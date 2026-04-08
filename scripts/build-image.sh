#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-.}"
PLATFORMS="${2:-linux/amd64,linux/arm64}"

echo "Building Docker image for platforms: ${PLATFORMS}..."

docker buildx build \
  --platform "$PLATFORMS" \
  --file "${REPO_PATH}/Dockerfile" \
  "${REPO_PATH}"

echo "Docker build succeeded for all platforms"
