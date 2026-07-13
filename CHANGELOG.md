# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-07-13

Wrapper versions track the upstream openwiki release they package.

### Added

- Multi-stage Dockerfile building [langchain-ai/openwiki](https://github.com/langchain-ai/openwiki) from a submodule pinned to the upstream `0.1.1` release tag (node:22-bookworm-slim, non-root UID 1000, git + ripgrep in the runtime, upstream LICENSE shipped in the image, OCI source/license labels).
- GitHub Actions workflow publishing `deathnerd/openwiki` for linux/amd64 and linux/arm64; pull requests build without pushing, actions pinned to commit SHAs.
- README covering interactive and one-shot usage, config persistence, UID-mismatch handling, and container-specific limitations.
