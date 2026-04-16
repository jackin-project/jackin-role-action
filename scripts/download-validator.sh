#!/usr/bin/env bash
set -euo pipefail

rm -f /tmp/jackin-validate

VERSION="${1:-latest}"
REPO="jackin-project/jackin"
WORKFLOW_FILE="ci.yml"

resolve_target() {
  local arch="$1"
  case "$arch" in
    x86_64) echo "x86_64-unknown-linux-gnu" ;;
    aarch64) echo "aarch64-unknown-linux-gnu" ;;
    *)
      echo "Unsupported architecture: $arch" >&2
      exit 1
      ;;
  esac
}

download_from_release() {
  local tag="$1"
  local target="$2"
  local version_num archive download_url checksum_url

  version_num="${tag#v}"
  archive="jackin-${version_num}-${target}.tar.gz"
  download_url="https://github.com/${REPO}/releases/download/${tag}/${archive}"
  checksum_url="https://github.com/${REPO}/releases/download/${tag}/${archive}.sha256"

  echo "Downloading jackin-validate ${tag} for ${target}..."
  curl -fsSL "$download_url" -o "/tmp/${archive}"
  curl -fsSL "$checksum_url" -o "/tmp/${archive}.sha256"
  cd /tmp && sha256sum --check "${archive}.sha256"
  tar -xzf "/tmp/${archive}" -C /tmp jackin-validate
}

download_from_latest_build() {
  local target="$1"
  local artifact_name="jackin-validate-${target}"
  local artifact_dir="/tmp/jackin-validate-artifact"
  local artifact_zip="/tmp/jackin-validate-artifact.zip"
  local run_id artifact_id archive checksum

  echo "Resolving latest successful ${WORKFLOW_FILE} build for ${target}..."
  # Pick the first match inside jq rather than piping through `head -n1`:
  # under `set -o pipefail`, head closing the pipe early can SIGPIPE the
  # upstream process, surfacing as exit 141 and flaking CI unpredictably.
  run_id=$(gh api -X GET "repos/${REPO}/actions/workflows/${WORKFLOW_FILE}/runs" \
    -f branch=main \
    -f per_page=20 \
    --jq '[.workflow_runs[] | select(.status == "completed" and .conclusion == "success")] | .[0].id // empty')

  if [ -z "$run_id" ]; then
    echo "Failed to resolve a successful ${WORKFLOW_FILE} run on main from ${REPO}" >&2
    exit 1
  fi

  artifact_id=$(gh api -X GET "repos/${REPO}/actions/runs/${run_id}/artifacts" \
    --jq "[.artifacts[] | select(.name == \"${artifact_name}\")] | .[0].id // empty")

  if [ -z "$artifact_id" ]; then
    echo "Failed to find artifact ${artifact_name} in workflow run ${run_id}" >&2
    exit 1
  fi

  rm -rf "$artifact_dir" "$artifact_zip"
  gh api -H "Accept: application/vnd.github+json" \
    "repos/${REPO}/actions/artifacts/${artifact_id}/zip" > "$artifact_zip"
  unzip -oq "$artifact_zip" -d "$artifact_dir"

  archive=$(find "$artifact_dir" -maxdepth 1 -name 'jackin-validate-*.tar.gz' -print -quit)
  checksum=$(find "$artifact_dir" -maxdepth 1 -name 'jackin-validate-*.tar.gz.sha256' -print -quit)

  if [ -z "$archive" ] || [ -z "$checksum" ]; then
    echo "Artifact ${artifact_name} is missing the packaged validator archive or checksum" >&2
    exit 1
  fi

  (
    cd "$artifact_dir"
    sha256sum --check "$(basename "$checksum")"
  )
  tar -xzf "$archive" -C /tmp jackin-validate
}

if [ "$VERSION" = "latest" ]; then
  TAG=$(gh api "repos/${REPO}/releases/latest" --jq '.tag_name')
  if [ -z "$TAG" ]; then
    echo "Failed to resolve latest release tag from ${REPO}" >&2
    exit 1
  fi
elif [ "$VERSION" = "latest-build" ]; then
  TAG=""
else
  VERSION_CLEAN="${VERSION#v}"
  if [[ ! "$VERSION_CLEAN" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "Invalid version format: ${VERSION}" >&2
    exit 1
  fi
  TAG="v${VERSION_CLEAN}"
fi

TARGET=$(resolve_target "$(uname -m)")

if [ "$VERSION" = "latest-build" ]; then
  download_from_latest_build "$TARGET"
else
  download_from_release "$TAG" "$TARGET"
fi

chmod +x /tmp/jackin-validate
echo "/tmp" >> "$GITHUB_PATH"
if [ "$VERSION" = "latest-build" ]; then
  echo "jackin-validate latest-build installed"
else
  echo "jackin-validate ${TAG} installed"
fi
