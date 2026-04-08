#!/usr/bin/env bash
set -euo pipefail

rm -f /tmp/jackin-validate

VERSION="${1:-latest}"
REPO="jackin-project/jackin"

if [ "$VERSION" = "latest" ]; then
  TAG=$(gh api "repos/${REPO}/releases/latest" --jq '.tag_name')
  if [ -z "$TAG" ]; then
    echo "Failed to resolve latest release tag from ${REPO}" >&2
    exit 1
  fi
else
  VERSION_CLEAN="${VERSION#v}"
  if [[ ! "$VERSION_CLEAN" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "Invalid version format: ${VERSION}" >&2
    exit 1
  fi
  TAG="v${VERSION_CLEAN}"
fi

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  TARGET="x86_64-unknown-linux-gnu" ;;
  aarch64) TARGET="aarch64-unknown-linux-gnu" ;;
  *)       echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

VERSION_NUM="${TAG#v}"
ARCHIVE="jackin-${VERSION_NUM}-${TARGET}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${ARCHIVE}"

echo "Downloading jackin-validate ${TAG} for ${TARGET}..."
curl -fsSL "$DOWNLOAD_URL" -o "/tmp/${ARCHIVE}"

CHECKSUM_URL="https://github.com/${REPO}/releases/download/${TAG}/${ARCHIVE}.sha256"
curl -fsSL "$CHECKSUM_URL" -o "/tmp/${ARCHIVE}.sha256"
cd /tmp && sha256sum --check "${ARCHIVE}.sha256"

tar -xzf "/tmp/${ARCHIVE}" -C /tmp jackin-validate
chmod +x /tmp/jackin-validate
echo "/tmp" >> "$GITHUB_PATH"
echo "jackin-validate ${TAG} installed"
