---
name: "Enterprise Definition of Done"
description: "Enforceable quality checklist for Brain v0.2.x — every merge to master must satisfy all gates"
type: audit
date: 2026-02-21
version: "1.0.0"
status: active
---

# Enterprise Definition of Done

Every merge to `master` MUST satisfy ALL gates below. A single FAIL = merge blocked.

## CI Gates (Automated)

| # | Gate | Command | Blocking | Source of Truth |
|---|------|---------|----------|-----------------|
| 1 | PHP Syntax | `php -l` on all `.php` files | YES | `brain-lint.yml` → audit-enterprise.sh Check 1 |
| 2 | Unit Tests | `composer test` (233+ tests, 0 failures) | YES | `brain-lint.yml` → audit-enterprise.sh Check 2 |
| 3 | Static Analysis (Core) | `composer analyse` in core/ (phpstan level 2) | YES | `brain-lint.yml` → `core/phpstan.neon` |
| 4 | Static Analysis (CLI) | `composer analyse` in cli/ (phpstan level 0) | YES | `brain-lint.yml` → `cli/phpstan.neon` |
| 5 | Secret Scanning | `bash scripts/scan-secrets.sh` (exit 0) | YES | `brain-lint.yml` → `scripts/scan-secrets.sh` |
| 6 | Enterprise Audit | `bash scripts/audit-enterprise.sh` (exit 0) | YES | `brain-lint.yml` → `scripts/audit-enterprise.sh` |
| 7 | Compile Discipline | Node source ↔ compiled artifact drift check | YES | `brain-lint.yml` inline step |
| 8 | Benchmark Dry-Run | `composer benchmark:dry` (0 errors) | YES | `brain-benchmark.yml` → `scripts/benchmark-llm-suite.sh` |
| 9 | Release Gate | Version/pin/manifest/bundle validation | YES | `brain-release.yml` → `scripts/build-release-bundle.sh` |

## Enterprise Audit Sub-Gates (19 Checks)

All 19 checks in `audit-enterprise.sh` must PASS or WARN (no FAIL):

| Check | What it catches | Severity |
|-------|----------------|----------|
| 1. PHP syntax | Parse errors in all PHP files | FAIL |
| 2. PHPUnit | Test failures or errors | FAIL |
| 3. Silent catch blocks | `catch (\Throwable) {}` with empty body | WARN |
| 4. Debug artifacts | `dd()`, `dump()`, `var_dump()`, `print_r()` | WARN |
| 5. TODO/FIXME | Unresolved items | INFO |
| 6. Unsafe exec | `shell_exec()`, `eval()` | WARN |
| 7. Shell safety | Missing `set -euo pipefail` in scripts | WARN |
| 8. No-op escape methods | Contract lie: method named *escape* returns input unchanged | WARN |
| 9. Trait LSB | `self::` in traits where `static::` required | WARN |
| 10. Known typos | "Standarts", "Compliation", etc. | FAIL |
| 11. Dev deps in prod | `fakerphp/faker` etc. in `require` (not `require-dev`) | FAIL |
| 12. PHPStan | Static analysis errors | FAIL |
| 13. strict_types | Missing `declare(strict_types=1)` in PHP files | FAIL |
| 14. Secret patterns | `github_pat_`, `ctx7sk-`, `gsk_`, `sk-or-v1-` in tracked files | FAIL |
| 15. Hardcoded paths | `/Users/`, `/home/` in tracked source files | WARN |
| 16. Degradation observability | Catch blocks without logging/fallback signal | WARN |
| 17. Version consistency | Root vs core `composer.json` version mismatch | FAIL |
| 18. MCP schema bypass | Raw `::call()` on schema-enabled MCP without `@mcp-schema-bypass` | FAIL |
| 19. Compile clean-worktree | `brain compile` produces new uncommitted changes (source ↔ artifact drift) | FAIL |

### CLI Sub-Checks (Cross-Repo Boundary)

Checks 2 (PHPUnit) and 12 (PHPStan) include CLI sub-checks that respect the three-repo topology:

- **Clean cli/ worktree:** sub-checks execute normally (tests + phpstan).
- **Dirty cli/ worktree:** sub-checks degrade to `WARN` + skip (parallel WIP detected). This is dev-safe — dirty CLI does not fail the audit.
- **Release stabilization:** CLI worktree MUST be clean so sub-checks actually run. `WARN` from CLI skip is not acceptable for release.

Worktree guard ignores `.phpunit.cache` and `.phpunit.result.cache` (PHPUnit artifacts, not real drift).

### PHPStan Level Policy (Cross-Repo)

- **Core baseline:** PHPStan level 2 — required for all Enterprise gates. Regression = merge blocked.
- **CLI baseline:** PHPStan level 0 — separate repo, may lag. Release requires explicit alignment plan (see `10-pre-publication.md` § "Version Alignment").
- **Downgrade prohibition:** Never lower core PHPStan level without evidence pack + Doc approval.
- **Source of truth:** `core/phpstan.neon` → `composer analyse` output. CLI: `cli/phpstan.neon`.
- **Level progression:** 0 → 1 → 2 (2026-02-22). Each lift produced evidence pack + test proof.

