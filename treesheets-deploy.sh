#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: TreeSheets kiosk deployer for Debian 13 (x86_64, tty-only)
#
# Purpose:
#   Convert a raw tty-only Debian 13 host into a minimal Xorg environment that
#   autostarts ratpoison and TreeSheets at boot, without any desktop manager.
#
# Behavior:
#   - Downloads the latest release binary from GitHub (no source compilation).
#   - Prefers .deb, then AppImage, then tar archives.
#   - Configures a non-root kiosk user with sudo privileges.
#   - Uses tty1 autologin -> startx -> ratpoison -> TreeSheets.
#
# Required TreeSheets flags:
#   -p (portable mode)
#   -i (allow more than one instance)
# ==============================================================================

TREE_OWNER="${TREE_OWNER:-aardappel}"
TREE_REPO="${TREE_REPO:-treesheets}"
GITHUB_API_URL="https://api.github.com/repos/${TREE_OWNER}/${TREE_REPO}/releases/latest"

KIOSK_USER="${KIOSK_USER:-treesheets}"
KIOSK_HOME="/home/${KIOSK_USER}"
TREE_INSTALL_DIR="/opt/treesheets"
TREE_BINARY_LINK="/usr/local/bin/treesheets"
WORK_DIR="${WORK_DIR:-/tmp/treesheets-deploy}"

log() {
    echo "[treesheets-deploy] $*"
}

die() {
    echo "[treesheets-deploy] ERROR: $*" >&2
    exit 1
}

require_cmd() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log "Installing missing command '$cmd' via package '$pkg'."
        sudo apt-get install -y "$pkg"
    fi
}

install_base_packages() {
    log "Updating APT index..."
    sudo apt-get update

    log "Installing Debian 13 kiosk dependencies..."
    sudo apt-get install -y \
        curl ca-certificates python3 \
        xorg xinit x11-xserver-utils ratpoison dbus-x11 \
        fonts-dejavu-core \
        libgtk-3-0 libgl1 libx11-6 libxext6 libxrandr2 libxinerama1 libxi6 libxcursor1
}

fetch_latest_asset() {
    local release_json="$WORK_DIR/latest-release.json"

    mkdir -p "$WORK_DIR"
    log "Fetching latest release metadata from ${TREE_OWNER}/${TREE_REPO}..."
    curl -fsSL "$GITHUB_API_URL" -o "$release_json"

    python3 - "$release_json" <<'PY'
import json
import re
import sys
from pathlib import Path

release = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assets = release.get("assets", [])

def match_asset(asset_name: str, kind: str) -> bool:
    name = asset_name.lower()
    is_arch = ("amd64" in name) or ("x86_64" in name)
    if kind == "deb":
        return name.endswith(".deb") and is_arch
    if kind == "appimage":
        return name.endswith(".appimage") and is_arch
    if kind == "tar":
        return is_arch and (name.endswith(".tar.gz") or name.endswith(".tgz") or name.endswith(".tar.xz"))
    return False

chosen = None
for preferred_kind in ("deb", "appimage", "tar"):
    for a in assets:
        if match_asset(a.get("name", ""), preferred_kind):
            chosen = a
            break
    if chosen:
        break

if not chosen:
    # Fallback: first Linux-ish binary package type.
    for a in assets:
        name = a.get("name", "").lower()
        if any(name.endswith(ext) for ext in (".deb", ".appimage", ".tar.gz", ".tgz", ".tar.xz")):
            chosen = a
            break

if not chosen:
    sys.exit(2)

print(chosen["name"])
print(chosen["browser_download_url"])
print(release.get("tag_name", "unknown"))
PY
}

resolve_treesheets_bin() {
    local candidate=""

    # Potential binary names in .deb packages may vary by distro/release.
    for candidate in \
        /usr/bin/TreeSheets \
        /usr/bin/treesheets \
        "$TREE_INSTALL_DIR/TreeSheets.AppImage"; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    candidate="$(find "$TREE_INSTALL_DIR" -type f \( -iname 'TreeSheets' -o -iname 'treesheets' \) -perm -111 | head -n 1 || true)"
    if [[ -n "$candidate" ]]; then
        echo "$candidate"
        return 0
    fi

    return 1
}

