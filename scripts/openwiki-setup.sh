#!/bin/sh
# openwiki-setup -- install, update, or remove the containerized openwiki wrapper.
#
# Ported from the claudesync setup methodology
# (https://github.com/InfiniteRoomLabs/claudesync). POSIX sh on purpose: this
# ships to end-user machines via curl|sh and must not assume any tooling
# beyond docker + a shell.
#
# Usage:
#   openwiki-setup [install|update|uninstall|schedule|unschedule] [options]
#
# Commands:
#   install/update     Install or refresh the wrapper function + completions
#   uninstall          Remove wrapper, completions, schedule, and this tool
#   schedule           Install a systemd user timer for daily personal-wiki
#                      refresh (Linux analog of upstream's macOS LaunchAgents)
#   unschedule         Remove the timer
#
# Options:
#   --version X.Y.Z    Pin to a specific image version tag (default: latest)
#   --no-pin-digest    Install the wrapper with a floating tag instead of a
#                      resolved @sha256 digest pin
#   --time HH:MM       schedule only: daily run time (default 02:00)
#   --dry-run          Print actions without performing them
#   --force            Skip confirmation prompts
#   -h, --help         Show this help
set -eu

IMAGE="deathnerd/openwiki"
RAW_BASE="https://raw.githubusercontent.com/InfiniteRoomLabs/langchain-ai-openwiki-docker/main"
HOST_DIR="/opt/openwiki/host"
DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/openwiki"
COMP_DIR="${DATA_DIR}/completions"
BIN_DIR="${HOME}/.local/bin"
FN_MARKER="# openwiki wrapper"
COMPLETION_MARKER="# openwiki completions"

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; RESET="\033[0m"
else
    RED=""; GREEN=""; YELLOW=""; RESET=""
fi
info()    { printf "%b[openwiki-setup]%b %s\n" "${YELLOW}" "${RESET}" "$*"; }
success() { printf "%b[openwiki-setup]%b %s\n" "${GREEN}"  "${RESET}" "$*"; }
warn()    { printf "%b[openwiki-setup]%b %s\n" "${RED}"    "${RESET}" "$*" >&2; }
die()     { warn "$*"; exit 1; }

usage() {
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
CMD="install"
VERSION=""
PIN_DIGEST=1
DRY_RUN=0
FORCE=0
SCHED_TIME="02:00"

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            install|update|uninstall|schedule|unschedule) CMD="$1" ;;
            --version) shift; VERSION="${1:-}" ;;
            --no-pin-digest) PIN_DIGEST=0 ;;
            --time) shift; SCHED_TIME="${1:-}" ;;
            --dry-run) DRY_RUN=1 ;;
            --force) FORCE=1 ;;
            -h|--help) usage ;;
            *) die "Unknown argument: $1 (see --help)" ;;
        esac
        shift
    done
}

run() {
    if [ "${DRY_RUN}" = "1" ]; then
        printf "%b[dry-run]%b %s\n" "${YELLOW}" "${RESET}" "$*"
        return 0
    fi
    "$@"
}

confirm() {
    [ "${FORCE}" = "1" ] && return 0
    [ "${DRY_RUN}" = "1" ] && return 0
    printf "%b[openwiki-setup]%b %s [y/N] " "${YELLOW}" "${RESET}" "$1"
    read -r _ans </dev/tty 2>/dev/null || return 1
    case "${_ans}" in [Yy]|[Yy][Ee][Ss]) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------------------
# Image reference resolution.
# With PIN_DIGEST, resolve tag -> image@sha256 (multi-arch index digest).
# ---------------------------------------------------------------------------
resolve_ref() {
    _tag="${VERSION:-latest}"
    _ref="${IMAGE}:${_tag}"

    if [ "${PIN_DIGEST}" != "1" ]; then
        printf '%s' "${_ref}"
        return 0
    fi

    _digest=""
    if command -v docker >/dev/null 2>&1; then
        _digest="$(docker buildx imagetools inspect "${_ref}" --format '{{.Manifest.Digest}}' 2>/dev/null || true)"
    fi
    if [ -z "${_digest}" ] && command -v python3 >/dev/null 2>&1; then
        _digest="$(docker manifest inspect -v "${_ref}" 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
d = d[0] if isinstance(d, list) else d
print((d.get("Descriptor") or {}).get("digest", ""))
' 2>/dev/null)"
    fi

    [ -n "${_digest}" ] || die "Could not resolve digest for ${_ref}. Ensure the tag exists and you can reach the registry (or pass --no-pin-digest)."
    printf '%s@%s' "${IMAGE}" "${_digest}"
}