## CI Supply Chain

- [x] All GitHub Actions pinned by SHA (not tag) — see `.github/workflows/*.yml`
- [x] All workflows have `concurrency:` guards to prevent parallel waste
- [x] No secrets in workflow files (only `${{ secrets.* }}` references)

## Release Discipline

- [ ] Version in `composer.json` matches tag
- [ ] `pins.json` up to date (no unpinned deps)
- [ ] `CHANGELOG.md` entry for version
- [ ] Release bundle builds without error (`build-release-bundle.sh`)
- [ ] No `FAIL` category in audit report
- [ ] Pre-publication checklist completed (see `.docs/product/10-pre-publication.md`)
- [ ] History secret scan recorded: `bash scripts/scan-secrets-history.sh` — **Manual Gate (not CI)**. Must be run and exit 0 for any release/publication. Exit 2 = history contains leaked patterns, requires mitigation per Security 3.0 Playbook.

## Code Quality

- [ ] All new PHP files have `declare(strict_types=1)`
- [ ] No `dd()`, `dump()`, `var_dump()` in committed code
- [ ] Protected/private visibility by default (public only when API)
- [ ] `static::` in traits (not `self::`) for overridable methods
- [ ] No hardcoded absolute paths — use `Runtime::` constants

## Test Coverage

- [ ] New code has corresponding test (or explicit skip justification)
- [ ] `composer test` = 0 failures, 0 errors
- [ ] Critical path changes (Merger, Builders, Operator) require test proof

## Documentation

- [ ] `.docs/` files have YAML front matter
- [ ] `brain docs --validate` = 0 errors, 0 warnings

**Docs Validation Invariant (Tracked-First):**

- **Gate (HARD):** `invalid=0` and `warnings=0` — these are the release gate. Any invalid doc = merge blocked.
- **Valid count (INFORMATIONAL):** varies with worktree state (branch, untracked files, WIP quarantine branches). Not a regression signal if `invalid=0, warnings=0` and `git status` is clean for tracked files.
- **Operator triage when counts change:** (1) `git status --porcelain` — check for untracked `.docs/` files; (2) `git branch --list 'wip/*'` — quarantined WIP branches remove docs from master's worktree; (3) if master is clean and `invalid=0` — no action needed.

- [ ] SCORECARD.md and FIX-QUEUE.md updated if audit items change

## Operator Readiness

- [ ] Failure runbooks cover new failure modes (if applicable)
- [ ] Benchmark scenarios cover new features (if applicable)
- [ ] Demo script updated if public API changed
- [ ] **Worktree isolation (when quad-mode active):** agents run in dedicated worktrees, not root repo; no cross-agent writes; artifacts local to worktree; no force push. See `.docs/product/17-worktree-isolation-contract.md`. Evidence: `git worktree list` + clean root `git status`.
- [ ] **Root CI protection (quad-mode):** `.github/workflows/*.yml` read-only on root master during quad-mode; CI edits in isolated `agent/<name>/ci-*` branch only. See `17-worktree-isolation-contract.md` § Hard Rule 4.6.
- [ ] **Repo boundary preflight (manual):** before editing, confirm correct repo root. Three independent repos share the disk — edits must be committed in the owning repo. Commands: `git rev-parse --show-toplevel` (from file's directory); for sub-repos: `cd core && git rev-parse --show-toplevel` / `cd cli && git rev-parse --show-toplevel`. See `.docs/architecture/repo-topology.md`.
- [ ] **Touch Whitelist Preflight (mandatory in quad-mode):** before editing, declare intended file list in prompt or evidence pack. After work: `git diff --name-only` must match whitelist exactly. Steps: (A) run `git diff --name-only` to record baseline, (B) declare whitelist of files to touch, (C) after work assert `git diff --name-only` matches whitelist. Violation: STOP, revert unexpected files (`git checkout -- <file>`), quarantine to `wip/` branch if changes are legitimate but out-of-scope. See `10-pre-publication.md` § Touch Whitelist Preflight.
- [ ] **Parallel hygiene sweep (end-of-batch):** run 3-agent sweep (docs, workspace, vector memory) to maintain invariants between batches. See `.docs/product/19-parallel-hygiene-sweep.md`.

## Quad-Mode Drift Policy

When multiple agents/terminals work in parallel ("quad-mode"):

- If all gates are GREEN but test counts (tests/assertions) changed between runs: classify as **External Drift** when Doc confirms parallel work is active.
- Evidence Pack must record: `Drift observed: tests X→Y, assertions A→B, reason: parallel work (Doc confirmed)`.
- **STOP** only if drift is accompanied by a RED gate or test failure/flake.
- Do NOT escalate count changes as incidents during active parallel work.
- Final test count validation happens in **stabilization phase** (endgame batch) after all parallel work converges.
