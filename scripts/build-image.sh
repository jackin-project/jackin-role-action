#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-.}"
PLATFORMS="${2:-linux/amd64,linux/arm64}"
IMAGE="${IMAGE:-}"
PUSH="${PUSH:-false}"

# Extract construct version tag from the FROM line, stripping any digest pin.
# e.g. "FROM projectjackin/construct:0.1-trixie@sha256:abc" → "0.1-trixie"
CONSTRUCT_VERSION=$(grep -m1 '^FROM projectjackin/construct:' "${REPO_PATH}/Dockerfile" \
  | sed 's|^FROM projectjackin/construct:\([^@ ]*\).*|\1|')

echo "Building Docker image for platforms: ${PLATFORMS} (construct_version=${CONSTRUCT_VERSION})..."

BUILD_ARGS=(
  --platform "$PLATFORMS"
  --file "${REPO_PATH}/Dockerfile"
  --build-arg "CONSTRUCT_VERSION=${CONSTRUCT_VERSION}"
  --sbom=true
  --provenance=true
)

if [ -n "$IMAGE" ]; then
  short_sha="${GITHUB_SHA::7}"
  BUILD_ARGS+=(--tag "${IMAGE}:latest" --tag "${IMAGE}:${short_sha}")
fi

if [ "$PUSH" = "true" ]; then
  BUILD_ARGS+=(--push)
fi

docker buildx build "${BUILD_ARGS[@]}" "${REPO_PATH}"

echo "Docker build succeeded for all platforms"
