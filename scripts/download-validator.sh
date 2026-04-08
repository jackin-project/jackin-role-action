#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-latest}"
REPO="jackin-project/jackin"

if [ "$VERSION" = "latest" ]; then
  TAG=$(gh api "repos/${REPO}/releases/latest" --jq '.tag_name')
else
  TAG="v${VERSION}"
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
tar -xzf "/tmp/${ARCHIVE}" -C /tmp jackin-validate
chmod +x /tmp/jackin-validate
echo "/tmp" >> "$GITHUB_PATH"
echo "jackin-validate ${TAG} installed"
