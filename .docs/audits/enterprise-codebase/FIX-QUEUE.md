---
name: "Enterprise Fix Queue"
description: "Prioritized fix queue from enterprise codebase audit — P0/P1/P2 items with exact locations and validation"
type: audit
date: 2026-02-21
version: "1.0.0"
status: active
---

# Enterprise Fix Queue

## P0 — Critical (Immediate Fix Required)

### P0-001: Missing strict_types in Brain.php

| Field | Value |
|-------|-------|
| File | `core/src/Support/Brain.php:1` |
| Risk | Type coercion bugs in facade; only PHP file in core without strict_types |
| Fix | Add `declare(strict_types=1);` after `<?php` |
| Size | 1 line |
| Status | **FIXED** |
| Validate | `php -l core/src/Support/Brain.php` |

### P0-002: Commented-out dd() in XmlBuilder.php

| Field | Value |
|-------|-------|
| File | `core/src/XmlBuilder.php:70-72, 209-211` |
| Risk | Debug artifacts — hard crash if uncommented; empty if-block is dead code |
| Fix | Remove lines 70-72 (commented dd block) and lines 209-211 (empty if with commented dd) |
| Size | -6 lines |
| Status | **FIXED** |
| Validate | `php -l core/src/XmlBuilder.php` + `cd core && ./vendor/bin/phpunit tests/XmlBuilderTest.php` |

### P0-003: dump() in ConvertCommand.php

| Field | Value |
|-------|-------|
| File | `core/src/Console/Commands/ConvertCommand.php:173` |
| Risk | Debug output leak in production fallback path |
| Fix | Replaced `dump()` with `fwrite(STDERR, json_encode(...))` — preserves debug utility, redirects to stderr |
| Size | 1 line |
| Status | **FIXED** |
| Validate | `php -l core/src/Console/Commands/ConvertCommand.php` + `audit-enterprise.sh` Check 4 (debug artifacts) = PASS |

### P0-004: CompileStandartsTrait typo

| Field | Value |
|-------|-------|
| File | `core/src/Compilation/Traits/CompileStandartsTrait.php` |
| Risk | Typo "Standarts" propagates to 3+ files via `use` statements; maintenance confusion |
| Fix | Rename to `CompileStandardsTrait.php`, update all `use` references |
| Size | 4+ files |
| Status | Open (coordinated rename needed) |
| Validate | `php -l` on all affected files + full test suite |

### ~~P0-005~~: Catch blocks in CompileStandartsTrait (RECLASSIFIED to P2)

| Field | Value |
|-------|-------|
| File | `core/src/Compilation/Traits/CompileStandartsTrait.php:44,92,111,125,157` |
| Original risk | Classified as "silent catches" — but verified: all 5 catches have fallback code returning `[unserializable]` |
| Actual risk | Graceful degradation for `VarExporter::export()` — correct pattern for serialization of non-exportable values |
| Status | **Reclassified** — not silent, not a P0. Consider adding `error_log()` for observability (P2). |

### ~~P0-006~~: Catch block in TaskTool.php (RECLASSIFIED to P2)

| Field | Value |
|-------|-------|
| File | `core/src/Compilation/Tools/TaskTool.php:22` |
| Original risk | Classified as "silent catch" — but verified: catch returns `'[unserializable]'` fallback |
| Actual risk | Same VarExporter graceful degradation pattern as CompileStandartsTrait |
| Status | **Reclassified** — not silent, not a P0. |

### P0-007: Missing CI timeout

| Field | Value |
|-------|-------|
| File | `.github/workflows/brain-lint.yml:28` |
| Risk | CI job hang = unlimited billable minutes; only job in all workflows without timeout |
| Fix | Add `timeout-minutes: 15` to `lint-and-test` job |
| Size | 1 line |
| Status | **FIXED** |
| Validate | YAML syntax validation |

### P0-008: Shell scripts missing pipefail

| Field | Value |
|-------|-------|
| Files | `scripts/verify-compile-metrics.sh:12`, `scripts/lint-mcp-syntax.sh:12`, `scripts/benchmark-suite.sh:14` |
| Risk | `set -e` only — unset vars expand to empty string, pipe errors swallowed |
| Fix | Changed `set -e` to `set -euo pipefail` + fixed `$1` → `${1:-}` for `-u` compatibility |
| Size | 3 lines + 2 `$1` fixes across 3 files |
| Status | **FIXED** |
| Validate | `bash -n` on each file + `audit-enterprise.sh` Check 7 (shell safety) = PASS |

### P0-009: HelloScript.php dead code

| Field | Value |
|-------|-------|
| File | `scripts/HelloScript.php` |
| Risk | Scaffold file with unused `Http` import and default description — dead code in tree |
| Fix | Remove file or complete implementation |
| Size | 1 file |
| Status | Open |
| Validate | N/A |

