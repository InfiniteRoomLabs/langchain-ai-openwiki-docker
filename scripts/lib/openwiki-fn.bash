# openwiki -- installed by https://github.com/InfiniteRoomLabs/langchain-ai-openwiki-docker
# Managed by openwiki-setup; __REF__ is replaced with the resolved image ref.
# Sourced by bash and zsh; arrays are used so both shells expand args identically.
openwiki() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "openwiki: docker is not installed." >&2
    return 1
  fi
  local _ow_args
  _ow_args=()
  if [ -t 0 ] && [ -t 1 ]; then
    _ow_args+=(-it)
  fi
  # Forward provider/config env vars so one-shot and cron runs work without
  # interactive onboarding. awk ENVIRON enumeration is immune to multiline
  # values, unlike parsing `env` output.
  local v
  for v in $(awk 'BEGIN { for (k in ENVIRON) print k }' </dev/null); do
    case "$v" in
      OPENWIKI_*|ANTHROPIC_*|OPENAI_*|OPENROUTER_*|LANGSMITH_*|TAVILY_*|BASETEN_*|FIREWORKS_*)
        _ow_args+=(-e "$v") ;;
    esac
  done
  # Extra docker args (e.g. read-only source mounts for personal mode):
  # export OPENWIKI_DOCKER_ARGS="-v $HOME/notes:/sources/notes:ro"
  if [ -n "${OPENWIKI_DOCKER_ARGS:-}" ]; then
    local _ow_extra
    read -r -a _ow_extra <<< "${OPENWIKI_DOCKER_ARGS}"
    _ow_args+=("${_ow_extra[@]}")
  fi
  docker run --rm "${_ow_args[@]}" \
    -v openwiki-config:/home/openwiki/.openwiki \
    -v "$(pwd):/workspace" \
    __REF__ "$@"
}
