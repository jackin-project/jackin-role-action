# CLAUDE.md

See [AGENTS.md](AGENTS.md) for shared agent instructions.

This is a **public composite GitHub Action** used by consumer repos in `jackin-project`. Every consumer invocation runs the shell scripts here with caller-supplied inputs and `GITHUB_TOKEN` access. The two fastest regression paths are (a) un-quoting a shell variable, and (b) referencing a third-party action by tag instead of SHA — both are specifically forbidden in AGENTS.md.

This repository uses `main` as its primary branch.
