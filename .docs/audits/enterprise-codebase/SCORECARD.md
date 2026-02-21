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
| 2 | Error Handling | 3 | 3 | -- | 3.0 | All catches: graceful degradation + `logDegradation()` observability (env-gated); Node: zero catches = correct for declarative config; **NEW**: VarExporterDegradationTest (8 tests), audit Check 16 |
| 3 | Input Validation | 2 | 2 | -- | 2.0 | MCP schema validator exists (3 modes) but not all methods use it |
| 4 | Security | 2 | 3 | 2 | 2.3 | ~~No static analysis~~ **FIXED** (phpstan level 0); ~~API keys in MCP files~~ **FIXED** (getenv()); ~~CI actions tag-pinned~~ **FIXED** (SHA-pinned); **NEW**: Secret scanning CI gate, release bundle .mcp.json exclusion, upload.sh/settings.json untracked, threat model doc, CI concurrency guards, pre-publication kill-switch |
| 5 | Docs Parity | 3 | 3 | -- | 3.0 | ~~`composer test`/`analyse` missing at root~~ **FIXED**; ~~LegacyParityTest referenced but never existed~~ **FIXED** (removed from CLAUDE.md, actual test list updated); ~~docs validation 1 invalid~~ **FIXED** (YAML front matter added); `brain docs --validate` = 0 invalid |
| 6 | Testability | 3 | 2 | 1 | 2.0 | 197/197 tests, 446 assertions; **Refactor Batch 4**: BlueprintTest (44 tests, 56 assertions — IronRule severity chain, builder fluency, mutateToString contract, defaultElement, Guideline/Style/Response builder APIs, id via set(), child accumulation, determinism); **Refactor Batch 3**: MDTest (30), CoreTest (28), VarChainTest (20); Node: 8 tests via NodeIntegrityTest; CLI: phpstan level 0 |
| 7 | Release Discipline | 3 | 3 | -- | 3.0 | Pinning, manifest, bundle, release CI -- all good |
| 8 | Operability | 3 | 3 | -- | 3.0 | Benchmarks, runbooks, ops-evidence, demo -- comprehensive |
| 9 | Footguns | 3 | 3 | -- | 3.0 | ~~Debug artifacts~~ **FIXED**; ~~typo in class name~~ **FIXED**; ~~dead scaffold~~ **FIXED**; ~~hardcoded MCP paths~~ **FIXED** (generator emits getcwd()); **Refactor Batch 2**: awesome-mcp.json `--save-as` → `--as` CLI bug fix; **Refactor Batch 4**: ~~Guideline::workflow() dead method~~ **REMOVED** |
| 10 | Maintainability | 3 | 3 | -- | 3.0 | ~~strict_types~~ **FIXED**; ~~CompileStandartsTrait typo~~ **FIXED**; ~~faker in prod~~ **FIXED**; ~~hardcoded paths~~ **FIXED** (generator + test); **Refactor Batch 1**: var-dumper→require-dev (17 prod deps); **Refactor Batch 2**: workspace.json portable paths, both Compilation traits 100% return-typed (verified); **Refactor Batch 4**: BlueprintArchitecture::mutateToString() `: mixed` return type added |

**Overall Score: 27.3 / 30 (91.0%)**

## Category Details

### 1. Determinism (3/3)

No sources of non-determinism found. No `rand()`, `shuffle()`, `mt_rand()`, `array_rand()`, `uniqid()`. Compile output is stable across runs. Build cache uses `md5(serialize())` which is deterministic for same input.

### 2. Error Handling (3/3)

**Core (3/3)**: All 9 VarExporter catch blocks across 4 files (CompileStandardsTrait, TaskTool, McpArchitecture, CommandArchetype) now have:
- Graceful degradation fallback (`[unserializable]` / `"unserializable_argument"`)
- Observable logging via `logDegradation()` helper (CompileStandardsTrait) or inline `error_log()` (McpArchitecture, CommandArchetype)
- Gated by `BRAIN_COMPILE_DEBUG` env — silent by default, observable on demand
- Proven by `VarExporterDegradationTest` (8 tests: closure handling, mixed args, determinism, logging emission, no-crash meta-test)
- Audit Check 16 verifies no catch blocks without observability signal

