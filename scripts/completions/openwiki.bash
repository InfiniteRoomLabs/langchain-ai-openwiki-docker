# Bash completion for openwiki (containerized)
# Install: source from ~/.bashrc (openwiki-setup does this for you)

_openwiki_complete() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "${prev}" in
        cron)
            COMPREPLY=($(compgen -W "list pause resume delete" -- "${cur}")); return ;;
        auth)
            COMPREPLY=($(compgen -W "slack gmail notion x configure tools" -- "${cur}")); return ;;
        --mode)
            COMPREPLY=($(compgen -W "code personal" -- "${cur}")); return ;;
    esac

    COMPREPLY=($(compgen -W "code personal ingest cron auth ngrok --init --update --print -p --dry-run --mode --modelId --help" -- "${cur}"))
}
complete -F _openwiki_complete openwiki