install_treesheets_from_asset() {
    local asset_name="$1"
    local asset_url="$2"
    local release_tag="$3"
    local downloaded="$WORK_DIR/$asset_name"

    [[ -n "$asset_name" && -n "$asset_url" ]] || die "Unable to locate a suitable release asset."

    log "Latest release tag: ${release_tag}"
    log "Downloading release asset: ${asset_name}"
    curl -fL "$asset_url" -o "$downloaded"

    sudo mkdir -p "$TREE_INSTALL_DIR"

    case "$asset_name" in
        *.deb)
            log "Installing .deb package via dpkg..."
            sudo dpkg -i "$downloaded" || sudo apt-get install -f -y
            ;;
        *.AppImage|*.appimage)
            log "Installing AppImage under ${TREE_INSTALL_DIR}..."
            sudo install -m 0755 "$downloaded" "$TREE_INSTALL_DIR/TreeSheets.AppImage"
            ;;
        *.tar.gz|*.tgz|*.tar.xz)
            log "Extracting tar archive under ${TREE_INSTALL_DIR}/extracted..."
            sudo rm -rf "$TREE_INSTALL_DIR/extracted"
            sudo mkdir -p "$TREE_INSTALL_DIR/extracted"
            sudo tar -xf "$downloaded" -C "$TREE_INSTALL_DIR/extracted"
            ;;
        *)
            die "Unsupported release asset format: $asset_name"
            ;;
    esac

    local resolved_bin
    resolved_bin="$(resolve_treesheets_bin || true)"
    [[ -n "$resolved_bin" ]] || die "TreeSheets executable could not be located after installation."

    log "Resolved TreeSheets executable: $resolved_bin"
    sudo ln -sf "$resolved_bin" "$TREE_BINARY_LINK"
}

configure_kiosk_user() {
    if ! id -u "$KIOSK_USER" >/dev/null 2>&1; then
        log "Creating non-root kiosk user '${KIOSK_USER}' with sudo privileges..."
        sudo useradd -m -s /bin/bash -G sudo,video,audio,input,tty "$KIOSK_USER"
    else
        log "User '${KIOSK_USER}' already exists; ensuring required groups..."
        sudo usermod -aG sudo,video,audio,input,tty "$KIOSK_USER"
    fi
}

write_kiosk_bash_profile() {
    local profile="$KIOSK_HOME/.bash_profile"
    local marker_start="# >>> treesheets-kiosk-startx >>>"

    sudo -u "$KIOSK_USER" touch "$profile"

    if sudo -u "$KIOSK_USER" grep -Fq "$marker_start" "$profile"; then
        log "Kiosk startx block already present in .bash_profile"
        return
    fi

    log "Appending tty1 startx block to ${profile}"
    sudo -u "$KIOSK_USER" tee -a "$profile" >/dev/null <<'EOF_PROFILE'
# >>> treesheets-kiosk-startx >>>
if [[ -z "${DISPLAY:-}" && "$(tty)" == "/dev/tty1" ]]; then
    exec startx -- -nocursor vt1
fi
# <<< treesheets-kiosk-startx <<<
EOF_PROFILE
}

configure_tty1_autologin() {
    log "Configuring systemd getty autologin on tty1 for '${KIOSK_USER}'..."
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null <<EOF_GETTY
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${KIOSK_USER} --noclear %I \$TERM
Type=idle
EOF_GETTY
}

configure_xinit_ratpoison_kiosk() {
    log "Writing ratpoison and X init configuration..."

    sudo -u "$KIOSK_USER" tee "$KIOSK_HOME/.ratpoisonrc" >/dev/null <<'EOF_RAT'
escape C-t
startup_message off
set winfmt %n:%t
exec xset -dpms
exec xset s off
exec xset s noblank
EOF_RAT

    sudo -u "$KIOSK_USER" tee "$KIOSK_HOME/.xinitrc" >/dev/null <<'EOF_XINIT'
#!/usr/bin/env bash
set -euo pipefail

xset -dpms
xset s off
xset s noblank

ratpoison &
RP_PID=$!

cleanup() {
    kill "$RP_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Mandatory launch flags: -p and -i
while true; do
    /usr/local/bin/treesheets -p -i
    sleep 1
done
EOF_XINIT

    sudo chmod 0755 "$KIOSK_HOME/.xinitrc"
    sudo chown "$KIOSK_USER:$KIOSK_USER" "$KIOSK_HOME/.xinitrc" "$KIOSK_HOME/.ratpoisonrc"
}

enable_boot_flow() {
    log "Reloading systemd and enabling tty1 getty service..."
    sudo systemctl daemon-reload
    sudo systemctl enable getty@tty1.service
}

main() {
    require_cmd sudo sudo
    require_cmd curl curl
    require_cmd python3 python3

    install_base_packages

    mapfile -t asset_info < <(fetch_latest_asset) || die "Unable to query latest release metadata."
    install_treesheets_from_asset "${asset_info[0]:-}" "${asset_info[1]:-}" "${asset_info[2]:-unknown}"

    configure_kiosk_user
    configure_tty1_autologin
    write_kiosk_bash_profile
    configure_xinit_ratpoison_kiosk
    enable_boot_flow

    log "Deployment complete. Reboot now to launch tty1 -> startx -> ratpoison -> TreeSheets kiosk automatically."
}

main "$@"
