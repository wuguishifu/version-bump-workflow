#!/usr/bin/env bash
# Computes the next semver version from the latest <prefix>X.Y.Z tag on the remote.
#
# Env:
#   BUMP_TYPE        major | minor | patch (default: patch)
#   TAG_PREFIX       tag prefix, e.g. "v" or "topaz-v"; may be empty (default: v)
#   INITIAL_VERSION  version to bump from when no matching tag exists (default: 0.0.0)
#   REMOTE           git remote to read tags from (default: origin)

set -euo pipefail

BUMP_TYPE=${BUMP_TYPE:-patch}
TAG_PREFIX=${TAG_PREFIX-v}
INITIAL_VERSION=${INITIAL_VERSION:-0.0.0}
REMOTE=${REMOTE:-origin}

SEMVER='^[0-9]+\.[0-9]+\.[0-9]+$'

if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
  echo "Invalid bump type: $BUMP_TYPE (major, minor or patch expected)"
  exit 1
elif [[ ! "$INITIAL_VERSION" =~ $SEMVER ]]; then
  echo "Invalid initial version: $INITIAL_VERSION (X.Y.Z expected)"
  exit 1
fi

# Only exact <prefix>X.Y.Z tags count, so pre-release tags (v2.0.0-beta) and tags with a
# longer prefix sharing this one's tail (topaz-v1.0.0 when the prefix is "v") are ignored.
PREVIOUS_VERSION=$(
  git ls-remote --refs --tags "$REMOTE" |
    cut -f2 |
    sed 's|^refs/tags/||' |
    while read -r tag; do
      if [[ "$tag" == "$TAG_PREFIX"* && "${tag#"$TAG_PREFIX"}" =~ $SEMVER ]]; then
        echo "${tag#"$TAG_PREFIX"}"
      fi
    done |
    sort -t. -k1,1nr -k2,2nr -k3,3nr |
    head -1
)

if [ -n "$PREVIOUS_VERSION" ]; then
  PREVIOUS_TAG="${TAG_PREFIX}${PREVIOUS_VERSION}"
  echo "Last tag: $PREVIOUS_TAG"
  BASE_VERSION=$PREVIOUS_VERSION
else
  PREVIOUS_TAG=""
  echo "No ${TAG_PREFIX}X.Y.Z tags found on $REMOTE, bumping from $INITIAL_VERSION"
  BASE_VERSION=$INITIAL_VERSION
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE_VERSION"

case $BUMP_TYPE in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

VERSION="${MAJOR}.${MINOR}.${PATCH}"
TAG="${TAG_PREFIX}${VERSION}"
echo "New version ($BUMP_TYPE): $VERSION"
echo "New tag: $TAG"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "version=$VERSION"
    echo "tag=$TAG"
    echo "previous-version=$PREVIOUS_VERSION"
    echo "previous-tag=$PREVIOUS_TAG"
  } >> "$GITHUB_OUTPUT"
fi
