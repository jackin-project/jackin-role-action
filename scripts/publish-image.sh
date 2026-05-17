#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-.}"
IMAGE="${2}"
PLATFORMS="${3:-linux/amd64,linux/arm64}"

# Extract the construct version tag pinned in the FROM line. jackin-validate
# already enforces its presence, so this cannot be empty on a valid Dockerfile.
# Strip any @sha256:... digest pin (added by Renovate's docker:pinDigests) before
# extracting the tag so "0.1-trixie@sha256:..." yields "0.1-trixie".
CONSTRUCT_VERSION=$(awk '/^FROM /{
    ref = $2; sub(/@.*/, "", ref)
    n = split(ref, parts, ":")
    if (n > 1) { print parts[2]; exit }
}' "${REPO_PATH}/Dockerfile")

short_sha="${GITHUB_SHA::7}"

echo "Publishing Docker image ${IMAGE} for platforms: ${PLATFORMS}..."

docker buildx build \
  --platform "$PLATFORMS" \
  --tag "${IMAGE}:latest" \
  --tag "${IMAGE}:${short_sha}" \
  --build-arg "CONSTRUCT_VERSION=${CONSTRUCT_VERSION:-unknown}" \
  --sbom=true \
  --provenance=true \
  --push \
  "${REPO_PATH}"

{
  echo "image=${IMAGE}"
  echo "short_sha=${short_sha}"
} >> "$GITHUB_OUTPUT"

echo "Published ${IMAGE}:latest and ${IMAGE}:${short_sha}"
