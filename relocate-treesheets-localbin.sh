#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root via sudo." >&2
  exit 1
fi

if [[ -z "${SUDO_USER:-}" || "${SUDO_USER}" == "root" ]]; then
  echo "Run via sudo from a normal user account (SUDO_USER is required)." >&2
  exit 1
fi

USER_NAME="${SUDO_USER}"
HOME_DIR="$(getent passwd "${USER_NAME}" | cut -d: -f6)"
if [[ -z "${HOME_DIR}" || ! -d "${HOME_DIR}" ]]; then
  echo "Could not resolve home directory for ${USER_NAME}." >&2
  exit 1
fi

USER_GROUP="$(id -gn "${USER_NAME}")"
DEST="${HOME_DIR}/.local/bin"
PKG_NAME="treesheets"

if command -v rpm >/dev/null 2>&1 && rpm -q "${PKG_NAME}" >/dev/null 2>&1; then
  PKG_TYPE="rpm"
  mapfile -t PKG_FILES < <(rpm -ql "${PKG_NAME}")
elif command -v dpkg-query >/dev/null 2>&1 && dpkg-query -W -f='${Status}' "${PKG_NAME}" 2>/dev/null | grep -q "install ok installed"; then
  PKG_TYPE="deb"
  mapfile -t PKG_FILES < <(dpkg-query -L "${PKG_NAME}")
else
  echo "Package '${PKG_NAME}' is not installed as an RPM or DEB package." >&2
  exit 1
fi

mkdir -p "${DEST}"

backup_items=(TreeSheets docs examples images lib scripts)

backup_needed=0
for item in "${backup_items[@]}"; do
  if [[ -e "${DEST}/${item}" ]]; then
    backup_needed=1
    break
  fi
done

if [[ ${backup_needed} -eq 1 ]]; then
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_root="${HOME_DIR}/treesheets-old-versions/${timestamp}"
  mkdir -p "${backup_root}"
  for item in "${backup_items[@]}"; do
    if [[ -e "${DEST}/${item}" ]]; then
      mv "${DEST}/${item}" "${backup_root}/"
    fi
  done
  chown -R "${USER_NAME}:${USER_GROUP}" "${backup_root}"
fi

for path in "${PKG_FILES[@]}"; do
  [[ "${path}" == /usr/* ]] || continue
  [[ -e "${path}" ]] || continue
  [[ "${path}" == /usr/share/locale/* ]] && continue
  [[ "${path}" == */translations/* ]] && continue

  rel="${path#/usr/}"
  target="${DEST}/${rel}"

  if [[ -d "${path}" ]]; then
    mkdir -p "${target}"
  else
    mkdir -p "$(dirname "${target}")"
    cp -aL "${path}" "${target}"
  fi
done

required_dirs=(docs examples images lib scripts)
for d in "${required_dirs[@]}"; do
  mkdir -p "${DEST}/${d}"
done

chown -R "${USER_NAME}:${USER_GROUP}" "${DEST}"
find "${DEST}" -type d -exec chmod 0755 {} +
find "${DEST}" -type f -exec chmod 0644 {} +
if [[ -f "${DEST}/TreeSheets" ]]; then
  chmod 0755 "${DEST}/TreeSheets"
fi

if command -v restorecon >/dev/null 2>&1; then
  restorecon -RF "${DEST}" || true
fi

if [[ "${PKG_TYPE}" == "rpm" ]]; then
  if command -v zypper >/dev/null 2>&1; then
    zypper -n rm --no-clean-deps "${PKG_NAME}"
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y remove "${PKG_NAME}"
  elif command -v yum >/dev/null 2>&1; then
    yum -y remove "${PKG_NAME}"
  else
    rpm -e "${PKG_NAME}"
  fi
else
  apt-get -y purge "${PKG_NAME}"
fi

echo "Relocation completed for ${PKG_TYPE} package."
echo "Run: ${DEST}/TreeSheets"
