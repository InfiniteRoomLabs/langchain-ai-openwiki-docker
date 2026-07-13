# CLAUDE.md

Docker packaging wrapper for [langchain-ai/openwiki](https://github.com/langchain-ai/openwiki). Upstream source is vendored as a submodule at `openwiki-src/`, pinned to a release tag. No patches, no forks - this repo only packages.

## Layout

- `Dockerfile` - multi-stage build of the vendored submodule; host-side scripts are baked into `/opt/openwiki/host/`.
- `scripts/openwiki-setup.sh` - user-facing installer (wrapper function + completions, digest-pinned). `scripts/install.sh` / `uninstall.sh` are curl-able bootstraps for it.
- `scripts/lib/openwiki-fn.{fish,bash}` - wrapper function templates; `__REF__` is substituted with the resolved image ref at install time. The repo never hardcodes an image digest.
- `scripts/cut-release.sh` - maintainer release tool (see below).
- `.github/workflows/ci.yml` - build-only check on main/PRs. `publish.yml` - publishes on `v*` tags only.

## Cutting a Release

Images are published **only on a `v*` git tag** - pushing `main` never publishes. `publish.yml` refuses tags that don't match the upstream version pinned in the submodule, and only stable `vX.Y.Z` tags publish (`latest` is added for stable semver only).

Wrapper releases track the upstream openwiki version they package. To release:

1. Add a `## [X.Y.Z]` entry to `CHANGELOG.md` (the release script refuses to run without it).
2. Run `scripts/cut-release.sh X.Y.Z --push` (use `--dry-run` first if unsure). It pins the submodule to the upstream tag, verifies versions match, smoke-builds the image, commits `release: vX.Y.Z`, tags, and pushes to both remotes (GitHub Actions only fire on `origin`; gitea is the mirror).
3. After publish completes, run `openwiki-setup update` to refresh the local digest-pinned wrapper.

The tag build produces images tagged `X.Y.Z`, `X.Y`, `latest`, and the short commit SHA, on Docker Hub (`deathnerd/openwiki`) and ghcr.io (`ghcr.io/infiniteroomlabs/openwiki`).

One-time note: the first tag publish creates the ghcr.io package; check its visibility is set to public in the package settings afterward.

Wrapper-only changes (README, scripts, workflows) don't get their own image release - they ride along with the next upstream version bump.

## Conventions

- Actions are pinned to commit SHAs - keep it that way when touching workflows.
- End-user manager scripts (`scripts/install.sh`, `uninstall.sh`, `openwiki-setup.sh`) are POSIX sh - they must run on machines with nothing but docker and a shell. The function/completion templates in `scripts/lib/` and `scripts/completions/` are shell-specific by nature. Maintainer-only tooling (`cut-release.sh`) may use jdx `usage`.
- UTF-8, ASCII punctuation in markdown (IRL repo convention).
- CHANGELOG.md is required by the commit hooks; stage with `git add` in a separate call from `git commit`.
