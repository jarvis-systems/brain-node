---
name: "Enterprise Codebase Scorecard"
description: "10-category enterprise audit scorecard for Brain v0.2.0 codebase (Core, Node, CLI)"
type: audit
date: 2026-02-21
version: "1.0.0"
status: active
---

# Enterprise Codebase Scorecard

## Rating Scale

| Score | Level | Meaning |
|-------|-------|---------|
| 0 | Critical | Systemic risk, immediate action required |
| 1 | Poor | Significant gaps, high priority remediation |
| 2 | Adequate | Functional but has known weaknesses |
| 3 | Good | Enterprise-ready, minor improvements only |

## Scorecard

| # | Category | Core | Node | CLI | Weighted | Key Finding |
|---|----------|------|------|-----|----------|-------------|
| 1 | Determinism | 3 | 3 | -- | 3.0 | No rand/shuffle; compile is idempotent (verified S12) |
| 2 | Error Handling | 2 | 2 | -- | 2.0 | Catch blocks have fallback code (not silent); minor observability gap |
| 3 | Input Validation | 2 | 2 | -- | 2.0 | MCP schema validator exists (3 modes) but not all methods use it |
| 4 | Security | 1 | 1 | 1 | 1.0 | No static analysis, API keys in MCP files, no secret management |
| 5 | Docs Parity | 2 | 2 | -- | 2.0 | CLAUDE.md references `composer test`/`analyse` that do not exist at root |
| 6 | Testability | 1 | 0 | 1 | 0.7 | Core: 4 tests/167 files; Node: 0 tests; CLI: 7 test files |
| 7 | Release Discipline | 3 | 3 | -- | 3.0 | Pinning, manifest, bundle, release CI -- all good |
| 8 | Operability | 3 | 3 | -- | 3.0 | Benchmarks, runbooks, ops-evidence, demo -- comprehensive |
| 9 | Footguns | 1 | 2 | -- | 1.3 | Debug artifacts (dd/dump), silent catches, typo in class name |
| 10 | Maintainability | 2 | 2 | -- | 2.0 | strict_types missing in 1 file; CompileStandartsTrait typo |

**Overall Score: 20.0 / 30 (67%)**

## Category Details

### 1. Determinism (3/3)

No sources of non-determinism found. No `rand()`, `shuffle()`, `mt_rand()`, `array_rand()`, `uniqid()`. Compile output is stable across runs. Build cache uses `md5(serialize())` which is deterministic for same input.

### 2. Error Handling (2/3)

**Core (2/3)**: 5 catch blocks in `CompileStandartsTrait.php` and 1 in `TaskTool.php:22` — initially classified as silent, but verified: all have graceful degradation fallback (`[unserializable]`) for `VarExporter::export()` failures. Correct pattern for non-exportable values. Minor gap: no logging for observability. Additional catch blocks in `CommandArchetype.php:75`, `McpArchitecture.php:44,87` need review.

**Node (2/3)**: Zero try/catch blocks. Correct for declarative configuration -- errors bubble to compiler.

### 3. Input Validation (2/3)

`McpSchemaTrait` provides 3 validation modes (`callJson`, `callValidatedJson`, schema generation). However, `self::callJson()` at line 28 uses early static binding instead of `static::callJson()`, breaking LSB in subclasses. Not all MCP call sites use validated variants.

### 4. Security (1/3)

- No static analysis tool (phpstan/psalm) installed anywhere
- API keys hardcoded in `GithubMcp.php:21` and `Context7Mcp.php:24` (mitigated: excluded from git)
- No `.env`-based secret management for MCP credentials
- CI actions pinned by tag (`@v4`) not SHA -- supply chain risk
- `fakerphp/faker` in CLI production `require` instead of `require-dev`

### 5. Docs Parity (2/3)

Compiled CLAUDE.md declares iron rules:
- `QUALITY GATE [TEST]: composer test` -- no `test` script in root `composer.json`
- `QUALITY GATE [PHPSTAN]: composer analyse` -- no `analyse` script, no phpstan installed

These quality gates are unenforceable. Documentation promises what code cannot deliver.

### 6. Testability (0.7/3)

| Package | Test Files | Source Files | Coverage |
|---------|-----------|--------------|----------|
| Core | 4 | 167+ | ~2.4% |
| Node | 0 | 44 | 0% |
| CLI | 7 | ~30+ | ~23% |

Major gaps: JsonBuilder, YamlBuilder, Runtime, Operator, Store, BrainCLI, all Tool classes, all Archetypes, Variable system, Include resolution (max depth 255).

### 7. Release Discipline (3/3)

Strong: dependency pinning (`pins.json`), release manifest, build bundle script (`build-release-bundle.sh`), release CI gate, semantic versioning, CHANGELOG conventions.

### 8. Operability (3/3)

Comprehensive: benchmark suite (standard + LLM), ops evidence collection, failure runbooks, demo/pilot pack, observability documentation, ADR/ADV decision records.

### 9. Footguns (1.3/3)

**Core (1/3)**:
- ~~2 commented-out `dd()` blocks in `XmlBuilder.php`~~ **FIXED**
- `dump()` in production fallback in `ConvertCommand.php:173`
- `CompileStandartsTrait.php` -- typo propagates to 3 files
- `HelloScript.php` -- scaffold with unused `Http` import

**Node (2/3)**:
- Placeholder Purpose in `Brain.php:14`
- Hardcoded paths in `VectorMemoryMcp.php`, `VectorTaskMcp.php`, `LaravelBoostMcp.php`

### 10. Maintainability (2/3)

- 166/167 PHP files in core have `declare(strict_types=1)` -- only `Brain.php` missing
- `CompileStandartsTrait.php` typo ("Standarts" vs "Standards") propagates through `use` statements
- Hardcoded paths (`/Users/xsaven/...`) in MCP configs and 1 test file
- `error_log()` in `ConvertCommand.php:193` (gated by env var -- acceptable)

## Risk Matrix

| Risk Level | Count | Action |
|------------|-------|--------|
| P0 (Critical) | 12 | Fix immediately, see FIX-QUEUE.md |
| P1 (Important) | 5 | Plan for next sprint |
| P2 (Nice to have) | 3 | Backlog |

## Audit Methodology

- Full file reads of all PHP source files in `core/src/`, `node/`, `cli/src/`, `scripts/`
- Automated grep scans for debug artifacts, silent catches, hardcoded paths
- CI workflow analysis for timeout, concurrency, action pinning
- Composer dependency review across all 3 packages
- Cross-reference between compiled CLAUDE.md claims and actual tooling
