# Fish completion for openwiki (containerized)
# Install: copy to ~/.config/fish/completions/openwiki.fish

complete -c openwiki -f

# Top-level flags
complete -c openwiki -l init -d 'Initialize OpenWiki for this repo'
complete -c openwiki -l update -d 'Update the wiki'
complete -c openwiki -s p -l print -d 'One-shot non-interactive run'
complete -c openwiki -l dry-run -d 'Dry run'
complete -c openwiki -l mode -r -x -a 'code personal' -d 'Brain mode'
complete -c openwiki -l modelId -r -d 'Override model ID'
complete -c openwiki -s h -l help -d 'Show help'

# Subcommands
complete -c openwiki -n '__fish_use_subcommand' -a code -d 'Repository documentation mode'
complete -c openwiki -n '__fish_use_subcommand' -a personal -d 'Personal brain wiki mode'
complete -c openwiki -n '__fish_use_subcommand' -a ingest -d 'Run connector ingestion'
complete -c openwiki -n '__fish_use_subcommand' -a cron -d 'Manage source schedules'
complete -c openwiki -n '__fish_use_subcommand' -a auth -d 'Authenticate a connector provider'
complete -c openwiki -n '__fish_use_subcommand' -a ngrok -d 'Manage ngrok tunnel for OAuth'

# cron subcommands
complete -c openwiki -n '__fish_seen_subcommand_from cron' -a 'list pause resume delete'

# auth providers
complete -c openwiki -n '__fish_seen_subcommand_from auth' -a 'slack gmail notion x configure tools'
