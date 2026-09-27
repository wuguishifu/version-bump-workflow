#!/usr/bin/env bash
# Builds docker image references for a version: <registry>/<image>:<version>-<short sha>
# plus <registry>/<image>:latest.
#
# Env:
#   VERSION   version to tag with (required)
#   IMAGE     image path within the registry, e.g. wuguishifu/universe/topaz (required)
#   REGISTRY  registry host (default: ghcr.io)

set -euo pipefail

VERSION=${VERSION:-}
IMAGE=${IMAGE:-}
REGISTRY=${REGISTRY:-ghcr.io}

if [ -z "$VERSION" ] || [ -z "$IMAGE" ]; then
  echo "Error: VERSION and IMAGE are required."
  exit 1
fi

if SHORT_SHA=$(git rev-parse --short=8 HEAD 2> /dev/null); then
  :
elif [ -n "${GITHUB_SHA:-}" ]; then
  SHORT_SHA=${GITHUB_SHA:0:8}
else
  echo "Error: not in a git repository and GITHUB_SHA is not set."
  exit 1
fi

# Registries require lowercase repository names; github.repository can contain uppercase.
IMAGE_NAME=$(echo "${REGISTRY}/${IMAGE}" | tr '[:upper:]' '[:lower:]')
DOCKER_TAG="${VERSION}-${SHORT_SHA}"
DOCKER_IMAGE="${IMAGE_NAME}:${DOCKER_TAG}"
DOCKER_IMAGE_LATEST="${IMAGE_NAME}:latest"

echo "Docker tag: $DOCKER_TAG"
echo "Docker image: $DOCKER_IMAGE"
echo "Docker image latest: $DOCKER_IMAGE_LATEST"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "tag=$DOCKER_TAG"
    echo "image=$DOCKER_IMAGE"
    echo "image-latest=$DOCKER_IMAGE_LATEST"
    echo "image-name=$IMAGE_NAME"
  } >> "$GITHUB_OUTPUT"
fi
