# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- The wrapper and systemd unit now persist config and the wiki at `~/.openwiki` on the host (bind mount) instead of a named docker volume - the wiki is plain files, usable as an Obsidian vault or grepped by other tools. Existing named-volume users: copy the volume contents to `~/.openwiki` before updating (`docker run --rm -v openwiki-config:/src:ro -v $HOME/.openwiki:/dst deathnerd/openwiki sh -c "cp -a /src/. /dst/"` with `--entrypoint sh`).

### Added

- `OPENWIKI_DOCKER_ARGS` support in the wrapper templates: extra docker args (e.g. read-only source mounts for personal mode) without editing the managed function.
- `openwiki-setup schedule`/`unschedule`: systemd user timer for daily personal-wiki refresh, with the digest pin and source mounts baked into the generated unit.

## [0.1.1] - 2026-07-13

Wrapper versions track the upstream openwiki release they package. This is the first tagged release of the packaging repo.

### Added

- Multi-stage Dockerfile building [langchain-ai/openwiki](https://github.com/langchain-ai/openwiki) from a submodule pinned to the upstream `0.1.1` release tag (node:22-bookworm-slim, non-root UID 1000, git + ripgrep in the runtime, upstream LICENSE shipped in the image, OCI source/license labels).
- Tag-driven publishing: `publish.yml` publishes on `v*` tags only (Docker Hub + ghcr.io, multi-arch, semver tag fan-out, tag/version guard, Docker Hub description sync); `ci.yml` is a build-only check. Actions pinned to commit SHAs.
- Installer tooling: `scripts/openwiki-setup.sh` (install/update/uninstall of a digest-pinned shell wrapper plus completions) with curl-able `scripts/install.sh` / `scripts/uninstall.sh` bootstraps; host-side scripts baked into the image at `/opt/openwiki/host/`. The wrapper mounts the current directory, persists config in a named volume, and forwards provider env vars for one-shot and cron runs.
- `scripts/cut-release.sh`: maintainer release tool - pins the submodule to the upstream tag, verifies versions, smoke-builds, commits, tags, pushes, and creates the GitHub release from this changelog.
- README covering interactive and one-shot usage, config persistence, UID-mismatch handling, and container-specific limitations.
