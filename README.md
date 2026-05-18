# jackin-role-action

GitHub Action to validate [jackin](https://github.com/jackin-project/jackin) agent role repos against the project contract and publish multi-platform Docker images.

jackin is experimental preview software and has not reached a stable release yet. This action defaults to the newest preview `jackin-role` build so role validation follows the current preview contract.

## CI — validate and build check

Use the composite action in your `ci.yml`. It runs Dockerfile linting, jackin contract validation, and a single-platform (`linux/amd64`) build check.

```yaml
jobs:
  validate:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6
      - uses: jackin-project/jackin-role-action@75a8a8b124332a631346a8ea81fdb883053745eb # latest
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

Use the reusable workflow in your `publish-image.yml`. It validates the repo, builds `linux/amd64` and `linux/arm64` on native runners (no QEMU), merges the platform images into a multi-arch manifest, and signs the result with cosign.

The image name is read from `published_image` in `jackin.role.toml` — no duplication in workflow YAML.

```yaml
jobs:
  publish:
    uses: jackin-project/jackin-role-action/.github/workflows/publish.yml@75a8a8b124332a631346a8ea81fdb883053745eb # latest
    permissions:
      contents: read
      id-token: write
    secrets:
      registry-username: ${{ secrets.DOCKERHUB_USERNAME }}
      registry-password: ${{ secrets.DOCKERHUB_TOKEN }}
```

### Publish inputs

| Input | Default | Description |
|-------|---------|-------------|
| `jackin-version` | `latest-build` | Version of `jackin-role` to use |
| `registry` | `https://index.docker.io/v1/` | Registry URL for docker login |

### Publish secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `registry-username` | yes | Registry username |
| `registry-password` | yes | Registry password or token |

### `jackin.role.toml` — published image

The `published_image` field must be set for the publish workflow to work:

```toml
published_image = "docker.io/myorg/jackin-my-role"
```

## License

Apache License 2.0
