#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-.}"
PLATFORMS="${2:-linux/amd64,linux/arm64}"

# Extract the construct version tag from the FROM line. jackin-validate already
# enforces a versioned tag is present, so this cannot be empty on a valid Dockerfile.
# Strip any @sha256:... digest pin (added by Renovate's docker:pinDigests) before
# extracting the tag so "0.1-trixie@sha256:..." yields "0.1-trixie".
CONSTRUCT_VERSION=$(awk '/^FROM /{
    ref = $2; sub(/@.*/, "", ref)
    n = split(ref, parts, ":")
    if (n > 1) { print parts[2]; exit }
}' "${REPO_PATH}/Dockerfile")

echo "Building Docker image for platforms: ${PLATFORMS}..."

docker buildx build \
  --platform "$PLATFORMS" \
  --build-arg "CONSTRUCT_VERSION=${CONSTRUCT_VERSION:-unknown}" \
  --file "${REPO_PATH}/Dockerfile" \
  "${REPO_PATH}"

echo "Docker build succeeded for all platforms"