**Node (3/3)**: Zero try/catch blocks — correct for declarative configuration. All errors bubble to the compiler where they're properly handled. This is the enterprise-correct pattern for config-as-code.

### 3. Input Validation (2/3)

`McpSchemaTrait` provides 3 validation modes (`callJson`, `callValidatedJson`, schema generation). ~~`self::callJson()` at line 28 uses early static binding~~ **FIXED** — now uses `static::` for proper LSB. Not all MCP call sites use validated variants.

### 4. Security (2.3/3)

- ~~No static analysis tool~~ **FIXED** — phpstan 2.x installed in core (level 0, 4 documented suppressions), `composer analyse` in CI
- ~~API keys hardcoded in `GithubMcp.php:21` and `Context7Mcp.php:24`~~ **FIXED** — migrated to `getenv()`, credentials in `.brain/.env` (gitignored), `.brain/.env.example` documented
- ~~CI actions pinned by tag (`@v4`) not SHA~~ **FIXED** — all 4 actions SHA-pinned across 3 workflows (verified via GitHub API)
- ~~`fakerphp/faker` in CLI production `require`~~ **FIXED** — moved to `require-dev`, dead `fake()` function removed
- ADV-007 benchmark scenario added for MCP credential extraction attempts
- **NEW**: `scripts/scan-secrets.sh` — standalone secret scanner (CI gate, blocking)
- **NEW**: `audit-enterprise.sh` Check 14 — secret pattern scanning in tracked files
- **NEW**: `upload.sh` and `settings.json` untracked from git (contained live API keys)
- **NEW**: `build-release-bundle.sh` — `.mcp.json` excluded from release bundles (contained resolved secrets)
- **NEW**: `.docs/product/09-secrets.md` — threat model, do/don't, key rotation, roadmap
- **NEW**: CI concurrency guards — all 3 workflows have `concurrency:` blocks (cancel-in-progress for lint/benchmark, safe for release)
- **NEW**: `.docs/product/10-pre-publication.md` — pre-publication kill-switch checklist (credential rotation + history cleanup)

### 5. Docs Parity (3/3)

- `QUALITY GATE [TEST]: composer test` — ~~no `test` script in root~~ **FIXED** — added, proxies to `core/phpunit`
- `QUALITY GATE [PHPSTAN]: composer analyse` — ~~no `analyse` script~~ **FIXED** — added, proxies to `core/phpstan`
- ~~LegacyParityTest referenced in CLAUDE.md~~ **FIXED** — removed false reference, replaced with actual 9 test file names
- ~~`brain docs --validate` = 1 invalid~~ **FIXED** — YAML front matter added to `deep-research-report-system-prompting.md`
- Both quality gates enforceable from root. Documentation claims verified against reality.

### 6. Testability (2.0/3)

| Package | Test Files | Source Files | Tests | Assertions | Status |
|---------|-----------|--------------|-------|------------|--------|
| Core | 16 | 167+ | 197 | 446 | 197/197 PASS |
| Node | 0 (tested via Core) | 44 | 8 | 22 | via NodeIntegrityTest |
| CLI | 7 | ~30+ | ~20 | ~50 | Separate repo + PHPStan level 0 |

**Fixes applied:**
- ~~MergerTest: protected `handle()` call from test~~ **FIXED** — Reflection-based invocation
- ~~TomlBuilderTest: `from()` returns string, tests chain `->build()`~~ **FIXED** — removed stale chain
- ~~Merger stale-index bug: `array_splice` shifts positions but hash index not rebuilt~~ **FIXED** — index rebuilt after splice
- ~~LegacyParityTest referenced in docs but never existed~~ **FIXED** — false reference removed from CLAUDE.md
- strict_types enforcement gate added to audit (Check 13)

