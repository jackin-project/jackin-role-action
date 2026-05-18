#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-.}"
IMAGE="${2}"
PLATFORMS="${3:-linux/amd64,linux/arm64}"

CONSTRUCT_VERSION=$(jackin-role construct-version "${REPO_PATH}")

short_sha="${GITHUB_SHA::7}"

echo "Publishing Docker image ${IMAGE} for platforms: ${PLATFORMS}..."

secret_args=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    secret_args+=(--secret "id=github_token,env=GITHUB_TOKEN")
fi

docker buildx build \
  "${secret_args[@]}" \
  --platform "$PLATFORMS" \
  --tag "${IMAGE}:latest" \
  --tag "${IMAGE}:${short_sha}" \
  --build-arg "CONSTRUCT_VERSION=${CONSTRUCT_VERSION}" \
  --sbom=true \
  --provenance=true \
  --push \
  "${REPO_PATH}"

{
  echo "image=${IMAGE}"
  echo "short_sha=${short_sha}"
} >> "$GITHUB_OUTPUT"

echo "Published ${IMAGE}:latest and ${IMAGE}:${short_sha}"