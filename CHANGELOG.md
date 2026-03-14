# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and the project follows Semantic Versioning while the plugin remains in the `0.x` phase.

## [Unreleased]

### 0.2.2

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
