#!/usr/bin/env bash
# Rewrites the top-level "version" field of a package.json in place, leaving the rest of
# the file's formatting untouched.
#
# Env:
#   VERSION       version to write, e.g. 1.2.3 (required)
#   PACKAGE_JSON  path to the package.json (default: package.json)

set -euo pipefail

VERSION=${VERSION:-}
PACKAGE_JSON=${PACKAGE_JSON:-package.json}

if [ -z "$VERSION" ]; then
  echo "Error: no version given."
  exit 1
elif [[ ! "$VERSION" =~ ^[0-9A-Za-z.+-]+$ ]]; then
  echo "Error: invalid version: $VERSION"
  exit 1
elif [ ! -f "$PACKAGE_JSON" ]; then
  echo "Error: $PACKAGE_JSON not found."
  exit 1
fi

# Top-level keys are the only ones indented by exactly two spaces.
if ! grep -q '^  "version": ".*"' "$PACKAGE_JSON"; then
  echo "Error: no top-level \"version\" field found in $PACKAGE_JSON."
  exit 1
fi

echo "Updating $PACKAGE_JSON to version $VERSION"

tmpfile="$(mktemp)"
sed 's/^\(  "version": \)".*"/\1"'"$VERSION"'"/' "$PACKAGE_JSON" > "$tmpfile"
# cat instead of mv so the file keeps its permissions.
cat "$tmpfile" > "$PACKAGE_JSON"
rm "$tmpfile"

echo "Updated $PACKAGE_JSON"
