# openwiki -- installed by https://github.com/InfiniteRoomLabs/langchain-ai-openwiki-docker
# Managed by openwiki-setup; __REF__ is replaced with the resolved image ref.
function openwiki
    if not command -q docker
        echo "openwiki: docker is not installed." >&2
        return 1
    end
    set -l _ow_tty
    if isatty stdin; and isatty stdout
        set _ow_tty -it
    end
    # Forward provider/config env vars so one-shot and cron runs work without
    # interactive onboarding.
    set -l _ow_env
    for v in (set --export --names | string match -r '^(OPENWIKI|ANTHROPIC|OPENAI|OPENROUTER|LANGSMITH|TAVILY|BASETEN|FIREWORKS)_.*')
        set -a _ow_env -e $v
    end
    # Extra docker args (e.g. read-only source mounts for personal mode):
    # set -gx OPENWIKI_DOCKER_ARGS "-v $HOME/notes:/sources/notes:ro"
    set -l _ow_extra
    if set -q OPENWIKI_DOCKER_ARGS
        set _ow_extra (string split -n ' ' -- $OPENWIKI_DOCKER_ARGS)
    end
    mkdir -p "$HOME/.openwiki"
    docker run --rm $_ow_tty $_ow_env $_ow_extra \
        -v "$HOME/.openwiki:/home/openwiki/.openwiki" \
        -v (pwd)":/workspace" \
        __REF__ $argv
end
