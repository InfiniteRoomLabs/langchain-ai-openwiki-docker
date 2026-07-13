#!/usr/bin/env -S usage bash
#USAGE name "cut-release"
#USAGE bin "cut-release"
#USAGE about "Cut a release: pin submodule to upstream tag, verify, build, commit, tag"
#USAGE flag "--push" help="Push branch and tag to origin and gitea after tagging"
#USAGE flag "--no-build" help="Skip the local docker build smoke test"
#USAGE flag "-n --dry-run" help="Print actions without performing them"
#USAGE arg "<version>" help="Upstream openwiki version to release (X.Y.Z, no v prefix)"
#
# Maintainer tooling (requires jdx `usage`; not part of the user-facing
# install surface). The release-prep skill discovers and drives this script.
set -euo pipefail
cd "$(dirname "$0")/.."

ver="${usage_version:?}"
dry="${usage_dry_run:-false}"

run() {
    if [ "$dry" = "true" ]; then echo "[dry-run] $*"; return 0; fi
    "$@"
}
fail() { echo "cut-release: $*" >&2; exit 1; }

echo "$ver" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail "'$ver' is not stable semver (X.Y.Z)"
[ "$(git branch --show-current)" = "main" ] || fail "not on main"
# A dirty CHANGELOG.md is expected (the runbook says write the entry first);
# anything else dirty is a stop.
dirty_other="$(git status --porcelain | grep -v ' CHANGELOG\.md$' || true)"
[ -z "$dirty_other" ] || fail "working tree has changes beyond CHANGELOG.md; commit or stash first"
git rev-parse -q --verify "refs/tags/v$ver" >/dev/null && fail "tag v$ver already exists locally"
for r in origin gitea; do
    git ls-remote --exit-code "$r" "refs/tags/v$ver" >/dev/null 2>&1 \
        && fail "tag v$ver already exists on $r"
done

# Pin the submodule to the upstream release tag (upstream tags are unprefixed).
run git -C openwiki-src fetch --tags origin
run git -C openwiki-src checkout -q "$ver"
if [ "$dry" != "true" ]; then
    got="$(jq -er .version openwiki-src/package.json)"
    [ "$got" = "$ver" ] || fail "upstream package.json says $got, expected $ver"
fi

# Iron law: no release without a changelog entry.
grep -q "^## \[$ver\]" CHANGELOG.md \
    || fail "CHANGELOG.md has no '## [$ver]' entry - write it first"

# Smoke test the build before tagging.
if [ "${usage_no_build:-false}" != "true" ]; then
    run docker build -q -t openwiki:release-check .
    run docker run --rm openwiki:release-check --help >/dev/null
fi

if [ -n "$(git status --porcelain)" ] || [ "$dry" = "true" ]; then
    run git add openwiki-src CHANGELOG.md
    run git commit -m "release: v$ver"
else
    echo "cut-release: submodule already pinned and committed; tagging only"
fi
run git tag -a "v$ver" -m "Release v$ver"

if [ "${usage_push:-false}" = "true" ]; then
    # Gitea (mirror) first: if it fails, nothing has published yet on GitHub.
    run git push gitea main "v$ver"
    run git push origin main "v$ver"

    # GitHub release with the CHANGELOG section as notes.
    notes="$(mktemp)"
    trap 'rm -f "$notes"' EXIT
    awk -v ver="$ver" '
        index($0, "## [" ver "]") == 1 { on=1; next }
        on && /^## \[/ { exit }
        on { print }
    ' CHANGELOG.md > "$notes"
    run gh release create "v$ver" --title "v$ver" --verify-tag --notes-file "$notes"

    echo "cut-release: v$ver pushed and GitHub release created."
    echo "publish.yml is building; when it finishes run:"
    echo "  openwiki-setup update   # refresh your local digest-pinned wrapper"
else
    echo "cut-release: v$ver tagged locally. To publish:"
    echo "  git push origin main v$ver && git push gitea main v$ver"
    echo "  gh release create v$ver --title v$ver --verify-tag --notes-file <(changelog section)"
fi
