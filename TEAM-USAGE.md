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
   - Use this when you want fetch + review + fix-forward + managed reply/resolve previews in one flow.
   - Auto mode now stops safely unless the repo/worktree is valid and `--live` is explicitly present.
   - Example:
     ```bash
     /pr-review --auto 161 --review-source all --repo-path /abs/path/to/repo --review-doc /abs/path/to/repo/docs/reviews/MOVE-658-review.md --worktree auto
     ```

## Operator Checklist

### Clean repo

- Use the repo directly when the target product repo is already clean and checked out to the PR head branch.
- Example:
  ```bash
  /pr-review --auto 161 --review-source all --repo-path /abs/path/to/repo --review-doc /abs/path/to/repo/docs/reviews/MOVE-658-review.md
  ```

### Dirty repo

- Do **not** stash automatically.
- Prefer:
  ```bash
  /pr-review --auto 161 --review-source all --repo-path /abs/path/to/repo --review-doc /abs/path/to/repo/docs/reviews/MOVE-658-review.md --worktree auto
  ```
- If you need a specific location:
  ```bash
  /pr-review --auto 161 --review-source all --repo-path /abs/path/to/repo --review-doc /abs/path/to/repo/docs/reviews/MOVE-658-review.md --worktree /abs/path/to/worktree
  ```

### Review-doc resolution

- If the branch basename has exactly one ticket match like `MOVE-658`, the default review doc path is:
  ```text
  docs/reviews/MOVE-658-review.md
  ```
- Pass `--review-doc <path>` when:
  - the branch shape is `TICKET/slug` like `MOVE-658/social-login-native`, because the basename is only `social-login-native`
  - the branch basename has zero ticket matches
  - the branch basename has multiple ticket matches
  - the repo uses a non-standard review-doc path
- Keep the review doc inside the target repo. In worktree mode, auto review mirrors that file into the prepared worktree before it appends the managed round.
- On a first-run auto review, the resolved review doc path may not exist yet. The workflow should still bootstrap the first review document at that exact path during Phase B.

### Dry-run before live mutation

1. Run auto mode without `--live`.
2. Inspect:
   - the appended/resumed Round N section in the review doc
   - `.pr-review/pr-<PR_NUMBER>/round-<N>/decisions.json`
   - the reply/resolve preview outputs in the same round directory
3. Update every `pending` entry in `round_decisions` to `accepted` or `declined`.
4. Re-run the same command with `--live`.
5. Expect a mandatory live preflight via `generate-decisions-json.sh --require-live-ready` before any commit or push. If any latest-round row is still `pending`, the workflow must stop there.

## Practical Defaults

- If the PR only has GitHub Copilot review, use `--review-source copilot`.
- If the PR has both Copilot and CodeRabbit, use `--review-source all`.
- If you only need code findings and do not care about AI comment triage, use `--quick`.
- Prefer PR URLs or PR numbers over local markdown when Copilot review is involved, because the skill can fetch structured review data and create a `*.review-data.json` sidecar.

## Rollout Guidance Learned From PR #161

- Keep dry-run proof separate from live mutation proof.
- Use `--worktree auto` when the product repo is dirty so fix-forward changes stay isolated.
- Treat the managed round doc as the source of truth for current provider review ids, round state, and artifact paths.
- Treat `needs-repo-path` as a hard stop. If auto mode is outside the product repo and no explicit `--repo-path` is provided, do not continue by guessing from existing worktrees.
- If live mutation succeeds only partially, preserve `mutation-partial` or `blocked` and resume intentionally instead of creating a fake “done” state.

## v0.2.2 Follow-Up Policy

- Treat `0.2.2` as the supported release for supervised dry-run automation and worktree-safe fix-forward preparation.
- Do not reopen the workflow just to chase benchmark noise if the dry-run canary and operator flow are already working.
- Open a `0.2.3` follow-up only if rollout exposes repeated pain in one of these areas: repo or branch mismatch validation, legacy review-doc migration, branch-drift blocking before `--live`, or broader live reply/resolve proof.
- Leave the rest alone unless it interferes with the lean-automation goal or creates repeated operator confusion.
