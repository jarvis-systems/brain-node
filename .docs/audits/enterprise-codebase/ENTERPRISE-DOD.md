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

| # | Gate | Command | Blocking | Where |
|---|------|---------|----------|-------|
| 1 | PHP Syntax | `php -l` on all `.php` files | YES | `brain-lint.yml` step 4 |
| 2 | Unit Tests | `composer test` (19+ tests, 0 failures) | YES | `brain-lint.yml` step 5 |
| 3 | Static Analysis | `composer analyse` (phpstan level 0, 0 errors) | YES | `brain-lint.yml` step 6 |
| 4 | Enterprise Audit | `bash scripts/audit-enterprise.sh` (exit 0) | YES | `brain-lint.yml` step 7 |
| 5 | Compile Discipline | `brain compile` + diff check (no drift) | YES | `brain-lint.yml` step 8 |
| 6 | Benchmark Dry-Run | `composer benchmark:dry` (0 errors) | YES | `brain-benchmark.yml` smoke-test |
| 7 | Release Gate | Version/pin/manifest/bundle validation | YES | `brain-release.yml` |

## Enterprise Audit Sub-Gates (13 Checks)

All 13 checks in `audit-enterprise.sh` must PASS or WARN (no FAIL):

| Check | What it catches |
|-------|----------------|
| 1. PHP syntax | Parse errors in all PHP files |
| 2. PHPUnit | Test failures or errors |
| 3. Silent catch blocks | `catch (\Throwable) {}` with empty body |
| 4. Debug artifacts | `dd()`, `dump()`, `var_dump()`, `print_r()` |
| 5. TODO/FIXME | Unresolved items (WARN only) |
| 6. Unsafe exec | `shell_exec()`, `eval()` |
| 7. Shell safety | Missing `set -euo pipefail` in scripts |
| 8. Hardcoded paths | `/Users/xsaven` in tracked files (WARN only) |
| 9. Trait LSB | `self::` in traits where `static::` required |
| 10. Known typos | "Standarts", "Compliation", etc. |
| 11. Dev deps in prod | `fakerphp/faker` etc. in `require` (not `require-dev`) |
| 12. PHPStan | Static analysis errors |
| 13. strict_types | Missing `declare(strict_types=1)` in PHP files |

## Release Discipline

- [ ] Version in `composer.json` matches tag
- [ ] `pins.json` up to date (no unpinned deps)
- [ ] `CHANGELOG.md` entry for version
- [ ] Release bundle builds without error (`build-release-bundle.sh`)
- [ ] No `FAIL` category in audit report

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