pre_pull() {
    _r="$1"
    if [ "${DRY_RUN}" = "1" ]; then info "[dry-run] docker pull ${_r}"; return 0; fi
    docker pull "${_r}" >/dev/null 2>&1 || warn "Could not pre-pull ${_r} (will pull on first use)."
}

# ---------------------------------------------------------------------------
# Asset fetching: local repo checkout -> pulled image -> GitHub raw (loud).
# ---------------------------------------------------------------------------
extract_from_image() {
    _img="$1"; _img_path="$2"; _dest="$3"
    command -v docker >/dev/null 2>&1 || return 1
    _cid="$(docker create "${_img}" 2>/dev/null)" || return 1
    if docker cp "${_cid}:${_img_path}" "${_dest}" >/dev/null 2>&1; then
        docker rm -f "${_cid}" >/dev/null 2>&1 || true
        [ -f "${_dest}" ]
    else
        docker rm -f "${_cid}" >/dev/null 2>&1 || true
        return 1
    fi
}

fetch_asset() {
    _repo_path="$1"; _dest="$2"; _img="$3"
    _local="${SCRIPT_DIR}/${_repo_path#scripts/}"
    if [ -f "${_local}" ]; then
        run cp "${_local}" "${_dest}"
        return 0
    fi
    if extract_from_image "${_img}" "${HOST_DIR}/${_repo_path#scripts/}" "${_dest}"; then
        return 0
    fi
    warn "FALLBACK: fetching ${_repo_path} from GitHub (main) -- may differ from your pinned image."
    if command -v curl >/dev/null 2>&1; then
        run curl -fsSL "${RAW_BASE}/${_repo_path}" -o "${_dest}" || { warn "Download failed: ${RAW_BASE}/${_repo_path}"; return 1; }
    elif command -v wget >/dev/null 2>&1; then
        run wget -qO "${_dest}" "${RAW_BASE}/${_repo_path}" || { warn "Download failed: ${RAW_BASE}/${_repo_path}"; return 1; }
    else
        warn "Need curl or wget to fetch ${_repo_path}."
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Shell detection
# ---------------------------------------------------------------------------
detect_shell() {
    case "$(basename "${SHELL:-}")" in
        fish) echo fish ;;
        zsh)  echo zsh ;;
        *)    echo bash ;;
    esac
}

rc_for_shell() {
    case "$1" in
        zsh)  echo "${HOME}/.zshrc" ;;
        *)    echo "${HOME}/.bashrc" ;;
    esac
}

_ensure_rc_line() {
    _rc="$1"; _line="$2"; _tag="$3"
    if [ "${DRY_RUN}" = "1" ]; then info "[dry-run] ensure '${_line}' in ${_rc}"; return 0; fi
    grep -qF "${_tag}" "${_rc}" 2>/dev/null && return 0
    printf '\n%s  %s\n' "${_line}" "${_tag}" >> "${_rc}"
}

_strip_rc_lines() {
    _rc="$1"; _tag="$2"
    [ -f "${_rc}" ] || return 0
    if [ "${DRY_RUN}" = "1" ]; then info "[dry-run] strip '${_tag}' lines from ${_rc}"; return 0; fi
    _tmp="${_rc}.openwiki.tmp"
    grep -vF "${_tag}" "${_rc}" > "${_tmp}" || true
    mv "${_tmp}" "${_rc}"
}

# ---------------------------------------------------------------------------
# Wrapper function install
# ---------------------------------------------------------------------------
render_fn() {
    _template="$1"; _dest="$2"; _ref="$3"
    if [ "${DRY_RUN}" = "1" ]; then info "[dry-run] render ${_template} -> ${_dest} (ref ${_ref})"; return 0; fi
    sed "s|__REF__|${_ref}|" "${_template}" > "${_dest}"
}

