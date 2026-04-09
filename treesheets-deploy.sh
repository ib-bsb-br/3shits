#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: Install released TreeSheets binary and configure X11 kiosk mode
# Target: Debian 13 (Trixie) x86_64 / amd64, tty-only, no desktop environment
# Description:
# - Runs as a regular user with sudo privileges.
# - Downloads the latest released TreeSheets .deb from this GitHub repository.
# - Installs Xorg, xinit, and ratpoison (no desktop environment).
# - Configures a tty1 systemd service that starts Xorg + ratpoison on boot.
# - Launches TreeSheets in portable, multi-instance mode (-p -i).
#
# Notes:
# - This script verifies that the downloaded release asset is amd64 or all.
# - Portable mode writes TreeSheets.ini in PORTABLE_DIR.
# ==============================================================================

REPO_OWNER="${REPO_OWNER:-ib-bsb-br}"
REPO_NAME="${REPO_NAME:-3shits}"
LATEST_RELEASE_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"

TARGET_USER="$(id -un)"
TARGET_HOME="${HOME}"

CACHE_DIR="${XDG_CACHE_HOME:-$TARGET_HOME/.cache}/treesheets-kiosk"
STATE_DIR="${XDG_STATE_HOME:-$TARGET_HOME/.local/state}/treesheets-kiosk"
PORTABLE_DIR="${TARGET_HOME}/TreeSheetsPortable"

LATEST_RELEASE_JSON="${CACHE_DIR}/latest-release.json"
DOWNLOADED_DEB=""
TREE_SHEETS_BIN=""

XINITRC_PATH="${TARGET_HOME}/.xinitrc"
RATPOISONRC_PATH="${TARGET_HOME}/.ratpoisonrc"

KIOSK_SERVICE_NAME="treesheets-kiosk.service"
KIOSK_SERVICE_PATH="/etc/systemd/system/${KIOSK_SERVICE_NAME}"

log() {
    printf '%s\n' "--> $*"
}

warn() {
    printf '%s\n' "Warning: $*" >&2
}

die() {
    printf '%s\n' "Error: $*" >&2
    exit 1
}

ensure_non_root_user() {
    if [[ "${EUID}" -eq 0 ]]; then
        die "Run this script as a regular user with sudo privileges, not as root."
    fi
}

ensure_sudo_works() {
    log "Validating sudo access..."
    sudo -v
}

ensure_pkg_installed() {
    local pkg_name="$1"
    if ! dpkg -s "$pkg_name" >/dev/null 2>&1; then
        log "Installing missing package '$pkg_name'..."
        sudo apt-get -o Acquire::Retries=3 install -y "$pkg_name"
    else
        log "Package '$pkg_name' is already installed."
    fi
}

refresh_apt_metadata() {
    log "Updating APT package lists..."
    sudo apt-get -o Acquire::Retries=3 update
}

install_runtime_dependencies() {
    local packages=(
        ca-certificates
        curl
        python3
        xorg
        xinit
        xauth
        x11-xserver-utils
        ratpoison
        dbus-x11
    )

    for pkg in "${packages[@]}"; do
        ensure_pkg_installed "$pkg"
    done
}

prepare_directories() {
    mkdir -p "$CACHE_DIR" "$STATE_DIR" "$PORTABLE_DIR"
}

download_latest_release_metadata() {
    log "Fetching metadata for the latest GitHub release..."
    local auth_header=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi

    curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        "${auth_header[@]}" \
        "$LATEST_RELEASE_API" \
        -o "$LATEST_RELEASE_JSON"
}

show_release_tag() {
    local tag
    tag="$(python3 - "$LATEST_RELEASE_JSON" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    data = json.load(fh)
print(data.get("tag_name", "unknown"))
PY
)"
    log "Latest release tag: ${tag}"
}

list_candidate_deb_assets() {
    python3 - "$LATEST_RELEASE_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    data = json.load(fh)

assets = data.get("assets", [])

def score(name: str):
    lower = name.lower()
    if not lower.endswith(".deb"):
        return None
    if "amd64" in lower or "x86_64" in lower:
        return 0
    if any(token in lower for token in ("arm64", "aarch64", "armhf", "armv7", "i386", "386")):
        return 2
    return 1

candidates = []
for asset in assets:
    name = asset.get("name", "")
    url = asset.get("browser_download_url", "")
    s = score(name)
    if s is not None and url:
        candidates.append((s, name, url))

for _, name, url in sorted(candidates, key=lambda item: (item[0], item[1].lower())):
    print(f"{name}\t{url}")
PY
}

download_release_deb() {
    log "Selecting a Debian package from the latest release..."
    local asset_lines=()
    mapfile -t asset_lines < <(list_candidate_deb_assets)

    if [[ "${#asset_lines[@]}" -eq 0 ]]; then
        die "The latest release does not expose any .deb asset."
    fi

    local auth_header=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi

    local asset_name
    local asset_url
    local asset_path
    local asset_arch

    for line in "${asset_lines[@]}"; do
        IFS=$'\t' read -r asset_name asset_url <<<"$line"
        asset_path="${CACHE_DIR}/${asset_name}"

        log "Downloading candidate asset '${asset_name}'..."
        curl -fL \
            -H "Accept: application/octet-stream" \
            "${auth_header[@]}" \
            "$asset_url" \
            -o "$asset_path"

        asset_arch="$(dpkg-deb -f "$asset_path" Architecture 2>/dev/null || true)"
        if [[ "$asset_arch" == "amd64" || "$asset_arch" == "all" ]]; then
            DOWNLOADED_DEB="$asset_path"
            log "Using asset '${asset_name}' (Architecture=${asset_arch})."
            return 0
        fi

        warn "Skipping '${asset_name}' because its Debian architecture is '${asset_arch:-unknown}', not amd64/all."
        rm -f "$asset_path"
    done

    die "No amd64-compatible .deb asset was found in the latest release."
}

