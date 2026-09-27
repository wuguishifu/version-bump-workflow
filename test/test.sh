#!/usr/bin/env bash
# Runs the scripts against a throwaway bare-repo remote. Usage: test/test.sh

set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")/../scripts" && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FAILURES=0

# expect <name> <expected> <actual>
expect() {
  if [ "$2" == "$3" ]; then
    echo "  ok: $1"
  else
    echo "  FAIL: $1: expected '$2', got '$3'"
    FAILURES=$((FAILURES + 1))
  fi
}

# output <key>: reads a key from the last run's GITHUB_OUTPUT
output() {
  grep "^$1=" "$GITHUB_OUTPUT" | tail -1 | cut -d= -f2-
}

# bump [ENV=value ...]: runs version-bump.sh in the clone with fresh outputs
bump() {
  : > "$GITHUB_OUTPUT"
  (cd "$WORK/clone" && env "$@" bash "$SCRIPTS/version-bump.sh" > /dev/null)
}

export GITHUB_OUTPUT="$WORK/output"

git init -q --bare "$WORK/remote.git"
git clone -q "$WORK/remote.git" "$WORK/clone" 2> /dev/null
git -C "$WORK/clone" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$WORK/clone" push -q origin HEAD

echo "version-bump: no tags"
bump BUMP_TYPE=major
expect "major from default initial" "1.0.0" "$(output version)"
expect "tag" "v1.0.0" "$(output tag)"
expect "previous-version empty" "" "$(output previous-version)"
expect "previous-tag empty" "" "$(output previous-tag)"
bump INITIAL_VERSION=1.0.0
expect "patch from initial 1.0.0" "1.0.1" "$(output version)"

for tag in v1 v99 v1.2.3 v1.9.9 v1.10.0 v2.0.0-beta vfoo topaz-v9.0.0 topaz-v9.1.3 1.5.0; do
  git -C "$WORK/clone" tag "$tag"
done
git -C "$WORK/clone" push -q origin --tags

echo "version-bump: with tags"
bump
expect "patch picks numerically highest, ignores major, pre-release and other-prefix tags" "1.10.1" "$(output version)"
expect "previous-tag" "v1.10.0" "$(output previous-tag)"
expect "previous-version" "1.10.0" "$(output previous-version)"
bump BUMP_TYPE=minor
expect "minor" "1.11.0" "$(output version)"
bump BUMP_TYPE=major
expect "major" "2.0.0" "$(output version)"
bump TAG_PREFIX=topaz-v BUMP_TYPE=minor
expect "custom prefix" "9.2.0" "$(output version)"
expect "custom prefix tag" "topaz-v9.2.0" "$(output tag)"
bump TAG_PREFIX=
expect "empty prefix" "1.5.1" "$(output version)"
expect "empty prefix tag" "1.5.1" "$(output tag)"
bump TAG_PREFIX=ruby-v
expect "unused prefix falls back to initial" "0.0.1" "$(output version)"

echo "version-bump: invalid input"
if bump BUMP_TYPE=huge 2> /dev/null; then
  expect "invalid bump type fails" "failure" "success"
else
  expect "invalid bump type fails" "failure" "failure"
fi
if bump INITIAL_VERSION=1.0 2> /dev/null; then
  expect "invalid initial version fails" "failure" "success"
else
  expect "invalid initial version fails" "failure" "failure"
fi

echo "set-package-version"
cat > "$WORK/package.json" << 'EOF'
{
  "name": "demo",
  "version": "0.0.0",
  "engines": {
    "version": "untouched"
  }
}
EOF
VERSION=3.4.5 PACKAGE_JSON="$WORK/package.json" bash "$SCRIPTS/set-package-version.sh" > /dev/null
expect "top-level version updated" '  "version": "3.4.5",' "$(sed -n 3p "$WORK/package.json")"
expect "nested version untouched" '    "version": "untouched"' "$(sed -n 5p "$WORK/package.json")"
echo '{ "name": "no-version" }' > "$WORK/bad.json"
if VERSION=1.0.0 PACKAGE_JSON="$WORK/bad.json" bash "$SCRIPTS/set-package-version.sh" > /dev/null; then
  expect "missing version field fails" "failure" "success"
else
  expect "missing version field fails" "failure" "failure"
fi

echo "docker-image"
SHA=$(git -C "$WORK/clone" rev-parse --short=8 HEAD)
: > "$GITHUB_OUTPUT"
(cd "$WORK/clone" && VERSION=topaz-v1.2.3 IMAGE=Owner/Repo/topaz bash "$SCRIPTS/docker-image.sh" > /dev/null)
expect "tag" "topaz-v1.2.3-$SHA" "$(output tag)"
expect "image (lowercased)" "ghcr.io/owner/repo/topaz:topaz-v1.2.3-$SHA" "$(output image)"
expect "image-latest" "ghcr.io/owner/repo/topaz:latest" "$(output image-latest)"
expect "image-name" "ghcr.io/owner/repo/topaz" "$(output image-name)"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES failure(s)"
  exit 1
fi
echo "All tests passed"
