#!/bin/sh
# openwiki-docker uninstaller -- delegates to openwiki-setup uninstall.
set -eu

RAW_BASE="https://raw.githubusercontent.com/InfiniteRoomLabs/langchain-ai-openwiki-docker/main"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"

# Prefer an already-installed manager (no network needed to remove).
if command -v openwiki-setup >/dev/null 2>&1; then
    exec openwiki-setup uninstall "$@"
fi
if [ -x "${HOME}/.local/bin/openwiki-setup" ]; then
    exec sh "${HOME}/.local/bin/openwiki-setup" uninstall "$@"
fi
if [ -f "${SCRIPT_DIR}/openwiki-setup.sh" ]; then
    exec sh "${SCRIPT_DIR}/openwiki-setup.sh" uninstall "$@"
fi

SETUP="$(mktemp)"
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${RAW_BASE}/scripts/openwiki-setup.sh" -o "${SETUP}"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "${SETUP}" "${RAW_BASE}/scripts/openwiki-setup.sh"
else
    echo "uninstall.sh: could not obtain openwiki-setup.sh (need curl or wget)." >&2
    rm -f "${SETUP}"
    exit 1
fi
if sh "${SETUP}" uninstall "$@"; then _rc=0; else _rc=$?; fi
rm -f "${SETUP}"
exit "${_rc}"