install_downloaded_package() {
    [[ -n "$DOWNLOADED_DEB" ]] || die "Internal error: no package has been selected."

    log "Installing TreeSheets package '${DOWNLOADED_DEB}'..."
    if ! sudo dpkg -i "$DOWNLOADED_DEB"; then
        warn "dpkg reported missing dependencies; asking APT to repair them."
        sudo apt-get -o Acquire::Retries=3 install -f -y
    fi

    sudo update-mime-database /usr/share/mime || true
    sudo update-desktop-database /usr/share/applications || true
}

resolve_treesheets_binary() {
    if command -v TreeSheets >/dev/null 2>&1; then
        TREE_SHEETS_BIN="$(command -v TreeSheets)"
    elif command -v treesheets >/dev/null 2>&1; then
        TREE_SHEETS_BIN="$(command -v treesheets)"
    elif [[ -x /usr/bin/TreeSheets ]]; then
        TREE_SHEETS_BIN="/usr/bin/TreeSheets"
    elif [[ -x /usr/bin/treesheets ]]; then
        TREE_SHEETS_BIN="/usr/bin/treesheets"
    else
        die "TreeSheets binary was not found after package installation."
    fi

    log "TreeSheets binary resolved to '${TREE_SHEETS_BIN}'."
}

grant_runtime_groups() {
    local groups=(video input render sudo)
    local group_name

    for group_name in "${groups[@]}"; do
        if getent group "$group_name" >/dev/null 2>&1; then
            log "Ensuring user '${TARGET_USER}' belongs to group '${group_name}'..."
            sudo usermod -aG "$group_name" "$TARGET_USER"
        fi
    done
}

write_ratpoison_config() {
    log "Writing ratpoison configuration to '${RATPOISONRC_PATH}'..."
    cat >"$RATPOISONRC_PATH" <<'EOF_RP'
startup_message off
set border 0
set padding 0 0 0 0
set barpadding 0 0
escape C-t
EOF_RP
    chmod 600 "$RATPOISONRC_PATH"
}

write_xinitrc() {
    log "Writing X session launcher to '${XINITRC_PATH}'..."
    cat >"$XINITRC_PATH" <<EOF_XINIT
#!/usr/bin/env bash
set -euo pipefail

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=ratpoison
export DESKTOP_SESSION=ratpoison

xset -dpms
xset s off
xset s noblank

mkdir -p "${PORTABLE_DIR}"
cd "${PORTABLE_DIR}"

/usr/bin/ratpoison &
sleep 1

exec "${TREE_SHEETS_BIN}" -p -i
EOF_XINIT
    chmod 700 "$XINITRC_PATH"
}

write_systemd_service() {
    log "Writing systemd kiosk service to '${KIOSK_SERVICE_PATH}'..."
    sudo tee "$KIOSK_SERVICE_PATH" >/dev/null <<EOF_SERVICE
[Unit]
Description=TreeSheets kiosk on Xorg + ratpoison
After=systemd-user-sessions.service network.target
Conflicts=getty@tty1.service

[Service]
User=${TARGET_USER}
Group=${TARGET_USER}
PAMName=login
WorkingDirectory=${PORTABLE_DIR}
Environment=HOME=${TARGET_HOME}
Environment=USER=${TARGET_USER}
Environment=LOGNAME=${TARGET_USER}
TTYPath=/dev/tty1
StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
ExecStart=/usr/bin/startx ${XINITRC_PATH} -- :0 vt1 -keeptty -nolisten tcp
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF_SERVICE
}

enable_kiosk_service() {
    log "Reloading systemd units..."
    sudo systemctl daemon-reload

    log "Disabling tty1 getty so the kiosk can own vt1 on boot..."
    sudo systemctl disable --now getty@tty1.service || true

    log "Enabling '${KIOSK_SERVICE_NAME}' for automatic startup..."
    sudo systemctl enable "$KIOSK_SERVICE_NAME"

    local current_tty
    current_tty="$(tty 2>/dev/null || true)"
    if [[ "$current_tty" != "/dev/tty1" ]]; then
        log "Starting the kiosk service now..."
        sudo systemctl restart "$KIOSK_SERVICE_NAME"
    else
        warn "The kiosk service was enabled but not started immediately because this shell is already on /dev/tty1. Reboot, or switch to another TTY and run: sudo systemctl start ${KIOSK_SERVICE_NAME}"
    fi
}

print_summary() {
    cat <<EOF_SUMMARY
============================================================
TreeSheets release-based kiosk setup completed.
============================================================
TreeSheets package : ${DOWNLOADED_DEB}
TreeSheets binary  : ${TREE_SHEETS_BIN}
Portable directory : ${PORTABLE_DIR}
X session launcher : ${XINITRC_PATH}
Ratpoison config   : ${RATPOISONRC_PATH}
Systemd service    : ${KIOSK_SERVICE_PATH}

At boot, tty1 will start Xorg + ratpoison and then launch:
  ${TREE_SHEETS_BIN} -p -i

Portable mode stores TreeSheets.ini in:
  ${PORTABLE_DIR}
============================================================
EOF_SUMMARY
}

main() {
    ensure_non_root_user
    ensure_sudo_works
    prepare_directories
    refresh_apt_metadata
    install_runtime_dependencies
    download_latest_release_metadata
    show_release_tag
    download_release_deb
    install_downloaded_package
    resolve_treesheets_binary
    grant_runtime_groups
    write_ratpoison_config
    write_xinitrc
    write_systemd_service
    enable_kiosk_service
    print_summary
}

main "$@"
