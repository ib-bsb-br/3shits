#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: TreeSheets kiosk deployer for Debian 13 (x86_64, tty-only)
#
# What this script does:
#   1) Installs Xorg/X11 + ratpoison + runtime dependencies.
#   2) Downloads the latest TreeSheets Linux x86_64 release artifact from GitHub
#      (prefers .deb, then AppImage, then tar.*).
#   3) Installs TreeSheets under /usr/local/bin/treesheets.
#   4) Creates/updates a non-root kiosk user with sudo privileges.
#   5) Configures tty1 autologin -> startx -> ratpoison -> TreeSheets kiosk.
#
# Kiosk constraints implemented:
#   - TreeSheets is always started with: -p -i
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

    log "Installing base packages for Debian 13 kiosk setup..."
    sudo apt-get install -y \
        curl ca-certificates python3 \
        xorg xinit x11-xserver-utils ratpoison dbus-x11 \
        fonts-dejavu-core \
        libgtk-3-0 libgl1 libx11-6 libxext6 libxrandr2 libxinerama1 libxi6 libxcursor1
}

fetch_latest_asset() {
    local release_json="$WORK_DIR/latest-release.json"

    mkdir -p "$WORK_DIR"

    log "Querying latest release metadata from ${TREE_OWNER}/${TREE_REPO}..."
    curl -fsSL "$GITHUB_API_URL" -o "$release_json"

    python3 - "$release_json" <<'PY'
import json
import re
import sys
from pathlib import Path

release_path = Path(sys.argv[1])
release = json.loads(release_path.read_text(encoding="utf-8"))
assets = release.get("assets", [])

# Prefer Linux x86_64/amd64 assets in this order.
patterns = [
    re.compile(r"(linux|debian|ubuntu).*(amd64|x86_64).*\.deb$", re.I),
    re.compile(r"(amd64|x86_64).*(linux|debian|ubuntu).*\.deb$", re.I),
    re.compile(r"(linux).*(amd64|x86_64).*\.appimage$", re.I),
    re.compile(r"(amd64|x86_64).*(linux).*\.appimage$", re.I),
    re.compile(r"(linux).*(amd64|x86_64).*(\.tar\.gz|\.tgz|\.tar\.xz)$", re.I),
    re.compile(r"(amd64|x86_64).*(linux).*(\.tar\.gz|\.tgz|\.tar\.xz)$", re.I),
]

chosen = None
for pat in patterns:
    for a in assets:
        name = a.get("name", "")
        if pat.search(name):
            chosen = a
            break
    if chosen:
        break

# Fallback: any linux appimage or deb.
if not chosen:
    for a in assets:
        name = a.get("name", "")
        if re.search(r"(linux).*(\.deb|\.appimage)$", name, re.I):
            chosen = a
            break

if not chosen:
    print("", end="")
    sys.exit(0)

print(chosen["name"])
print(chosen["browser_download_url"])
print(release.get("tag_name", "unknown"))
PY
}

install_treesheets_from_asset() {
    local asset_name="$1"
    local asset_url="$2"
    local release_tag="$3"
    local downloaded="$WORK_DIR/$asset_name"

    if [[ -z "$asset_name" || -z "$asset_url" ]]; then
        log "ERROR: Could not locate a suitable Linux x86_64 release asset."
        exit 1
    fi

    log "Latest release tag: ${release_tag}"
    log "Downloading asset: ${asset_name}"
    curl -fL "$asset_url" -o "$downloaded"

    sudo mkdir -p "$TREE_INSTALL_DIR"

    case "$asset_name" in
        *.deb)
            log "Installing .deb package..."
            sudo dpkg -i "$downloaded" || sudo apt-get install -f -y
            ;;
        *.AppImage|*.appimage)
            log "Installing AppImage into ${TREE_INSTALL_DIR}/TreeSheets.AppImage"
            sudo install -m 0755 "$downloaded" "$TREE_INSTALL_DIR/TreeSheets.AppImage"
            ;;
        *.tar.gz|*.tgz|*.tar.xz)
            log "Extracting tar archive into ${TREE_INSTALL_DIR}"
            sudo rm -rf "$TREE_INSTALL_DIR/extracted"
            sudo mkdir -p "$TREE_INSTALL_DIR/extracted"
            sudo tar -xf "$downloaded" -C "$TREE_INSTALL_DIR/extracted"
            ;;
        *)
            log "ERROR: Unsupported asset format: $asset_name"
            exit 1
            ;;
    esac

    # Resolve runtime executable path and expose stable launcher symlink.
    local resolved_bin=""

    if command -v TreeSheets >/dev/null 2>&1; then
        resolved_bin="$(command -v TreeSheets)"
    elif [[ -x "$TREE_INSTALL_DIR/TreeSheets.AppImage" ]]; then
        resolved_bin="$TREE_INSTALL_DIR/TreeSheets.AppImage"
    else
        resolved_bin="$(find "$TREE_INSTALL_DIR" -type f -iname 'TreeSheets' -perm -111 | head -n 1 || true)"
    fi

    if [[ -z "$resolved_bin" ]]; then
        log "ERROR: Could not find TreeSheets executable after install."
        exit 1
    fi

    log "Using TreeSheets executable: $resolved_bin"
    sudo ln -sf "$resolved_bin" "$TREE_BINARY_LINK"
}

