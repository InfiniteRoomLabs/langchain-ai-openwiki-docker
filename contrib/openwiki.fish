# openwiki -- installed by https://github.com/InfiniteRoomLabs/langchain-ai-openwiki-docker
# Copy to ~/.config/fish/functions/openwiki.fish. Assumes host UID 1000 (see
# the README's file-ownership note for other UIDs). Update the digest pin when
# bumping versions: docker buildx imagetools inspect deathnerd/openwiki:<ver>
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
    for v in (set --export --names | string match -r '^(OPENWIKI|ANTHROPIC|OPENAI|OPENROUTER|LANGSMITH|TAVILY)_.*')
        set -a _ow_env -e $v
    end
    docker run --rm $_ow_tty $_ow_env \
        -v openwiki-config:/home/openwiki/.openwiki \
        -v (pwd)":/workspace" \
        deathnerd/openwiki@sha256:e929d2de6126e315cbfd18269d7dd41fa3b222aba158fa5cede2883c57c2c17d $argv
end