install_function() {
    _ref="$1"
    _sh="$(detect_shell)"
    # Extract assets from the same resolved ref the wrapper will run, so the
    # templates always match the pinned image.
    _img="${_ref}"
    run mkdir -p "${DATA_DIR}"
    case "${_sh}" in
        fish)
            _tmpl="${DATA_DIR}/openwiki-fn.fish"
            fetch_asset "scripts/lib/openwiki-fn.fish" "${_tmpl}" "${_img}" || die "Could not obtain fish wrapper template."
            run mkdir -p "${HOME}/.config/fish/functions"
            render_fn "${_tmpl}" "${HOME}/.config/fish/functions/openwiki.fish" "${_ref}"
            info "Installed fish function: ~/.config/fish/functions/openwiki.fish"
            ;;
        *)
            _tmpl="${DATA_DIR}/openwiki-fn.bash"
            fetch_asset "scripts/lib/openwiki-fn.bash" "${_tmpl}" "${_img}" || die "Could not obtain bash wrapper template."
            render_fn "${_tmpl}" "${DATA_DIR}/openwiki.bash" "${_ref}"
            _rc="$(rc_for_shell "${_sh}")"
            _ensure_rc_line "${_rc}" "source ${DATA_DIR}/openwiki.bash" "${FN_MARKER}"
            info "Installed ${_sh} function: ${DATA_DIR}/openwiki.bash (sourced from ${_rc})"
            ;;
    esac
}

remove_function() {
    run rm -f "${HOME}/.config/fish/functions/openwiki.fish" \
              "${DATA_DIR}/openwiki.bash" \
              "${DATA_DIR}/openwiki-fn.fish" "${DATA_DIR}/openwiki-fn.bash"
    _strip_rc_lines "${HOME}/.bashrc" "${FN_MARKER}"
    _strip_rc_lines "${HOME}/.zshrc" "${FN_MARKER}"
}

# ---------------------------------------------------------------------------
# Completions
# ---------------------------------------------------------------------------
install_completion() {
    _ref="$1"
    _sh="$(detect_shell)"
    _img="${_ref}"
    case "${_sh}" in
        fish)
            _d="${HOME}/.config/fish/completions"
            run mkdir -p "${_d}"
            fetch_asset "scripts/completions/openwiki.fish" "${_d}/openwiki.fish" "${_img}" \
                || warn "fish completion unavailable; skipping."
            ;;
        zsh)
            # No native zsh completion shipped yet; bash's `complete -F` would
            # need bashcompinit, so don't pretend.
            info "zsh completion not shipped yet; skipping."
            ;;
        *)
            run mkdir -p "${COMP_DIR}"
            if fetch_asset "scripts/completions/openwiki.bash" "${COMP_DIR}/openwiki.bash" "${_img}"; then
                _ensure_rc_line "$(rc_for_shell "${_sh}")" "source ${COMP_DIR}/openwiki.bash" "${COMPLETION_MARKER}"
            else
                warn "bash completion unavailable; skipping."
            fi
            ;;
    esac
}

remove_completion() {
    run rm -f "${COMP_DIR}/openwiki.bash" "${HOME}/.config/fish/completions/openwiki.fish"
    _strip_rc_lines "${HOME}/.bashrc" "${COMPLETION_MARKER}"
    _strip_rc_lines "${HOME}/.zshrc" "${COMPLETION_MARKER}"
}

# ---------------------------------------------------------------------------
# Self-install so `openwiki-setup update` works later
# ---------------------------------------------------------------------------
self_install() {
    run mkdir -p "${BIN_DIR}"
    _dest="${BIN_DIR}/openwiki-setup"
    _src=""
    if [ -f "${SCRIPT_DIR}/openwiki-setup.sh" ]; then
        _src="${SCRIPT_DIR}/openwiki-setup.sh"
    elif [ -f "$0" ]; then
        _src="$0"
    fi
    # Running as the installed copy (openwiki-setup update): nothing to do.
    if [ -n "${_src}" ] && [ "$(cd "$(dirname "${_src}")" && pwd)/$(basename "${_src}")" != "${_dest}" ]; then
        run cp "${_src}" "${_dest}.tmp"
        run mv "${_dest}.tmp" "${_dest}"
        run chmod +x "${_dest}"
    fi
}