configure_kiosk_user() {
    if ! id -u "$KIOSK_USER" >/dev/null 2>&1; then
        log "Creating kiosk user '$KIOSK_USER' with sudo privileges..."
        sudo useradd -m -s /bin/bash -G sudo,video,audio,input,tty "$KIOSK_USER"
    else
        log "User '$KIOSK_USER' already exists. Ensuring required groups..."
        sudo usermod -aG sudo,video,audio,input,tty "$KIOSK_USER"
    fi
}

configure_startx_autologin() {
    log "Configuring systemd getty autologin on tty1 for ${KIOSK_USER}..."
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null <<EOF_GETTY
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${KIOSK_USER} --noclear %I \$TERM
Type=idle
EOF_GETTY

    log "Writing ${KIOSK_USER} shell profile to auto-run startx on tty1..."
    sudo -u "$KIOSK_USER" tee "$KIOSK_HOME/.bash_profile" >/dev/null <<'EOF_PROFILE'
# Auto-start X on tty1 only.
if [[ -z "${DISPLAY:-}" && "$(tty)" == "/dev/tty1" ]]; then
    exec startx
fi
EOF_PROFILE
}

configure_xinit_ratpoison_kiosk() {
    log "Writing ratpoison config..."
    sudo -u "$KIOSK_USER" tee "$KIOSK_HOME/.ratpoisonrc" >/dev/null <<'EOF_RAT'
escape C-t
startup_message off
set winfmt %n:%t
exec xset -dpms
exec xset s off
exec xset s noblank
EOF_RAT

    log "Writing X init script (ratpoison + TreeSheets kiosk)..."
    sudo -u "$KIOSK_USER" tee "$KIOSK_HOME/.xinitrc" >/dev/null <<'EOF_XINIT'
#!/usr/bin/env bash
set -euo pipefail

xset -dpms
xset s off
xset s noblank

ratpoison &
RP_PID=$!

# Kiosk loop: TreeSheets always starts with portable + multi-instance flags.
while true; do
    /usr/local/bin/treesheets -p -i
    sleep 1
done &
TS_PID=$!

wait "$TS_PID"
kill "$RP_PID" 2>/dev/null || true
EOF_XINIT

    sudo chmod 0755 "$KIOSK_HOME/.xinitrc"
    sudo chown "$KIOSK_USER:$KIOSK_USER" "$KIOSK_HOME/.xinitrc" "$KIOSK_HOME/.ratpoisonrc" "$KIOSK_HOME/.bash_profile"
}

enable_boot_flow() {
    log "Reloading systemd and enabling getty@tty1..."
    sudo systemctl daemon-reload
    sudo systemctl enable getty@tty1.service

    log "Kiosk deployment complete. Reboot to start tty1 -> startx -> ratpoison -> TreeSheets."
}

main() {
    require_cmd sudo sudo
    require_cmd curl curl
    require_cmd python3 python3

    install_base_packages

    mapfile -t asset_info < <(fetch_latest_asset)
    install_treesheets_from_asset "${asset_info[0]:-}" "${asset_info[1]:-}" "${asset_info[2]:-unknown}"

    configure_kiosk_user
    configure_startx_autologin
    configure_xinit_ratpoison_kiosk
    enable_boot_flow

    log "Done. You can test immediately by switching to tty1 and logging in as ${KIOSK_USER}, or rebooting."
}

main "$@"
