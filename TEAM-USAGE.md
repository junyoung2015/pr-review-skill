# Team Usage Note

Use this skill in three tiers:

1. **Quick review**
   - Fastest path when you only want direct code findings.
   - Example:
     ```bash
     /pr-review https://github.com/demodev-lab/moving-frontend/pull/161 --quick
     ```

2. **Provider-aware review**
   - Use this when the PR has GitHub Copilot review, CodeRabbit, or both.
   - Examples:
     ```bash
     /pr-review https://github.com/demodev-lab/moving-frontend/pull/161 --review-source copilot
     /pr-review https://github.com/demodev-lab/moving-frontend/pull/161 --review-source all
     ```

3. **Auto review**
   - Use this only when you want fetch + review + fix-forward in one flow.
   - The workflow should still pause before commit / push / live GitHub reply actions.
   - Example:
     ```bash
     /pr-review --auto 161 --review-source all
     ```

## Safe rollout rule

Before posting replies or resolving threads, preview the mutations:

```bash
skills/pr-review/scripts/post-ai-review-comments.sh 161 /tmp/pr-161-decisions.json --dry-run
skills/pr-review/scripts/resolve-ai-review-threads.sh 161 /tmp/pr-161-decisions.json --dry-run
```

`--dry-run` previews GitHub mutations only. It does not push anything.

## Practical defaults

- If the PR only has GitHub Copilot review, use `--review-source copilot`.
- If the PR has both Copilot and CodeRabbit, use `--review-source all`.
- If you only need code findings and do not care about AI comment triage, use `--quick`.
- Prefer PR URLs or PR numbers over local markdown when Copilot review is involved, because the skill can fetch structured review data and create a `*.review-data.json` sidecar.
