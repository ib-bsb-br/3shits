#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: Install and Deploy TreeSheets on VPC-3588 (RK3588)
# Target: Debian 11 (Bullseye) ARM64 (aarch64) - bare-metal
# Description: Automates host dependency setup, native compilation, Debian
# packaging, optional installation, and optional kiosk setup.
#
# Design notes:
# - Primary GCC 10 / Lobster charconv fix lives in CMakeLists.txt.
# - Script keeps a verified patch fallback in case the source tree predates that fix.
# - Build uses verbose logs and exposes root cause on failure.
# ==============================================================================

REPO_URL="https://github.com/ib-bsb-br/3shits.git"
BUILD_DIR_NAME="3shits"
CMAKE_BUILD_DIR="_build"
TREESHEETS_VERSION="1.0.0"
KIOSK_USER="treesheets_user"
KIOSK_SERVICE_FILE="/etc/systemd/system/treesheets-kiosk.service"
BUILD_LOG_FILE=""

WORK_DIR="$HOME"
SRC_DIR="$WORK_DIR/$BUILD_DIR_NAME"

ensure_pkg_installed() {
    local pkg_name="$1"
    if ! dpkg -s "$pkg_name" >/dev/null 2>&1; then
        echo "--> Package '$pkg_name' is missing. Installing..."
        sudo apt-get -o Acquire::Retries=3 install -y "$pkg_name"
    else
        echo "--> Package '$pkg_name' is already installed."
    fi
}

ensure_tool_installed() {
    local cmd_name="$1"
    local pkg_name="${2:-$1}"
    if ! command -v "$cmd_name" >/dev/null 2>&1; then
        ensure_pkg_installed "$pkg_name"
    else
        echo "--> Tool '$cmd_name' is already available."
    fi
}

configure_cmake() {
    local enable_lobster="$1"
    echo "--> Configuring CMake build (ENABLE_LOBSTER=${enable_lobster})..."

    cmake -S . -B "$CMAKE_BUILD_DIR" \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCPACK_PACKAGING_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POLICY_DEFAULT_CMP0177=NEW \
        -DCMAKE_C_FLAGS="-D_GNU_SOURCE -D_POSIX_C_SOURCE=200809L" \
        -DwxBUILD_SHARED=OFF \
        -DwxBUILD_INSTALL=OFF \
        -DwxUSE_REGEX=builtin \
        -DwxUSE_ZLIB=builtin \
        -DwxUSE_EXPAT=builtin \
        -DwxUSE_LIBJPEG=builtin \
        -DwxUSE_LIBPNG=builtin \
        -DwxUSE_LIBTIFF=builtin \
        -DwxUSE_NANOSVG=builtin \
        -DENABLE_LOBSTER="$enable_lobster" \
        -DTREESHEETS_VERSION="$TREESHEETS_VERSION"
}

patch_lobster_charconv_if_needed() {
    local lobster_dir
    local pre_count
    local post_count

    lobster_dir=$(find "$SRC_DIR/$CMAKE_BUILD_DIR/_deps" -maxdepth 2 -type d -name lobster-src | head -n 1 || true)
    if [[ -z "$lobster_dir" ]]; then
        echo "Warning: Lobster source directory not found; skipping manual charconv patch." >&2
        return 0
    fi

    pre_count=$(grep -r -l "__cpp_lib_to_chars" "$lobster_dir" | wc -l || true)
    if [[ "$pre_count" -eq 0 ]]; then
        echo "--> Lobster charconv macro already neutralized (likely by CMake patch)."
        return 0
    fi

    echo "--> Applying script-level Lobster charconv patch to $pre_count file(s)..."
    find "$lobster_dir" -type f \( -name "*.h" -o -name "*.hpp" -o -name "*.hh" -o -name "*.c" -o -name "*.cc" -o -name "*.cpp" -o -name "*.cxx" -o -name "*.inl" -o -name "*.ipp" \) \
        -exec sed -i 's/__cpp_lib_to_chars/LOBSTER_DISABLE_TO_CHARS/g' {} +

    post_count=$(grep -r -l "__cpp_lib_to_chars" "$lobster_dir" | wc -l || true)
    if [[ "$post_count" -ne 0 ]]; then
        echo "Warning: Script-level patch verification found $post_count remaining file(s)." >&2
        return 1
    fi

    echo "--> Script-level Lobster patch applied and verified."
}

build_package() {
    echo "--> Building package target with $(nproc) parallel jobs..."
    echo "--> Build log: $BUILD_LOG_FILE"
    cmake --build "$CMAKE_BUILD_DIR" --target package -j"$(nproc)" --verbose 2>&1 | tee "$BUILD_LOG_FILE"
}

echo "============================================================"
echo "Section 1: Preparing Host System & Toolchain"
echo "============================================================"

echo "Updating APT package lists..."
if ! sudo apt-get -o Acquire::Retries=3 update; then
    echo "Warning: APT update returned errors (likely third-party repo key issues). Continuing..." >&2
fi

ensure_pkg_installed "build-essential"
ensure_tool_installed "cmake"
ensure_tool_installed "git"
ensure_tool_installed "gettext"
ensure_pkg_installed "libunwind-dev"
ensure_pkg_installed "libdw-dev"
ensure_pkg_installed "mesa-common-dev"
ensure_pkg_installed "libgl1-mesa-dev"
ensure_pkg_installed "libgl1"
ensure_pkg_installed "libglx-mesa0"
ensure_pkg_installed "libxext-dev"
ensure_pkg_installed "libgtk-3-dev"
ensure_pkg_installed "squashfs-tools"
ensure_pkg_installed "zenity"
ensure_tool_installed "ruby"
ensure_pkg_installed "ruby-dev"
ensure_tool_installed "gem" "ruby"