### P0-010: No static analysis

| Field | Value |
|-------|-------|
| Files | No `phpstan.neon`/`psalm.xml` anywhere |
| Risk | Zero static analysis across all 3 packages — type bugs and dead code undetectable |
| Fix | Install phpstan, create baseline, add to CI |
| Size | New tooling |
| Status | Open (out of scope: "no new features" constraint) |
| Validate | `composer analyse` passes |

### P0-011: faker in production require

| Field | Value |
|-------|-------|
| File | `cli/composer.json` |
| Risk | `fakerphp/faker` in `require` instead of `require-dev` — dev dependency in production |
| Fix | Move to `require-dev` |
| Size | 1 line |
| Status | Open (CLI package, separate concern) |
| Validate | `composer install --no-dev` still works |

### P0-012: self instead of static in McpSchemaTrait

| Field | Value |
|-------|-------|
| File | `core/src/Mcp/Traits/McpSchemaTrait.php:27-28` |
| Risk | `self::callJson()` and `self::schema()` break late static binding if methods overridden in subclass |
| Fix | Changed both `self::` to `static::` on lines 27-28 |
| Size | 2 lines |
| Status | **FIXED** |
| Validate | `php -l` + `audit-enterprise.sh` Check 9 (trait LSB) — McpSchemaTrait clean |

## P1 — Important (Next Sprint)

### P1-001: Placeholder Purpose in Brain.php

| Field | Value |
|-------|-------|
| File | `node/Brain.php:14` |
| Issue | `#[Purpose('<!-- Specify the primary project purpose -->')]` — HTML comment as Purpose |
| Fix | Define actual project purpose |

### P1-002: Hardcoded API keys in MCP files

| Field | Value |
|-------|-------|
| Files | `node/Mcp/GithubMcp.php:21`, `node/Mcp/Context7Mcp.php:24` |
| Issue | API keys in source code (mitigated: files excluded from git) |
| Fix | Extract to environment variables |

### P1-003: Low test coverage

| Field | Value |
|-------|-------|
| Scope | Core: 4 tests/167 files (2.4%), Node: 0 tests, CLI: 7 test files |
| Issue | Critical paths untested: JsonBuilder, YamlBuilder, Runtime, Operator, Tool classes |
| Fix | Incremental test coverage plan |

### P1-004: Swallowing catch blocks in archetypes

| Field | Value |
|-------|-------|
| Files | `CommandArchetype.php:75`, `McpArchitecture.php:44,87` |
| Issue | Catch blocks that may swallow significant errors |
| Fix | Analyze and add appropriate error handling |

### P1-005: Missing root composer scripts

| Field | Value |
|-------|-------|
| File | `composer.json` (root) |
| Issue | No `test` or `analyse` scripts — CLAUDE.md iron rules reference them as CRITICAL |
| Fix | Add scripts that proxy to core/cli test commands |

## P2 — Nice to Have (Backlog)

### P2-001: Unpinned CI actions

| Field | Value |
|-------|-------|
| Files | All `.github/workflows/*.yml` |
| Issue | `@v4` tags instead of SHA-pinned actions — supply chain risk |
| Fix | Pin to full SHA hashes |

### P2-002: Missing CI concurrency guards

| Field | Value |
|-------|-------|
| Files | `brain-lint.yml`, `brain-benchmark.yml` |
| Issue | No `concurrency:` blocks — parallel runs waste resources |
| Fix | Add concurrency groups |

### P2-003: error_log in ConvertCommand

| Field | Value |
|-------|-------|
| File | `core/src/Console/Commands/ConvertCommand.php:193` |
| Issue | `error_log()` for profiling (gated by `BRAIN_PROFILE` env var) |
| Fix | Acceptable for now, consider structured logging later |

## Summary

| Priority | Total | Fixed | Reclassified | Open |
|----------|-------|-------|--------------|------|
| P0 | 12 | 6 | 2 (to P2) | 4 |
| P1 | 5 | 0 | 0 | 5 |
| P2 | 3+2 | 0 | 0 | 5 |
| **Total** | **20** | **6** | **2** | **14** |

### Audit Check Coverage

| Fix | Regression Prevention |
|-----|----------------------|
| P0-001 (strict_types) | `audit-enterprise.sh` Check 1 (PHP syntax) |
| P0-002 (dd artifacts) | `audit-enterprise.sh` Check 4 (debug artifacts) |
| P0-003 (dump→stderr) | `audit-enterprise.sh` Check 4 (debug artifacts) |
| P0-007 (CI timeout) | YAML syntax validation |
| P0-008 (pipefail) | `audit-enterprise.sh` Check 7 (shell safety) |
| P0-012 (self→static) | `audit-enterprise.sh` Check 9 (trait LSB) |
