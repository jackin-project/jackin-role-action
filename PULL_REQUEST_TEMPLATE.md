<!--
Rules:
- One paragraph per section, no hard-wrap.
- No file-by-file changelog (use the diff).
- "Related pull requests" only when the PR spans multiple repos.
- Drop headings you don't need.
-->

## Related pull requests

- <https://github.com/org/repo/pull/N>

## Summary

<One paragraph: what shipped, who benefits, how it changes their flow.>

## What's deferred (follow-up PRs)

- <follow-up 1>

## Verify locally

```sh
# Clone and check out the branch
git clone https://github.com/jackin-project/jackin-role-action.git
cd jackin-role-action
git fetch origin <BRANCH_NAME>
git checkout <BRANCH_NAME>
```

<Describe the role repo workflow steps to test the action change, e.g. trigger a CI run or publish run against a test role repo.>
