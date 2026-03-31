#!/usr/bin/env bash
set -euo pipefail

PKG="${PKG:-treesheets}"

log() {
  printf '%s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

# Re-exec via sudo when invoked by a non-root user.
# This supports the requested Debian bullseye case of a non-root user named
# 'linaro' with sudo privileges, while still allowing direct root execution.
if [[ "${EUID}" -ne 0 ]]; then
  need_cmd sudo
  exec sudo --preserve-env=PKG,TARGET_USER "$0" "$@"
fi

# Target user resolution:
# - direct root run            -> root
# - sudo from linaro session   -> linaro
# - explicit override          -> TARGET_USER=<user>
TARGET_USER="${TARGET_USER:-${SUDO_USER:-root}}"

need_cmd getent
getent passwd "${TARGET_USER}" >/dev/null 2>&1 || die "target user '${TARGET_USER}' does not exist"

HOME_DIR="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
[[ -n "${HOME_DIR}" && -d "${HOME_DIR}" ]] || die "could not determine home directory for user '${TARGET_USER}'"

# Preserve openSUSE-style group ownership when possible, but fall back cleanly
# on Debian and other systems.
TARGET_GROUP="$(id -gn "${TARGET_USER}")"
if getent group users >/dev/null 2>&1; then
  if id -nG "${TARGET_USER}" | tr ' ' '\n' | grep -qx 'users'; then
    TARGET_GROUP="users"
  fi
fi

DEST="${HOME_DIR}/.local/bin"
BACKUP_ROOT="${HOME_DIR}/treesheets-old-versions"

need_cmd find
need_cmd cp
need_cmd mv
need_cmd sort
need_cmd date
need_cmd install
need_cmd basename

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
else
  die "/etc/os-release not found; cannot determine operating system"
fi

OS_ID="${ID,,}"
OS_ID_LIKE="${ID_LIKE,,}"
OS_VERSION_ID="${VERSION_ID:-}"
OS_CODENAME="${VERSION_CODENAME:-}"

LIST_CMD=()
REMOVE_CMD=()

if [[ "${OS_ID}" == opensuse* || " ${OS_ID_LIKE} " == *" suse "* ]]; then
  need_cmd rpm
  need_cmd zypper

  rpm -q "${PKG}" >/dev/null 2>&1 || die "RPM package '${PKG}' is not installed"

  LIST_CMD=(rpm -ql "${PKG}")
  REMOVE_CMD=(zypper -n rm "${PKG}")

elif [[ "${OS_ID}" == "debian" ]]; then
  need_cmd dpkg-query
  need_cmd apt-get
  need_cmd dpkg

  ARCH="$(dpkg --print-architecture)"

  [[ "${OS_VERSION_ID}" == "11" ]] || die "Debian support in this script is only for Debian 11; detected VERSION_ID='${OS_VERSION_ID:-unknown}'"
  if [[ -n "${OS_CODENAME}" && "${OS_CODENAME}" != "bullseye" ]]; then
    die "Debian support in this script is only for bullseye; detected VERSION_CODENAME='${OS_CODENAME}'"
  fi
  [[ "${ARCH}" == "arm64" ]] || die "Debian support in this script is only for arm64; detected architecture '${ARCH}'"

  dpkg-query -W -f='${Status}\n' "${PKG}" 2>/dev/null | grep -qx 'install ok installed' \
    || die "Debian package '${PKG}' is not installed"

  LIST_CMD=(dpkg-query -L "${PKG}")
  REMOVE_CMD=(env DEBIAN_FRONTEND=noninteractive apt-get -y remove "${PKG}")

else
  die "unsupported operating system: ID='${OS_ID}', VERSION_ID='${OS_VERSION_ID:-unknown}'"
fi

# Map packaged paths into the legacy ~/.local/bin layout expected by the
# original script.
#
# This handles both:
# 1) relocatable installs such as /usr/TreeSheets, /usr/docs, /usr/images, ...
# 2) FHS installs such as /usr/bin/TreeSheets, /usr/share/doc/TreeSheets/...,
#    /usr/share/TreeSheets/...
map_pkg_path() {
  local src="$1"

  case "${src}" in
    # Relocatable layout under /usr/
    /usr/TreeSheets) printf '%s\n' "TreeSheets" ;;
    /usr/docs) printf '%s\n' "docs" ;;
    /usr/docs/*) printf '%s\n' "docs/${src#/usr/docs/}" ;;
    /usr/examples) printf '%s\n' "examples" ;;
    /usr/examples/*) printf '%s\n' "examples/${src#/usr/examples/}" ;;
    /usr/images) printf '%s\n' "images" ;;
    /usr/images/*) printf '%s\n' "images/${src#/usr/images/}" ;;
    /usr/lib) printf '%s\n' "lib" ;;
    /usr/lib/*) printf '%s\n' "lib/${src#/usr/lib/}" ;;
    /usr/scripts) printf '%s\n' "scripts" ;;
    /usr/scripts/*) printf '%s\n' "scripts/${src#/usr/scripts/}" ;;
    /usr/translations) printf '%s\n' "translations" ;;
    /usr/translations/*) printf '%s\n' "translations/${src#/usr/translations/}" ;;
    /usr/readme*.html) basename -- "${src}" ;;

    # FHS layout
    /usr/bin/TreeSheets) printf '%s\n' "TreeSheets" ;;

    /usr/share/doc/TreeSheets/docs) printf '%s\n' "docs" ;;
    /usr/share/doc/TreeSheets/docs/*) printf '%s\n' "docs/${src#/usr/share/doc/TreeSheets/docs/}" ;;
    /usr/share/doc/TreeSheets/examples) printf '%s\n' "examples" ;;
    /usr/share/doc/TreeSheets/examples/*) printf '%s\n' "examples/${src#/usr/share/doc/TreeSheets/examples/}" ;;
    /usr/share/doc/TreeSheets/readme*.html) basename -- "${src}" ;;

    /usr/share/TreeSheets/docs) printf '%s\n' "docs" ;;
    /usr/share/TreeSheets/docs/*) printf '%s\n' "docs/${src#/usr/share/TreeSheets/docs/}" ;;
    /usr/share/TreeSheets/examples) printf '%s\n' "examples" ;;
    /usr/share/TreeSheets/examples/*) printf '%s\n' "examples/${src#/usr/share/TreeSheets/examples/}" ;;
    /usr/share/TreeSheets/images) printf '%s\n' "images" ;;
    /usr/share/TreeSheets/images/*) printf '%s\n' "images/${src#/usr/share/TreeSheets/images/}" ;;
    /usr/share/TreeSheets/lib) printf '%s\n' "lib" ;;
    /usr/share/TreeSheets/lib/*) printf '%s\n' "lib/${src#/usr/share/TreeSheets/lib/}" ;;
    /usr/share/TreeSheets/scripts) printf '%s\n' "scripts" ;;
    /usr/share/TreeSheets/scripts/*) printf '%s\n' "scripts/${src#/usr/share/TreeSheets/scripts/}" ;;
    /usr/share/TreeSheets/translations) printf '%s\n' "translations" ;;
    /usr/share/TreeSheets/translations/*) printf '%s\n' "translations/${src#/usr/share/TreeSheets/translations/}" ;;
    /usr/share/TreeSheets/readme*.html) basename -- "${src}" ;;

    /usr/lib/TreeSheets) printf '%s\n' "lib" ;;
    /usr/lib/TreeSheets/*) printf '%s\n' "lib/${src#/usr/lib/TreeSheets/}" ;;
    /usr/lib64/TreeSheets) printf '%s\n' "lib" ;;
    /usr/lib64/TreeSheets/*) printf '%s\n' "lib/${src#/usr/lib64/TreeSheets/}" ;;

    # Ignore everything else: desktop files, MIME, icons, metainfo, etc.
    *) return 1 ;;
  esac
}

install -d -m 0755 -o "${TARGET_USER}" -g "${TARGET_GROUP}" "${DEST}"
install -d -m 0755 -o "${TARGET_USER}" -g "${TARGET_GROUP}" "${BACKUP_ROOT}"

mapfile -t FILES < <("${LIST_CMD[@]}" | sort -u)
((${#FILES[@]} > 0)) || die "package '${PKG}' returned no file list"

declare -A PAYLOAD_TOPLEVEL=()

for src in "${FILES[@]}"; do
  [[ -n "${src}" ]] || continue
  if rel="$(map_pkg_path "${src}")"; then
    top="${rel%%/*}"
    PAYLOAD_TOPLEVEL["${top}"]=1
  fi
done

((${#PAYLOAD_TOPLEVEL[@]} > 0)) || die "could not identify a TreeSheets payload in package '${PKG}'"

ts="$(date +%Y%m%d%H%M%S)"
BACKUP_BASE="${BACKUP_ROOT}/${ts}"

need_backup=0
for item in "${!PAYLOAD_TOPLEVEL[@]}"; do
  if [[ -e "${DEST}/${item}" || -L "${DEST}/${item}" ]]; then
    need_backup=1
    break
  fi
done

if [[ "${need_backup}" -eq 1 ]]; then
  install -d -m 0755 -o "${TARGET_USER}" -g "${TARGET_GROUP}" "${BACKUP_BASE}"
  for item in "${!PAYLOAD_TOPLEVEL[@]}"; do
    if [[ -e "${DEST}/${item}" || -L "${DEST}/${item}" ]]; then
      mv -f "${DEST}/${item}" "${BACKUP_BASE}/"
    fi
  done
  chown -R "${TARGET_USER}:${TARGET_GROUP}" "${BACKUP_BASE}" || true
  log "NOTE: Existing TreeSheets payload moved to backup: ${BACKUP_BASE}"
fi

log "==> Copying packaged TreeSheets payload from '${PKG}' into: ${DEST}"

for src in "${FILES[@]}"; do
  [[ -n "${src}" ]] || continue

  if ! rel="$(map_pkg_path "${src}")"; then
    continue
  fi

  dst="${DEST}/${rel}"

  if [[ -d "${src}" ]]; then
    mkdir -p "${dst}"
  elif [[ -e "${src}" || -L "${src}" ]]; then
    mkdir -p "$(dirname "${dst}")"
    # -L dereferences symlinks, preventing broken links after package removal.
    cp -aL "${src}" "${dst}"
  else
    log "NOTE: listed by package manager but missing on disk (skipping): ${src}"
  fi
done

# Apply ownership + permissions only to the TreeSheets payload.
for d in docs examples images lib scripts translations; do
  if [[ -d "${DEST}/${d}" ]]; then
    chown -R "${TARGET_USER}:${TARGET_GROUP}" "${DEST}/${d}"
    find "${DEST}/${d}" -type d -exec chmod 0755 {} +
    find "${DEST}/${d}" -type f -exec chmod 0644 {} +
  fi
done

shopt -s nullglob
for f in "${DEST}"/readme*.html; do
  chown "${TARGET_USER}:${TARGET_GROUP}" "${f}"
  chmod 0644 "${f}"
done
shopt -u nullglob

# Preserve the original script's requested executable mode.
if [[ -e "${DEST}/TreeSheets" ]]; then
  chown "${TARGET_USER}:${TARGET_GROUP}" "${DEST}/TreeSheets"
  chmod 0777 "${DEST}/TreeSheets"
else
  die "${DEST}/TreeSheets was not created. Inspect the package layout with: ${LIST_CMD[*]}"
fi

# Optional SELinux context restore.
if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
  if command -v restorecon >/dev/null 2>&1; then
    restorecon -RF "${DEST}" 2>/dev/null || true
  fi
fi

log "==> Removing system package '${PKG}' to complete the move"
"${REMOVE_CMD[@]}"

echo
echo "==> Final tree under ${DEST}:"
ls -lA "${DEST}"

echo
echo "Launch:"
echo "  ${DEST}/TreeSheets"
