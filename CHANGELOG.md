# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and the project follows Semantic Versioning while the plugin remains in the `0.x` phase.

## [Unreleased]

## [0.3.0] - 2026-03-17

> Release title: review intelligence + per-project settings

### Added
- **Per-project settings file** (`.claude/pr-review.local.md`): configurable output language, default review source, default repo path, review dimensions per mode, fix-forward exclusion patterns, and developer profile tracking toggle. CLI flags override settings; settings override defaults.
- **`gh pr diff` fallback**: when the target repo is not cloned locally, the skill now uses `gh pr diff <PR#> --repo <owner/repo>` to fetch actual file-level changes via GitHub API instead of silently relying on provider summaries.
- **Severity count validation**: the skill now cross-checks the severity summary line against individual finding detail labels before finalizing, preventing mismatches (e.g., claiming MEDIUM 3 when one is actually LOW).
- **Fix-forward exclusion patterns**: never auto-modify migration files, Dockerfiles, CI workflows, lockfiles, or environment files. These get "Manual fix recommended" instead.
- **Fix-forward commit hygiene**: reads `git log --oneline -10` to match repo commit convention, uses specific-file `git add` only (never broad staging), and never includes `Co-Authored-By` or similar attribution trailers.
- **Developer profile dedup**: checks for existing ticket+date entries before appending to prevent duplicates across multiple review iterations.
- **Output template reference file** (`references/output-template.md`): extracted from SKILL.md for progressive disclosure (SKILL.md reduced from 700 to 572 lines).

### Changed
- **Quick mode depth reduced**: now reviews top 5 dimensions (Bugs, Architecture, React/TypeScript, Error Handling, Performance) instead of all 9, producing meaningfully shorter reviews. Quick mode saves to `[TICKET]-review-quick.md` to avoid overwriting full reviews.
- **Independent review execution order enforced**: Step 4 (independent code review) must complete entirely before reading any AI provider comments in Step 5. This prevents confirmation bias from Copilot/CodeRabbit data contaminating "independent" findings.
- **Step 1 clarified**: now notes which AI providers have data available without reading their actual comments. Inline summaries visible in the PR doc must not influence Step 4.
- **Dirty detection relaxed**: only staged changes (`git diff --cached`) trigger the dirty-repo block. Unstaged modifications (e.g., local `.gitignore` tweaks) are no longer considered dirty.
- **Repo access resolution chain**: `--repo-path` → settings `default_repo_path` → CWD → `gh pr diff` fallback → graceful degradation with explicit disclosure.

### Removed
- **Difficulty scale**: removed the 1-5 difficulty rating and associated criteria table. It was a vestige from the CodeRabbit-only v0.1.0 era with no clear criteria for multi-provider reviews.

### Fixed
- Fix-forward no longer auto-modifies immutable framework files (Supabase migrations, Prisma migrations, etc.).
- Fix-forward no longer uses broad `git add` commands that could stage unrelated user changes.
- Fix-forward no longer includes `Co-Authored-By` attribution in generated commits.
- Fix-forward now matches the target repo's commit message convention.
- Quick mode no longer overwrites full review files (uses `-quick` suffix).

### Release Boundary
- `0.3.0` completes the MVP improvement plan (Phases 0-2): baseline measurement, bug fixes, intelligence improvements, and per-project settings.
- Dedicated agent, PreToolUse hook, `${CLAUDE_PLUGIN_ROOT}` paths, and full plugin restructure are deferred to `0.4.0` (Post-MVP Phase 3).

## [0.2.2] - 2026-03-14

> Release title: mixed-provider auto-mode hardening

#### Added
- Worktree-aware auto mode with deterministic clean worktree preparation for dirty target repos.
- Managed Round N review-doc support with structured `round_meta` and `round_decisions` JSON blocks.
- Provider-neutral decisions artifact generation for mixed GitHub Copilot and CodeRabbit auto mode.

#### Changed
- Auto mode now requires explicit `--live` confirmation before commit, push, reply, or resolve actions.
- Auto mode now resolves the target repo and review doc explicitly instead of guessing from operator context.
- Preview and live mutation steps now run through the same normalized decisions artifact contract.
- Worktree mode now mirrors the authoritative review doc into the prepared worktree before managed round edits.

#### Fixed
- Hardened stale-round protection so reply/resolve steps fail rather than mutating older provider review rounds.
- Hardened rerun behavior so mutation-partial rounds can resume intentionally with persistent per-round artifacts.
- Hardened missing-`--repo-path` handling so auto mode stops instead of drifting into unrelated repos or worktrees.

#### Release Boundary
- `0.2.2` is intentionally a supervised automation release: explicit repo resolution, worktree preparation, managed round docs, decisions artifacts, and dry-run previews are in scope.
- `0.2.2` does not claim autonomous accept/decline judgment or exhaustive live-mutation proof across every edge case.
- Remaining unchecked live or edge-case acceptance criteria are candidate `0.2.3` scope only if rollout pain clusters around repo or branch mismatch validation, legacy review-doc migration, branch-drift blocking, or broader live reply/resolve proof.

## [0.2.1] - 2026-03-13

> Release title: command wrapper and manifest validation fix

### Added
- Explicit `/pr-review` command wrapper for passing raw review arguments safely.

### Changed
- README and rollout docs now position automated provider-aware review as the primary feature and use `/pr-review` as the supported command entrypoint.
- Plugin and marketplace descriptions now highlight automated review as the primary feature.
- Plugin manifest `repository` field now uses the format expected by Claude's plugin validator.

### Fixed
- Fixed marketplace installation failure caused by an invalid `plugin.json` repository field.

## [0.2.0] - 2026-03-13

> Release title: Copilot-aware PR review workflow

### Added
- GitHub Copilot review support alongside existing CodeRabbit handling.
- Provider-neutral scripts for replying to AI review comments and resolving AI review threads.
- Copilot-specific triage guide and repo-level Copilot review instructions.
- Benchmark coverage for Copilot-only, mixed-provider, and quick-review scenarios.

### Changed
- Review output now treats direct code review as primary and AI review triage as provider-aware secondary output.
- Auto review flow now supports `--review-source` selection and `--dry-run` mutation previews.
- Plugin metadata and marketplace metadata now describe Copilot-aware review behavior.

## [0.1.0] - 2026-03-12

> Release title: Initial PR review skill release

### Added
- Initial plugin release for PR review, CodeRabbit triage, fix-forward workflow, and developer feedback tracking.