**Proof Pack (v1) — invariant proofs added:**
- `BuilderDeterminismTest` (5 tests): XmlBuilder/TomlBuilder idempotency, child ordering, key ordering, double-newline contract
- `MergerInvariantsTest` (4 tests): no child loss, empty includes, deep nesting (3-level), determinism
- `CompilationOutputTest` (13 tests): Store::as/get/var format, Operator::if/forEach/task/verify/validate, BrainCLI constants/methods, Operator::do chaining, determinism

**Phase 4 — Node integrity + CLI phpstan:**
- `NodeIntegrityTest` (8 tests): strict_types across all node/, agent attribute contracts, command attribute contracts, MCP Meta('id'), MCP defaultCommand/defaultArgs contracts, no secrets in source, pins.json structure
- CLI phpstan level 0 with documented suppressions (7 ignore rules, 2 excluded files)
- `composer analyse` now covers core + CLI

**Phase 5 — Include refinery + compile idempotency:**
- `CompileIdempotencyTest` (4 tests): full Merger→XmlBuilder pipeline determinism with realistic structures, MCP JSON payload preservation, 3-level nested include flattening, special character escaping consistency
- Include refinery: VectorTask dedup (-19 compiled lines), dead BrainScriptsInclude import removed
- TomlBuilderTest path portability fix (hardcoded user path → generic)

**Phase 7 — Enterprise closure:**
- `RuntimeTest` (9 tests): all 17 constants are `{{ NAME }}` template placeholders, path methods append/join correctly, `print()` generates templates, `__callStatic` resolves defined constants via `defined()/constant()`, fallthrough to `print()` for unknown, determinism proof
- `ToolFormatTest` (8 tests): all 9 tools have PascalCase names, unique names, `call()` produces `ToolName(args)` format, `describe()` produces block format, determinism proof
- `VarExporterDegradationTest` (8 tests): closure graceful handling, mixed valid+invalid args, determinism, `logDegradation()` callable, debug logging emission, multiple operator catch paths
- Suite: 52→75 tests, 125→218 assertions

**Refactor Batch 3 — Coverage expansion (MD, Core, Variable chain):**
- `MDTest` (30 tests, 90 assertions): all 24 static methods + 4 constants; autoCode status wrapping, case sensitivity, double-backtick prevention; fromArray recursive builder with header levels; determinism proof
- `CoreTest` (28 tests, 52 assertions): setVariable/getVariable (exact key, UPPER_CASE fallback, closure default), mergeVariables precedence (later wins), allVariables prefix filter, basePath relative/absolute/array, version() reading + caching, getEnv full type casting (null/int/float/bool/JSON array/JSON object/string), hasEnv, isDebug, allEnv filter, CompileDto roundtrip
- `VarChainTest` (20 tests, 30 assertions): full resolution order (ENV > Store > Meta > Method Hook > Default), method hook receives meta, ENV skips hook, varIs strict/loose, varIsPositive/Negative with truthy/falsy edge cases, allVars merge, groupVars prefix stripping, disableByDefault contract, determinism proof
- Suite: 75→153 tests, 218→390 assertions

**Refactor Batch 4 — Blueprint contracts + production code cleanup:**
- `BlueprintTest` (44 tests, 56 assertions): mutateToString passthrough/array-implode/null/empty-array; defaultElement for all 4 blueprints (rule/guideline/style/response_contract); IronRule severity chain — all 4 helpers (critical/high/medium/low) + string-to-enum + enum-direct + default UNSPECIFIED; IronRule builder fluency — text/why/onViolation return self + array imploding + full chain child accumulation; Guideline builder — text/example fluency + no-workflow-method contract; Style builder — language/tone/brevity/formatting fluency + forbiddenPhrases singleton pattern; Response builder — sections returns DTO + codeBlocks/patches fluency; BlueprintArchitecture::text append-with-newline + array-implode; id via set() (production pathway); determinism proof
- Production code: Guideline::workflow() dead method **REMOVED** (-4 lines); BlueprintArchitecture::mutateToString() `: mixed` return type added
- False lead closed: McpArchitecture::ksortRecursive() already has `: void` (audit was wrong)
- Suite: 153→197 tests, 390→446 assertions

