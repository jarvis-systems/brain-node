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
| 2 | Error Handling | 2 | 2 | -- | 2.0 | Catch blocks have fallback code (not silent); P1-004 reclassified to P2 (same VarExporter pattern) |
| 3 | Input Validation | 2 | 2 | -- | 2.0 | MCP schema validator exists (3 modes) but not all methods use it |
| 4 | Security | 2 | 1 | 1 | 1.3 | ~~No static analysis~~ **FIXED** (phpstan level 0); API keys in MCP files remain |
| 5 | Docs Parity | 3 | 2 | -- | 2.5 | ~~`composer test`/`analyse` missing at root~~ **FIXED** — scripts added, both pass |
| 6 | Testability | 2 | 0 | 1 | 1.0 | ~~MergerTest/TomlBuilderTest broken~~ **FIXED** — 19/19 pass; ~~Merger stale-index bug~~ **FIXED**; strict_types CI gate added |
| 7 | Release Discipline | 3 | 3 | -- | 3.0 | Pinning, manifest, bundle, release CI -- all good |
| 8 | Operability | 3 | 3 | -- | 3.0 | Benchmarks, runbooks, ops-evidence, demo -- comprehensive |
| 9 | Footguns | 3 | 2 | -- | 2.5 | ~~Debug artifacts~~ **FIXED**; ~~typo in class name~~ **FIXED**; ~~dead scaffold~~ **FIXED** |
| 10 | Maintainability | 3 | 2 | -- | 2.5 | ~~strict_types~~ **FIXED**; ~~CompileStandartsTrait typo~~ **FIXED**; ~~faker in prod~~ **FIXED** |

**Overall Score: 22.8 / 30 (76%)**

## Category Details

### 1. Determinism (3/3)

No sources of non-determinism found. No `rand()`, `shuffle()`, `mt_rand()`, `array_rand()`, `uniqid()`. Compile output is stable across runs. Build cache uses `md5(serialize())` which is deterministic for same input.

### 2. Error Handling (2/3)

**Core (2/3)**: 5 catch blocks in `CompileStandardsTrait.php` and 1 in `TaskTool.php:22` — verified: all have graceful degradation fallback (`[unserializable]`) for `VarExporter::export()` failures. Correct pattern for non-exportable values. Minor gap: no logging for observability. `CommandArchetype.php:75` and `McpArchitecture.php:44,87` — same VarExporter pattern, reclassified P1-004→P2.

**Node (2/3)**: Zero try/catch blocks. Correct for declarative configuration -- errors bubble to compiler.

### 3. Input Validation (2/3)

`McpSchemaTrait` provides 3 validation modes (`callJson`, `callValidatedJson`, schema generation). ~~`self::callJson()` at line 28 uses early static binding~~ **FIXED** — now uses `static::` for proper LSB. Not all MCP call sites use validated variants.

### 4. Security (1.3/3)

- ~~No static analysis tool~~ **FIXED** — phpstan 2.x installed in core (level 0, 4 documented suppressions), `composer analyse` in CI
- API keys hardcoded in `GithubMcp.php:21` and `Context7Mcp.php:24` (mitigated: excluded from git)
- No `.env`-based secret management for MCP credentials
- CI actions pinned by tag (`@v4`) not SHA -- supply chain risk
- ~~`fakerphp/faker` in CLI production `require`~~ **FIXED** — moved to `require-dev`, dead `fake()` function removed

### 5. Docs Parity (2.5/3)

Compiled CLAUDE.md declares iron rules:
- `QUALITY GATE [TEST]: composer test` — ~~no `test` script in root~~ **FIXED** — added, proxies to `core/phpunit`
- `QUALITY GATE [PHPSTAN]: composer analyse` — ~~no `analyse` script~~ **FIXED** — added, proxies to `core/phpstan`

Both quality gates now enforceable from root. Remaining gap: no root-level test aggregation across CLI/Node.

### 6. Testability (1.0/3)

| Package | Test Files | Source Files | Coverage | Status |
|---------|-----------|--------------|----------|--------|
| Core | 4 | 167+ | ~2.4% | ~~5 errors~~ **FIXED** — 19/19 PASS |
| Node | 0 | 44 | 0% | No tests |
| CLI | 7 | ~30+ | ~23% | Separate repo |

**Fixes applied:**
- ~~MergerTest: protected `handle()` call from test~~ **FIXED** — Reflection-based invocation
- ~~TomlBuilderTest: `from()` returns string, tests chain `->build()`~~ **FIXED** — removed stale chain
- ~~Merger stale-index bug: `array_splice` shifts positions but hash index not rebuilt~~ **FIXED** — index rebuilt after splice
- ~~LegacyParityTest referenced in docs but never existed~~ Confirmed: file does not exist (P2 backlog)
- strict_types enforcement gate added to audit (Check 13)

Major gaps remain: JsonBuilder, YamlBuilder, Runtime, Operator, Store, BrainCLI, Tool classes, Archetypes, Variable system.

### 7. Release Discipline (3/3)

Strong: dependency pinning (`pins.json`), release manifest, build bundle script (`build-release-bundle.sh`), release CI gate, semantic versioning, CHANGELOG conventions.

### 8. Operability (3/3)

Comprehensive: benchmark suite (standard + LLM), ops evidence collection, failure runbooks, demo/pilot pack, observability documentation, ADR/ADV decision records.

### 9. Footguns (2.5/3)

**Core (3/3)**:
- ~~2 commented-out `dd()` blocks in `XmlBuilder.php`~~ **FIXED**
- ~~`dump()` in production fallback in `ConvertCommand.php:173`~~ **FIXED** (→ fwrite STDERR)
- ~~`CompileStandartsTrait.php` typo~~ **FIXED** (renamed to `CompileStandardsTrait.php`)
- ~~`HelloScript.php` dead scaffold~~ **FIXED** (removed)

**Node (2/3)**:
- Placeholder Purpose in `Brain.php:14`
- Hardcoded paths in `VectorMemoryMcp.php`, `VectorTaskMcp.php`, `LaravelBoostMcp.php`

### 10. Maintainability (2.5/3)

- ~~166/167 PHP files with strict_types~~ **FIXED** — now 167/167 (Brain.php added in batch 1)
- ~~`CompileStandartsTrait.php` typo~~ **FIXED** — renamed to `CompileStandardsTrait.php`, 4 files updated
- ~~`fakerphp/faker` in CLI production require~~ **FIXED** — moved to `require-dev`, dead `fake()` removed
- Hardcoded paths (`/Users/xsaven/...`) in MCP configs and 1 test file
- `error_log()` in `ConvertCommand.php:193` (gated by env var -- acceptable)

## Risk Matrix

| Risk Level | Total | Fixed | Reclassified | Open | Action |
|------------|-------|-------|--------------|------|--------|
| P0 (Critical) | 12 | 10 | 2 (→P2) | 0 | **ALL CLOSED** — audit gate is blocking |
| P1 (Important) | 8 | 4 | 1 (→P2) | 3 | P1-003 partial, P1-005 done, P1-004 reclassified |
| P2 (Nice to have) | 6+1 | 0 | 0 | 7 | Backlog (includes P1-004 reclassified) |

## Audit Methodology

- Full file reads of all PHP source files in `core/src/`, `node/`, `cli/src/`, `scripts/`
- Automated grep scans for debug artifacts, silent catches, hardcoded paths
- CI workflow analysis for timeout, concurrency, action pinning
- Composer dependency review across all 3 packages
- Cross-reference between compiled CLAUDE.md claims and actual tooling
