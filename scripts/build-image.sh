#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-.}"
PLATFORMS="${2:-linux/amd64,linux/arm64}"

CONSTRUCT_VERSION=$(jackin-role construct-version "${REPO_PATH}")

echo "Building Docker image for platforms: ${PLATFORMS}..."

secret_args=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    secret_args+=(--secret "id=github_token,env=GITHUB_TOKEN")
fi

docker buildx build \
  "${secret_args[@]}" \
  --platform "$PLATFORMS" \
  --build-arg "CONSTRUCT_VERSION=${CONSTRUCT_VERSION}" \
  --file "${REPO_PATH}/Dockerfile" \
  "${REPO_PATH}"

echo "Docker build succeeded for all platforms"