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
# ## Testing and Verification First
# 
# ### A. Testing status from the provided data
# 
# No executed test results, CI artifacts, screenshots, demos, or recorded verification transcripts are included in the supplied unstructured data. Therefore, the script’s correctness can only be documented from its embedded validation logic, not from demonstrated runtime success.
# 
# ### B. Validation procedures directly implemented in the script
# 
# The script performs the following runtime checks before or during migration:
# 
# 1. **Tool availability checks**
# 
#    * Fails immediately if a required command is missing by calling `need_cmd`.
# 
# 2. **Privilege validation**
# 
#    * If not already root, the script requires `sudo` and re-executes itself with preserved environment.
# 
# 3. **Target-user validation**
# 
#    * Verifies that the resolved target user exists in the account database.
# 
# 4. **Home-directory validation**
# 
#    * Verifies that the resolved user has a non-empty existing home directory.
# 
# 5. **OS metadata validation**
# 
#    * Requires readable `/etc/os-release`.
# 
# 6. **Supported-platform validation**
# 
#    * Allows only:
# 
#      * openSUSE/SUSE-like systems, or
#      * Debian 11 bullseye arm64.
# 
# 7. **Package-installed validation**
# 
#    * SUSE-like branch: `rpm -q "${PKG}"`
#    * Debian branch: `dpkg-query -W -f='${Status}\n' "${PKG}"`
# 
# 8. **Architecture/version validation**
# 
#    * Debian branch additionally requires:
# 
#      * version `11`,
#      * codename `bullseye` if present,
#      * architecture `arm64`.
# 
# 9. **Package-file-list validation**
# 
#    * Requires a non-empty package file list.
# 
# 10. **Payload-discovery validation**
# 
#     * Requires at least one package path to map successfully through `map_pkg_path()`.
# 
# 11. **Post-copy executable validation**
# 
#     * Requires `${DEST}/TreeSheets` to exist before removing the package.
# 
# ### C. Testing results actually available
# 
# * **Available:** evidence that these validations are implemented in code.
# * **Unavailable:** proof that any specific branch, host, or package layout was actually executed successfully.
# 
# ### D. Recommended immediate test plan
# 
# For future maintainability, the following tests should be added:
# 
# 1. SUSE branch with relocatable package layout.
# 2. SUSE branch with FHS layout.
# 3. Debian 11 bullseye arm64 branch with FHS layout.
# 4. Negative test: unsupported Debian version.
# 5. Negative test: unsupported architecture.
# 6. Negative test: missing package.
# 7. Negative test: missing required command.
# 8. Backup test: existing destination payload is moved to timestamped backup.
# 9. Copy test: symlink source becomes dereferenced regular copied content.
# 10. Final-state test: `${DEST}/TreeSheets` exists with mode `0777`.
# 
# ## Background and Purpose
# 
# This script is a migration utility for TreeSheets. It is designed to extract the payload of an already-installed `treesheets` package and re-materialize it under a per-user directory, `${HOME_DIR}/.local/bin`, so that TreeSheets remains available after the original system package is removed.
# 
# This interpretation is supported directly by the copy, backup, permissioning, and package-removal logic. The script does not build TreeSheets or install a package from scratch.
# 
# ## Current State
# 
# Based strictly on the provided data:
# 
# * the script is implemented for two platform branches,
# * it includes extensive runtime validation,
# * it includes backup and cleanup logic,
# * it includes layout mapping for multiple package-install shapes,
# * it does not include automated tests or recorded results,
# * it does not include formal version history or update notes.
# 
# ## Environment Matrix
# 
# ### Supported
# 
# 1. **openSUSE / SUSE-like**
# 
#    * detected from `/etc/os-release`
#    * uses `rpm` to query package contents
#    * uses `zypper` to remove the package
# 
# 2. **Debian 11 bullseye arm64**
# 
#    * `ID=debian`
#    * `VERSION_ID=11`
#    * `VERSION_CODENAME=bullseye` if present
#    * `dpkg --print-architecture = arm64`
#    * uses `dpkg-query` to list files
#    * uses `apt-get` to remove the package
# 
# ### Unsupported by current implementation
# 
# * non-SUSE RPM systems not matching the branch condition
# * Debian versions other than 11
# * Debian non-arm64 systems
# * other Linux distributions not explicitly recognized
# 
# ## Invocation Model
# 
# ### Direct root execution
# 
# If run directly as root and `TARGET_USER` is not set, the script installs into root’s home:
# 
# * destination: `/root/.local/bin`
# 
# ### Sudo-mediated execution
# 
# If a non-root user invokes the script, it re-execs through `sudo`:
# 
# * preserves `PKG`
# * preserves `TARGET_USER`
# 
# In that case, if `TARGET_USER` is not explicitly set, the effective target user becomes `SUDO_USER`.
# 
# ### Explicit override
# 
# A caller may set:
# 
# * `TARGET_USER=<user>`
#   to force installation into another user’s home.
# 
# ## Dependencies
# 
# ### Common required commands
# 
# * `getent`
# * `find`
# * `cp`
# * `mv`
# * `sort`
# * `date`
# * `install`
# * `basename`
# 
# ### SUSE branch
# 
# * `rpm`
# * `zypper`
# 
# ### Debian branch
# 
# * `dpkg-query`
# * `apt-get`
# * `dpkg`
# 
# ### Optional SELinux handling
# 
# * `selinuxenabled`
# * `restorecon`
# 
# ## Design Considerations and Decision Logic
# 
# ### 1. Why target a user-local destination
# 
# The script’s implemented end state is a private user-local payload. This is evidenced by:
# 
# * `DEST="${HOME_DIR}/.local/bin"`
# * package removal after successful copy
# 
# ### 2. Why resolve target user and target group
# 
# Because the destination is per-user, the script must determine whose home directory and ownership to use.
# 
# ### 3. Why prefer group `users` when available
# 
# The script encodes a compatibility rule:
# 
# * default to the user’s primary group,
# * but use `users` if that group exists and the target user belongs to it.
#   The code shows this behavior directly; the historical rationale beyond compatibility cannot be proven from the supplied data.
# 
# ### 4. Why `map_pkg_path()` exists
# 
# The script directly shows support for multiple package layout styles. Therefore a normalization layer is required to transform source package paths into a single local destination layout.
# 
# ### 5. Why `cp -aL` is used
# 
# The script comment states:
# 
# * “`-L dereferences symlinks, preventing broken links after package removal.`”
#   This is directly evidenced and is a critical implementation detail.
# 
# ### 6. Why backup exists
# 
# The script checks whether mapped payload items already exist in the destination and, if so, moves them to a timestamped backup before copying new content.
# 
# ## Implementation Details
# 
# ### Target user resolution
# 
# ```bash
# TARGET_USER="${TARGET_USER:-${SUDO_USER:-root}}"
# ```
# 
# ### Target group resolution
# 
# ```bash
# TARGET_GROUP="$(id -gn "${TARGET_USER}")"
# if getent group users >/dev/null 2>&1; then
#   if id -nG "${TARGET_USER}" | tr ' ' '\n' | grep -qx 'users'; then
#     TARGET_GROUP="users"
#   fi
# fi
# ```
# 
# ### Destination and backup
# 
# ```bash
# DEST="${HOME_DIR}/.local/bin"
# BACKUP_ROOT="${HOME_DIR}/treesheets-old-versions"
# ts="$(date +%Y%m%d%H%M%S)"
# BACKUP_BASE="${BACKUP_ROOT}/${ts}"
# ```
# 
# ### Debian restriction logic
# 
# ```bash
# [[ "${OS_VERSION_ID}" == "11" ]]
# [[ -n "${OS_CODENAME}" && "${OS_CODENAME}" != "bullseye" ]] && die ...
# [[ "${ARCH}" == "arm64" ]]
# ```
# 
# ### Copy behavior
# 
# ```bash
# cp -aL "${src}" "${dst}"
# ```
# 
# ### Executable finalization
# 
# ```bash
# chown "${TARGET_USER}:${TARGET_GROUP}" "${DEST}/TreeSheets"
# chmod 0777 "${DEST}/TreeSheets"
# ```
# 
# ## Path Mapping Inventory
# 
# ### Relocatable layout inputs
# 
# * `/usr/TreeSheets`
# * `/usr/docs/...`
# * `/usr/examples/...`
# * `/usr/images/...`
# * `/usr/lib/...`
# * `/usr/scripts/...`
# * `/usr/translations/...`
# * `/usr/readme*.html`
# 
# ### FHS-style inputs
# 
# * `/usr/bin/TreeSheets`
# * `/usr/share/doc/TreeSheets/docs/...`
# * `/usr/share/doc/TreeSheets/examples/...`
# * `/usr/share/doc/TreeSheets/readme*.html`
# * `/usr/share/TreeSheets/docs/...`
# * `/usr/share/TreeSheets/examples/...`
# * `/usr/share/TreeSheets/images/...`
# * `/usr/share/TreeSheets/lib/...`
# * `/usr/share/TreeSheets/scripts/...`
# * `/usr/share/TreeSheets/translations/...`
# * `/usr/share/TreeSheets/readme*.html`
# * `/usr/lib/TreeSheets/...`
# * `/usr/lib64/TreeSheets/...`
# 
# ### Ignored source categories
# 
# The script intentionally ignores non-mapped assets such as desktop integration files, MIME metadata, icons, and metainfo.
# 
# ## Backup and Recovery-Relevant Behavior
# 
# ### Backup trigger
# 
# A backup is created only if at least one mapped top-level payload item already exists in destination.
# 
# ### Backup contents
# 
# Only the mapped top-level payload entries that already exist are moved into the timestamped backup directory.
# 
# ### Recovery implications
# 
# The script preserves prior local content in backup form, but it does not include a formal rollback command or restore procedure. That procedure should be documented separately in future work.
# 
# ## Ownership and Permission Model
# 
# ### Payload directories
# 
# For `docs`, `examples`, `images`, `lib`, `scripts`, and `translations`:
# 
# * recursive owner/group normalization,
# * directory mode `0755`,
# * file mode `0644`.
# 
# ### Readme files
# 
# For `readme*.html`:
# 
# * owner/group normalization,
# * mode `0644`.
# 
# ### Main executable
# 
# For `TreeSheets`:
# 
# * owner/group normalization,
# * mode `0777`.
# 
# This exact mode is documented from the implementation, not endorsed as a security recommendation.
# 
# ## SELinux Handling
# 
# If SELinux is enabled and `restorecon` exists, the script runs:
# 
# * `restorecon -RF "${DEST}"`
# 
# This is optional behavior and only applies on SELinux-capable hosts.
# 
# ## Final System State After Successful Execution
# 
# If the script succeeds as implemented, the expected end state is:
# 
# 1. TreeSheets payload exists under `${HOME_DIR}/.local/bin`.
# 2. Any overwritten local payload has been moved to a timestamped backup under `treesheets-old-versions`.
# 3. `${DEST}/TreeSheets` exists and is executable with mode `0777`.
# 4. The original system package has been removed.
# 5. The script prints the final directory tree and a launch path.
# 
# ## Operator Verification Procedure
# 
# After running the script, a maintainer should verify:
# 
# 1. `${DEST}` exists.
# 2. `${DEST}/TreeSheets` exists.
# 3. Required subdirectories such as `docs`, `examples`, `images`, `lib`, `scripts`, and `translations` are present if expected from the package.
# 4. `readme*.html` files are present if package-provided.
# 5. Backup directory exists if prior payload was present.
# 6. System package is no longer installed.
# 7. TreeSheets launches from the printed path.

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