Remaining gaps: XmlBuilder edge cases. CLI runtime tests require Laravel framework.

### 7. Release Discipline (3/3)

Strong: dependency pinning (`pins.json`), release manifest, build bundle script (`build-release-bundle.sh`), release CI gate, semantic versioning, CHANGELOG conventions.

### 8. Operability (3/3)

Comprehensive: benchmark suite (standard + LLM), ops evidence collection, failure runbooks, demo/pilot pack, observability documentation, ADR/ADV decision records.

### 9. Footguns (3.0/3)

**Core (3/3)**:
- ~~2 commented-out `dd()` blocks in `XmlBuilder.php`~~ **FIXED**
- ~~`dump()` in production fallback in `ConvertCommand.php:173`~~ **FIXED** (→ fwrite STDERR)
- ~~`CompileStandartsTrait.php` typo~~ **FIXED** (renamed to `CompileStandardsTrait.php`)
- ~~`HelloScript.php` dead scaffold~~ **FIXED** (removed)

**Node (3/3)**:
- ~~Placeholder Purpose in `Brain.php:14`~~ **FIXED** — real Purpose defined
- ~~Hardcoded paths in MCP configs~~ **FIXED** — `MakeMcpCommand::exportWithDynamicPaths()` now emits `getcwd() ?: '.'` instead of baking absolute path at generation time; paths resolve at `brain compile` time

### 10. Maintainability (3.0/3)

- ~~166/167 PHP files with strict_types~~ **FIXED** — now 167/167 (Brain.php added in batch 1)
- ~~`CompileStandartsTrait.php` typo~~ **FIXED** — renamed to `CompileStandardsTrait.php`, 4 files updated
- ~~`fakerphp/faker` in CLI production require~~ **FIXED** — moved to `require-dev`, dead `fake()` removed
- ~~Hardcoded paths (`/Users/xsaven/...`) in MCP configs and 1 test file~~ **FIXED** — MCP generator emits dynamic `getcwd()`, test fixture uses portable path
- `error_log()` in `ConvertCommand.php:193` (gated by env var — acceptable)

## Risk Matrix

| Risk Level | Total | Fixed | Reclassified | Open | Action |
|------------|-------|-------|--------------|------|--------|
| P0 (Critical) | 15 | 13 | 2 (→P2) | 0 | **ALL CLOSED** — audit gate is blocking + secret scanning |
| P1 (Important) | 8 | 7 | 1 (→P2) | 0 | P1-001 **FIXED**, P1-002 **FIXED**, P1-003 substantially improved (74/74), P1-005 done, P1-006 secrets **FIXED** |
| P2 (Nice to have) | 6+1+1+1 | 6 | 0 | 3 | P2-001 (SHA pinning) **FIXED**, P2-002 (concurrency) **FIXED**, P2-004 (hardcoded paths) **FIXED**, P2-005 (observability) **FIXED**, P2-006 (LegacyParityTest) **FIXED**, P2-007 (docs validation) **FIXED**; remaining: P2-003 (error_log), git history, DocChallenge.md paths |

## Audit Methodology

- Full file reads of all PHP source files in `core/src/`, `node/`, `cli/src/`, `scripts/`
- Automated grep scans for debug artifacts, silent catches, hardcoded paths
- CI workflow analysis for timeout, concurrency, action pinning
- Composer dependency review across all 3 packages
- Cross-reference between compiled CLAUDE.md claims and actual tooling
- Automated audit: 16 checks (syntax, tests, catches, debug, TODO, unsafe, shell, noop, LSB, typos, deps, phpstan, strict_types, secrets, paths, degradation)
