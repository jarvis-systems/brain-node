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
| 2 | Unit Tests | `composer test` (48+ tests, 0 failures) | YES | `brain-lint.yml` → audit-enterprise.sh Check 2 |
| 3 | Static Analysis (Core) | `composer analyse` in core/ (phpstan level 0) | YES | `brain-lint.yml` → `core/phpstan.neon` |
| 4 | Static Analysis (CLI) | `composer analyse` in cli/ (phpstan level 0) | YES | `brain-lint.yml` → `cli/phpstan.neon` |
| 5 | Secret Scanning | `bash scripts/scan-secrets.sh` (exit 0) | YES | `brain-lint.yml` → `scripts/scan-secrets.sh` |
| 6 | Enterprise Audit | `bash scripts/audit-enterprise.sh` (exit 0) | YES | `brain-lint.yml` → `scripts/audit-enterprise.sh` |
| 7 | Compile Discipline | Node source ↔ compiled artifact drift check | YES | `brain-lint.yml` inline step |
| 8 | Benchmark Dry-Run | `composer benchmark:dry` (0 errors) | YES | `brain-benchmark.yml` → `scripts/benchmark-llm-suite.sh` |
| 9 | Release Gate | Version/pin/manifest/bundle validation | YES | `brain-release.yml` → `scripts/build-release-bundle.sh` |

## Enterprise Audit Sub-Gates (14 Checks)

All 14 checks in `audit-enterprise.sh` must PASS or WARN (no FAIL):

| Check | What it catches | Severity |
|-------|----------------|----------|
| 1. PHP syntax | Parse errors in all PHP files | FAIL |
| 2. PHPUnit | Test failures or errors | FAIL |
| 3. Silent catch blocks | `catch (\Throwable) {}` with empty body | WARN |
| 4. Debug artifacts | `dd()`, `dump()`, `var_dump()`, `print_r()` | WARN |
| 5. TODO/FIXME | Unresolved items | INFO |
| 6. Unsafe exec | `shell_exec()`, `eval()` | WARN |
| 7. Shell safety | Missing `set -euo pipefail` in scripts | WARN |
| 8. Hardcoded paths | `/Users/xsaven` in tracked files | WARN |
| 9. Trait LSB | `self::` in traits where `static::` required | WARN |
| 10. Known typos | "Standarts", "Compliation", etc. | FAIL |
| 11. Dev deps in prod | `fakerphp/faker` etc. in `require` (not `require-dev`) | FAIL |
| 12. PHPStan | Static analysis errors | FAIL |
| 13. strict_types | Missing `declare(strict_types=1)` in PHP files | FAIL |
| 14. Secret patterns | `github_pat_`, `ctx7sk-`, `gsk_`, `sk-or-v1-` in tracked files | FAIL |

## CI Supply Chain

- [ ] All GitHub Actions pinned by SHA (not tag) — see `.github/workflows/*.yml`
- [ ] All workflows have `concurrency:` guards to prevent parallel waste
- [ ] No secrets in workflow files (only `${{ secrets.* }}` references)

## Release Discipline

- [ ] Version in `composer.json` matches tag
- [ ] `pins.json` up to date (no unpinned deps)
- [ ] `CHANGELOG.md` entry for version
- [ ] Release bundle builds without error (`build-release-bundle.sh`)
- [ ] No `FAIL` category in audit report
- [ ] Pre-publication checklist completed (see `.docs/product/10-pre-publication.md`)

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
- [ ] SCORECARD.md and FIX-QUEUE.md updated if audit items change

## Operator Readiness

- [ ] Failure runbooks cover new failure modes (if applicable)
- [ ] Benchmark scenarios cover new features (if applicable)
- [ ] Demo script updated if public API changed
