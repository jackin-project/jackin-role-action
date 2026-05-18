# validate-agent-action

GitHub Action to validate [jackin](https://github.com/jackin-project/jackin) agent repos against the project contract.

jackin is experimental preview software and has not reached a stable release yet. This action defaults to the newest preview `jackin-role` build so role validation follows the current preview contract.

## Checks

1. **Required files** — `Dockerfile`, `jackin.agent.toml`, `.dockerignore`, `.gitignore`
2. **Dockerfile contract** — final stage must be `FROM projectjackin/construct:trixie`
3. **Manifest schema** — valid TOML, no unknown fields, env var rules
4. **Docker build** — multi-platform build (amd64 + arm64)

## Usage

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: jackin-project/validate-agent-action@v1
```

The default is equivalent to setting `jackin-version: latest-build` explicitly:

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: jackin-project/validate-agent-action@v1
        with:
          jackin-version: latest-build
```

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `path` | `.` | Path to the agent repo |
| `jackin-version` | `latest-build` | Version of `jackin-role` to use. Use `latest-build` for the newest preview validator artifact |
| `build-platforms` | `linux/amd64,linux/arm64` | Docker platforms to build |
| `skip-build` | `false` | Skip Docker build step |

## License

Apache License 2.0
