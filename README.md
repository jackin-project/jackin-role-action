# jackin-role-action

GitHub Action to validate [jackin](https://github.com/jackin-project/jackin) agent role repos against the project contract and publish multi-platform Docker images.

jackin is experimental preview software and has not reached a stable release yet. This action defaults to the newest preview `jackin-role` build so role validation follows the current preview contract.

## CI — validate and build check

Use the composite action in your `ci.yml`. It runs Dockerfile linting, jackin contract validation, and a single-platform (`linux/amd64`) build check. The build check uses the GitHub Actions BuildKit cache, scoped by repository, path, and platform, so pull request validation can reuse expensive layers across runs.

```yaml
jobs:
  validate:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6
      - uses: jackin-project/jackin-role-action@fe73996146153765c69e3334269e18779e8f3bb9 # latest
```

### CI inputs

| Input | Default | Description |
|-------|---------|-------------|
| `path` | `.` | Path to the agent repo |
| `jackin-version` | `latest-build` | Version of `jackin-role` to use |
| `skip-build` | `false` | Skip the Docker build step (validate only) |

### CI checks performed

1. **Dockerfile linting** — `hadolint` enforces Dockerfile best practices
2. **Required files** — `Dockerfile`, `jackin.role.toml`, `.dockerignore`, `.gitignore`
3. **Dockerfile contract** — construct base image pinned to an approved version
4. **Manifest schema** — valid TOML, no unknown fields, env var rules
5. **Docker build** — `linux/amd64` build check (no push)

## Publish — multi-platform image

Use the reusable workflow in your `publish-image.yml`. It validates the repo, builds `linux/amd64` and `linux/arm64`, merges the platform images into a multi-arch manifest, and signs the result with cosign.

The image name is read from `published_image` in `jackin.role.toml` — no duplication in workflow YAML.

```yaml
jobs:
  publish:
    uses: jackin-project/jackin-role-action/.github/workflows/publish.yml@fe73996146153765c69e3334269e18779e8f3bb9 # latest
    permissions:
      contents: read
      id-token: write
    secrets:
      registry-username: ${{ secrets.DOCKERHUB_USERNAME }}
      registry-password: ${{ secrets.DOCKERHUB_TOKEN }}
```

By default, `linux/amd64` runs on `ubuntu-24.04` and `linux/arm64` runs on `ubuntu-24.04-arm` (native, no QEMU). To use self-hosted runners, pass `runner-amd64`, `runner-arm64`, and `runner-merge`:

```yaml
# Self-hosted runners — native amd64 and arm64
jobs:
  publish:
    uses: jackin-project/jackin-role-action/.github/workflows/publish.yml@fe73996146153765c69e3334269e18779e8f3bb9 # latest
    permissions:
      contents: read
      id-token: write
    with:
      runner-amd64: my-amd64-runner
      runner-arm64: my-arm64-runner
      runner-merge: my-amd64-runner
    secrets:
      registry-username: ${{ secrets.DOCKERHUB_USERNAME }}
      registry-password: ${{ secrets.DOCKERHUB_TOKEN }}
```

When `runner-amd64` and `runner-arm64` are set to the same label, QEMU is used automatically for the `linux/arm64` build:

```yaml
# Single self-hosted runner — arm64 via QEMU
    with:
      runner-amd64: my-runner
      runner-arm64: my-runner
      runner-merge: my-runner
```

### Publish inputs

| Input | Default | Description |
|-------|---------|-------------|
| `jackin-version` | `latest-build` | Version of `jackin-role` to use |
| `registry` | `https://index.docker.io/v1/` | Registry URL for docker login |
| `runner-amd64` | `ubuntu-24.04` | Runner label for the `linux/amd64` build job |
| `runner-arm64` | `ubuntu-24.04-arm` | Runner label for the `linux/arm64` build job. When equal to `runner-amd64`, QEMU is used automatically |
| `runner-merge` | `ubuntu-24.04` | Runner label for the manifest merge and sign job |

### Publish secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `registry-username` | yes | Registry username |
| `registry-password` | yes | Registry password or token |
| `github-readonly-token` | no | Read-only GitHub token passed into the Docker build as the `github_token` secret. Avoids API rate limits when the Dockerfile downloads GitHub-hosted tools (mise, cargo-binstall, etc.). Falls back to `github.token` if omitted. |

### Build caching

The CI build check uses GitHub Actions cache storage through BuildKit's `type=gha` backend. This cache is best for pull request validation and branch builds where the image is not pushed.

The publish workflow uses registry-backed Docker layer caching. After each build, two per-platform cache manifests are written to the same repository:

- `<image>:buildcache-amd64`
- `<image>:buildcache-arm64`

`mode=max` exports all intermediate layers, not just the final image. Expensive tool-install layers (Rust toolchain, Java runtime, Node, etc.) are cache hits on subsequent builds as long as their `ARG` values and parent layers have not changed.

**The first build after creating a new role repo is always cold** — it populates the cache. Subsequent builds with no Dockerfile changes typically complete in under a minute.

Cache tags are written using the same `registry-username` / `registry-password` secrets. No additional credentials are needed.

## Dockerfile best practices for role authors

### Pin every tool version with an ARG

Every tool installed in the Dockerfile should have a dedicated `ARG` so that bumping one version only invalidates that tool's layer and the layers that follow it:

```dockerfile
ARG RUST_VERSION=1.85.0
ARG NODE_VERSION=24.0.0
ARG CARGO_BINSTALL_VERSION=1.19.1
```

Avoid `latest`, `lts`, or unversioned installs — they produce non-deterministic layers that can bust the registry cache when the resolved version changes.

### One RUN per tool (deliberate layer separation)

Put each tool installation in its own `RUN` instruction, keyed to its version `ARG`. This trips hadolint `DL3059` but the cache benefit is intentional — suppress with a comment:

```dockerfile
# Per-tool RUNs are deliberate: bumping one ARG only invalidates that
# tool's layer. Trips hadolint DL3059; the cache reuse is worth it.
RUN --mount=type=secret,id=github_token,uid=1000,required=false \
    GITHUB_TOKEN=$(cat /run/secrets/github_token 2>/dev/null || true) \
    mise install "rust@${RUST_VERSION}" && \
    mise use -g --pin "rust@${RUST_VERSION}"

RUN --mount=type=secret,id=github_token,uid=1000,required=false \
    GITHUB_TOKEN=$(cat /run/secrets/github_token 2>/dev/null || true) \
    mise install "node@${NODE_VERSION}" && \
    mise use -g --pin "node@${NODE_VERSION}"
```

### Order layers by stability (slowest-changing first)

Layers later in the Dockerfile inherit cache invalidation from all layers above them. Place the largest, least-frequently-bumped downloads first. A version bump to a volatile tool should not force a re-download of a large stable runtime.

Recommended order: `large runtimes (JDK, etc.) → build tools (protoc, cmake) → Rust → Node/Bun → cargo tools → npm globals → agent tooling (caveman, etc.)`

### Use `cargo binstall` instead of `cargo install`

`cargo install` compiles crates from source — this can add 3–10 minutes per crate. `cargo-binstall` downloads prebuilt binaries from GitHub Releases instead.

Install `cargo-binstall` via mise first (own layer, own version ARG), then use it for cargo tools:

```dockerfile
ARG CARGO_BINSTALL_VERSION=1.19.1

RUN --mount=type=secret,id=github_token,uid=1000,required=false \
    GITHUB_TOKEN=$(cat /run/secrets/github_token 2>/dev/null || true) \
    mise install "cargo-binstall@${CARGO_BINSTALL_VERSION}" && \
    mise use -g --pin "cargo-binstall@${CARGO_BINSTALL_VERSION}"

RUN --mount=type=secret,id=github_token,uid=1000,required=false \
    --mount=type=cache,target=/home/agent/.cargo/registry,uid=1000 \
    --mount=type=cache,target=/home/agent/.cargo/git,uid=1000 \
    GITHUB_TOKEN=$(cat /run/secrets/github_token 2>/dev/null || true) \
    . ~/.profile && \
    cargo binstall --no-confirm cargo-nextest cargo-watch lychee
```

### Use BuildKit cache mounts for mise cache

The construct image runs as `agent` with `HOME=/home/agent`. Its mise defaults are:

- cache: `/home/agent/.cache/mise`
- downloads: `/home/agent/.local/share/mise/downloads`
- installs: `/home/agent/.local/share/mise/installs`

Cache the first location whenever a Dockerfile installs tools with mise. Do **not** cache-mount the downloads or installs directories: some mise plugins extract through `downloads`, and BuildKit cache mount contents are not committed into the final image, so tools installed under `installs` would be missing at runtime.

```dockerfile
RUN mkdir -p "${HOME}/.cache/mise"

RUN --mount=type=secret,id=github_token,uid=1000,required=false \
    --mount=type=cache,target=/home/agent/.cache/mise,uid=1000 \
    GITHUB_TOKEN=$(cat /run/secrets/github_token 2>/dev/null || true) \
    mise install "node@${NODE_VERSION}" && \
    mise use -g --pin "node@${NODE_VERSION}"
```

### Use BuildKit cache mounts for Cargo

`--mount=type=cache` on `.cargo/registry` and `.cargo/git` preserves the crate registry across layer rebuilds. On **persistent (self-hosted) runners**, this means a Rust version bump does not re-download all crates — only the compilation step is repeated. On ephemeral runners (GitHub-hosted), cache mounts have no cross-run benefit; the registry cache handles that case instead.

### Use apt cache mounts for the system package layer

The same principle applies to `apt-get`. Cache mounts speed up the apt layer when the base image bumps:

```dockerfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    sudo apt-get update && \
    sudo apt-get install -y --no-install-recommends \
    build-essential libssl-dev openssl pkg-config && \
    sudo apt-get autoremove -y
```

When using cache mounts, omit the final `rm -rf /var/cache/apt /var/lib/apt` cleanup — those directories are the cache and must not be removed from the mount.

### Pass `github-readonly-token` to avoid rate limiting

If your Dockerfile downloads tools from GitHub (via mise, `cargo-binstall`, or direct `curl`), pass a read-only GitHub token as a build secret. Without it, GitHub's unauthenticated rate limit (60 requests/hour per IP) can cause flaky failures on shared runners.

In `publish-image.yml`:

```yaml
secrets:
  github-readonly-token: ${{ secrets.GH_READONLY_TOKEN }}
```

In the Dockerfile:

```dockerfile
RUN --mount=type=secret,id=github_token,uid=1000,required=false \
    GITHUB_TOKEN=$(cat /run/secrets/github_token 2>/dev/null || true) \
    mise install "rust@${RUST_VERSION}"
```

### `jackin.role.toml` — published image

The `published_image` field must be set for the publish workflow to work:

```toml
published_image = "docker.io/myorg/jackin-my-role"
```

## License

Apache License 2.0
