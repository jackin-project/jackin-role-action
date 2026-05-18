#!/usr/bin/env bash
set -euo pipefail

rm -f /tmp/jackin-role

VERSION="${1:-latest-build}"
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

  echo "Downloading jackin-role ${tag} for ${target}..."
  curl -fsSL "$download_url" -o "/tmp/${archive}"
  curl -fsSL "$checksum_url" -o "/tmp/${archive}.sha256"
  cd /tmp && sha256sum --check "${archive}.sha256"
  tar -xzf "/tmp/${archive}" -C /tmp jackin-role
}

download_from_latest_build() {
  local target="$1"
  local artifact_name="jackin-role-${target}"
  local artifact_dir="/tmp/jackin-role-artifact"
  local artifact_zip="/tmp/jackin-role-artifact.zip"
  local run_id artifact_id archive checksum

  echo "Resolving latest preview validator build for ${target}..."

  # Walk recent successful CI runs looking for the first one that actually
  # uploaded the build-validator artifact. Non-Rust commits (e.g. Docker image
  # bumps) skip build-validator, so the most-recent successful run may have
  # no artifacts — scanning avoids a false "not found" failure in that case.
  run_id=""
  while IFS= read -r candidate_id; do
    candidate_artifact_id=$(gh api -X GET "repos/${REPO}/actions/runs/${candidate_id}/artifacts" \
      --jq "[.artifacts[] | select(.name == \"${artifact_name}\")] | .[0].id // empty")
    if [ -n "$candidate_artifact_id" ]; then
      run_id="$candidate_id"
      artifact_id="$candidate_artifact_id"
      break
    fi
  done < <(gh api -X GET "repos/${REPO}/actions/workflows/${WORKFLOW_FILE}/runs" \
    -f branch=main \
    -f per_page=20 \
    --jq '[.workflow_runs[] | select(.status == "completed" and .conclusion == "success")] | .[].id')

  if [ -z "$run_id" ]; then
    echo "Failed to resolve a preview validator build from ${REPO}" >&2
    exit 1
  fi

  echo "Using artifact ${artifact_name} from workflow run ${run_id}"

  rm -rf "$artifact_dir" "$artifact_zip"
  gh api -H "Accept: application/vnd.github+json" \
    "repos/${REPO}/actions/artifacts/${artifact_id}/zip" > "$artifact_zip"
  unzip -oq "$artifact_zip" -d "$artifact_dir"

  archive=$(find "$artifact_dir" -maxdepth 1 -name 'jackin-role-*.tar.gz' -print -quit)
  checksum=$(find "$artifact_dir" -maxdepth 1 -name 'jackin-role-*.tar.gz.sha256' -print -quit)

  if [ -z "$archive" ] || [ -z "$checksum" ]; then
    echo "Artifact ${artifact_name} is missing the packaged validator archive or checksum" >&2
    exit 1
  fi

  (
    cd "$artifact_dir"
    sha256sum --check "$(basename "$checksum")"
  )
  tar -xzf "$archive" -C /tmp jackin-role
}

if [ "$VERSION" = "latest" ] || [ "$VERSION" = "latest-build" ]; then
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

if [ "$VERSION" = "latest" ] || [ "$VERSION" = "latest-build" ]; then
  download_from_latest_build "$TARGET"
else
  download_from_release "$TAG" "$TARGET"
fi

chmod +x /tmp/jackin-role
echo "/tmp" >> "$GITHUB_PATH"
if [ "$VERSION" = "latest" ] || [ "$VERSION" = "latest-build" ]; then
  echo "jackin-role latest-build installed"
else
  echo "jackin-role ${TAG} installed"
fi