if ! command -v fpm >/dev/null 2>&1; then
    echo "Installing fpm..."
    sudo gem install fpm
else
    echo "--> 'fpm' gem is already installed."
fi

echo "============================================================"
echo "Section 2: Native C++ Compilation & Source Patching"
echo "============================================================"

cd "$WORK_DIR"
if [[ -d "$SRC_DIR" ]]; then
    echo "--> Source directory exists. Pulling latest changes..."
    (cd "$SRC_DIR" && git pull || echo "Warning: Git pull failed; continuing with existing checkout.")
else
    echo "--> Cloning repository..."
    git clone "$REPO_URL" "$SRC_DIR"
fi

cd "$SRC_DIR"

if [[ -d "$CMAKE_BUILD_DIR" ]]; then
    echo "--> Removing stale build directory '$CMAKE_BUILD_DIR'..."
    rm -rf "$CMAKE_BUILD_DIR"
fi

BUILD_LOG_FILE="$SRC_DIR/$CMAKE_BUILD_DIR/build-$(date +%Y%m%d-%H%M%S).log"

configure_cmake "ON"
patch_lobster_charconv_if_needed || true

set +e
build_package
build_rc=$?
set -e

if [[ "$build_rc" -ne 0 ]]; then
    echo "Warning: Build failed with ENABLE_LOBSTER=ON."
    echo "--> Last 120 lines from build log:"
    tail -n 120 "$BUILD_LOG_FILE" || true

    echo "--> Retrying with ENABLE_LOBSTER=OFF for maximum compatibility..."
    rm -rf "$CMAKE_BUILD_DIR"

    BUILD_LOG_FILE="$SRC_DIR/$CMAKE_BUILD_DIR/build-nolobster-$(date +%Y%m%d-%H%M%S).log"
    configure_cmake "OFF"
    build_package

    echo "--> Fallback build with ENABLE_LOBSTER=OFF succeeded."
fi

echo "============================================================"
echo "Section 3: Package Generation & System Installation"
echo "============================================================"

if ! bash -c "
    cd '$SRC_DIR'
    shopt -s extglob nullglob
    for file in $CMAKE_BUILD_DIR/treesheets_*:*.deb; do
        [ -f \"\$file\" ] && mv -v \"\$file\" \"\${file/_+([[:digit:]]):/_}\"
    done
"; then
    echo "Warning: Filename sanitization step encountered an issue. Proceeding anyway." >&2
fi

DEB_PACKAGE=$(find "$SRC_DIR/$CMAKE_BUILD_DIR" -maxdepth 1 -name "treesheets_*.deb" | head -n 1)
if [[ -z "$DEB_PACKAGE" ]]; then
    echo "Error: Could not find generated .deb package in $SRC_DIR/$CMAKE_BUILD_DIR." >&2
    exit 1
fi

echo "--> Found package: $DEB_PACKAGE"
echo "--> Build artifacts and logs are in: $SRC_DIR/$CMAKE_BUILD_DIR"

read -r -p "WARNING: Install '$DEB_PACKAGE' system-wide via dpkg now? (yes/NO): " confirm_install
if [[ "$confirm_install" == "yes" ]]; then
    if ! sudo dpkg -i "$DEB_PACKAGE"; then
        echo "Warning: dpkg returned an error. Attempting dependency repair..."
        sudo apt-get install -f -y
    fi
    sudo update-mime-database /usr/share/mime || true
    sudo update-desktop-database /usr/share/applications || true
    echo "--> TreeSheets installed successfully."
else
    echo "--> Installation skipped by user."
fi

echo "============================================================"
echo "Section 4: Embedded Kiosk Auto-Start Integration"
echo "============================================================"

read -r -p "WARNING: Configure TreeSheets kiosk auto-start on boot? (yes/NO): " setup_kiosk
if [[ "$setup_kiosk" == "yes" ]]; then
    if ! id -u "$KIOSK_USER" >/dev/null 2>&1; then
        sudo useradd -m -G video,input -s /bin/bash "$KIOSK_USER"
    else
        echo "--> User '$KIOSK_USER' already exists."
    fi

    ensure_tool_installed "xinit"

    sudo bash -c "cat << 'EOF_SERVICE' > $KIOSK_SERVICE_FILE
[Unit]
Description=TreeSheets Embedded Kiosk
After=systemd-user-sessions.service graphical.target
Conflicts=getty@tty1.service

[Service]
User=$KIOSK_USER
Group=$KIOSK_USER
PAMName=login
Environment=\"DISPLAY=:0\"
ExecStart=/usr/bin/xinit /usr/bin/TreeSheets -- :0 -nolisten tcp vt1
Restart=always
RestartSec=5

[Install]
WantedBy=graphical.target
EOF_SERVICE"

    sudo systemctl daemon-reload

    read -r -p "Enable and start kiosk service immediately? (yes/NO): " start_kiosk
    if [[ "$start_kiosk" == "yes" ]]; then
        sudo systemctl enable treesheets-kiosk.service
        sudo systemctl start treesheets-kiosk.service || {
            echo "Error: Failed to start kiosk service. Check: journalctl -u treesheets-kiosk.service" >&2
        }
    else
        echo "--> Service created but not enabled. Enable later with: sudo systemctl enable treesheets-kiosk.service"
    fi
else
    echo "--> Skipping kiosk setup."
fi

echo "============================================================"
echo "Deployment Script Completed Successfully!"
echo "============================================================"
