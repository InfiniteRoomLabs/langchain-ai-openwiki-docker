#!/bin/sh
# openwiki-docker bootstrap installer -- obtains openwiki-setup and runs it.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/InfiniteRoomLabs/langchain-ai-openwiki-docker/main/scripts/install.sh | sh
#   curl -fsSL <url> | sh -s -- [install|update|uninstall] [--version X.Y.Z] [--dry-run] ...
#
# With no arguments this installs everything (the happy path). All other
# behavior lives in openwiki-setup; this script just bootstraps it.
set -eu

IMAGE="deathnerd/openwiki"
RAW_BASE="https://raw.githubusercontent.com/InfiniteRoomLabs/langchain-ai-openwiki-docker/main"
# Under `curl | sh`, $0 is the shell, not this script: don't treat the
# caller's cwd as a repo checkout.
case "$0" in
    *install.sh) SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)" ;;
    *) SCRIPT_DIR="" ;;
esac

printf '\n  openwiki-docker -- containerized langchain-ai/openwiki\n'
printf '  https://github.com/InfiniteRoomLabs/langchain-ai-openwiki-docker\n\n'

SETUP=""
CLEANUP=""

if [ -f "${SCRIPT_DIR}/openwiki-setup.sh" ]; then
    SETUP="${SCRIPT_DIR}/openwiki-setup.sh"
else
    SETUP="$(mktemp)"
    CLEANUP="${SETUP}"
    _got=0
    # Prefer extracting from the pulled image (version-locked).
    if command -v docker >/dev/null 2>&1; then
        _cid="$(docker create "${IMAGE}:latest" 2>/dev/null || true)"
        if [ -n "${_cid}" ]; then
            if docker cp "${_cid}:/opt/openwiki/host/openwiki-setup.sh" "${SETUP}" >/dev/null 2>&1; then _got=1; fi
            docker rm -f "${_cid}" >/dev/null 2>&1 || true
        fi
    fi
    # Fall back to GitHub.
    if [ "${_got}" = "0" ]; then
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "${RAW_BASE}/scripts/openwiki-setup.sh" -o "${SETUP}" && _got=1
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "${SETUP}" "${RAW_BASE}/scripts/openwiki-setup.sh" && _got=1
        fi
    fi
    if [ "${_got}" != "1" ]; then
        echo "install.sh: could not obtain openwiki-setup.sh (need docker, curl, or wget)." >&2
        rm -f "${CLEANUP}"
        exit 1
    fi
fi

if sh "${SETUP}" "$@"; then _rc=0; else _rc=$?; fi
[ -n "${CLEANUP}" ] && rm -f "${CLEANUP}"
exit "${_rc}"