# ---------------------------------------------------------------------------
# Systemd user timer (Linux analog of upstream's macOS LaunchAgents).
# The unit bakes in the resolved image ref and the current
# OPENWIKI_DOCKER_ARGS (source mounts), since timers don't see shell config.
# Re-run `openwiki-setup schedule` after `update` or after changing mounts.
# ---------------------------------------------------------------------------
UNIT_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"

cmd_schedule() {
    command -v systemctl >/dev/null 2>&1 || die "systemd not available; use cron instead."
    echo "${SCHED_TIME}" | grep -Eq '^[0-2][0-9]:[0-5][0-9]$' || die "--time must be HH:MM"
    _ref="$(resolve_ref)"
    run mkdir -p "${UNIT_DIR}"
    if [ "${DRY_RUN}" = "1" ]; then
        info "[dry-run] write ${UNIT_DIR}/openwiki-refresh.{service,timer} (ref ${_ref}, ${SCHED_TIME} daily)"
    else
        cat > "${UNIT_DIR}/openwiki-refresh.service" <<EOF
[Unit]
Description=OpenWiki personal wiki refresh
# Generated by openwiki-setup; re-run 'openwiki-setup schedule' to regenerate.

[Service]
Type=oneshot
ExecStart=$([ -x /usr/bin/docker ] && echo /usr/bin/docker || command -v docker) run --rm ${OPENWIKI_DOCKER_ARGS:-} -v ${HOME}/.openwiki:/home/openwiki/.openwiki ${_ref} personal --update --print "Refresh the wiki from configured connectors"
EOF
        cat > "${UNIT_DIR}/openwiki-refresh.timer" <<EOF
[Unit]
Description=Daily OpenWiki personal wiki refresh

[Timer]
OnCalendar=*-*-* ${SCHED_TIME}:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
    fi
    run systemctl --user daemon-reload
    run systemctl --user enable --now openwiki-refresh.timer
    success "Scheduled daily refresh at ${SCHED_TIME} (systemd user timer 'openwiki-refresh')."
    info "Runs while you're logged in; for always-on: loginctl enable-linger $(id -un)"
    info "Logs: journalctl --user -u openwiki-refresh.service"
}

cmd_unschedule() {
    run systemctl --user disable --now openwiki-refresh.timer 2>/dev/null || true
    run rm -f "${UNIT_DIR}/openwiki-refresh.service" "${UNIT_DIR}/openwiki-refresh.timer"
    run systemctl --user daemon-reload
    success "Removed the openwiki-refresh timer."
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
cmd_install() {
    command -v docker >/dev/null 2>&1 || die "docker is required."
    _ref="$(resolve_ref)"
    info "Image ref: ${_ref}"
    pre_pull "${_ref}"
    install_function "${_ref}"
    install_completion "${_ref}"
    self_install
    success "Done. Open a new shell (or 'exec ${SHELL}') and run: openwiki"
    [ "${PIN_DIGEST}" = "1" ] && info "Wrapper is digest-pinned. Run 'openwiki-setup update' after new releases."
}

cmd_uninstall() {
    confirm "Remove the openwiki wrapper, completions, schedule, and openwiki-setup?" || die "Aborted."
    command -v systemctl >/dev/null 2>&1 && cmd_unschedule
    remove_function
    remove_completion
    run rm -f "${BIN_DIR}/openwiki-setup"
    [ "${DRY_RUN}" = "1" ] || rmdir "${COMP_DIR}" "${DATA_DIR}" 2>/dev/null || true
    success "Removed. ~/.openwiki (your wiki, config, and API keys) was kept."
}

parse_args "$@"
case "${CMD}" in
    install|update) cmd_install ;;
    uninstall)      cmd_uninstall ;;
    schedule)       cmd_schedule ;;
    unschedule)     cmd_unschedule ;;
esac
