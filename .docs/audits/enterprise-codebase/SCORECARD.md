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
| 4 | Security | 2 | 3 | 2 | 2.3 | ~~No static analysis~~ **FIXED** (phpstan level 0); ~~API keys in MCP files~~ **FIXED** (getenv()); ~~CI actions tag-pinned~~ **FIXED** (SHA-pinned); **NEW**: Secret scanning CI gate, release bundle .mcp.json exclusion, upload.sh/settings.json untracked, threat model doc, CI concurrency guards, pre-publication kill-switch |
| 5 | Docs Parity | 3 | 2 | -- | 2.5 | ~~`composer test`/`analyse` missing at root~~ **FIXED** — scripts added, both pass |
| 6 | Testability | 2 | 1 | 1 | 1.5 | ~~MergerTest/TomlBuilderTest broken~~ **FIXED** — 52/52 pass (125 assertions); Proof Pack v1+v2: builder determinism, merger invariants, compilation output, compile idempotency; **NEW**: CompileIdempotencyTest (4 tests: pipeline determinism, MCP JSON preservation, nested includes, special chars); NodeIntegrityTest (8 tests); CLI phpstan level 0 |
| 7 | Release Discipline | 3 | 3 | -- | 3.0 | Pinning, manifest, bundle, release CI -- all good |
| 8 | Operability | 3 | 3 | -- | 3.0 | Benchmarks, runbooks, ops-evidence, demo -- comprehensive |
| 9 | Footguns | 3 | 3 | -- | 3.0 | ~~Debug artifacts~~ **FIXED**; ~~typo in class name~~ **FIXED**; ~~dead scaffold~~ **FIXED**; ~~hardcoded MCP paths~~ **FIXED** (generator emits getcwd()) |
| 10 | Maintainability | 3 | 3 | -- | 3.0 | ~~strict_types~~ **FIXED**; ~~CompileStandartsTrait typo~~ **FIXED**; ~~faker in prod~~ **FIXED**; ~~hardcoded paths~~ **FIXED** (generator + test) |

**Overall Score: 25.3 / 30 (84.3%)**

## Category Details

### 1. Determinism (3/3)

No sources of non-determinism found. No `rand()`, `shuffle()`, `mt_rand()`, `array_rand()`, `uniqid()`. Compile output is stable across runs. Build cache uses `md5(serialize())` which is deterministic for same input.

### 2. Error Handling (2/3)

**Core (2/3)**: 5 catch blocks in `CompileStandardsTrait.php` and 1 in `TaskTool.php:22` — verified: all have graceful degradation fallback (`[unserializable]`) for `VarExporter::export()` failures. Correct pattern for non-exportable values. Minor gap: no logging for observability. `CommandArchetype.php:75` and `McpArchitecture.php:44,87` — same VarExporter pattern, reclassified P1-004→P2.

**Node (2/3)**: Zero try/catch blocks. Correct for declarative configuration -- errors bubble to compiler.

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

### 5. Docs Parity (2.5/3)

Compiled CLAUDE.md declares iron rules:
- `QUALITY GATE [TEST]: composer test` — ~~no `test` script in root~~ **FIXED** — added, proxies to `core/phpunit`
- `QUALITY GATE [PHPSTAN]: composer analyse` — ~~no `analyse` script~~ **FIXED** — added, proxies to `core/phpstan`

Both quality gates now enforceable from root. Remaining gap: no root-level test aggregation across CLI/Node.

### 6. Testability (1.5/3)

| Package | Test Files | Source Files | Tests | Assertions | Status |
|---------|-----------|--------------|-------|------------|--------|
| Core | 9 | 167+ | 52 | 125 | 52/52 PASS |
| Node | 0 (tested via Core) | 44 | 8 | 22 | via NodeIntegrityTest |
| CLI | 7 | ~30+ | ~20 | ~50 | Separate repo + PHPStan level 0 |

**Fixes applied:**
- ~~MergerTest: protected `handle()` call from test~~ **FIXED** — Reflection-based invocation
- ~~TomlBuilderTest: `from()` returns string, tests chain `->build()`~~ **FIXED** — removed stale chain
- ~~Merger stale-index bug: `array_splice` shifts positions but hash index not rebuilt~~ **FIXED** — index rebuilt after splice
- ~~LegacyParityTest referenced in docs but never existed~~ Confirmed: file does not exist (P2 backlog)
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
- Suite: 48→52 tests, 117→125 assertions

Remaining gaps: Runtime class, Tool classes, Archetypes, Variable system.

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
| P1 (Important) | 8 | 7 | 1 (→P2) | 0 | P1-001 **FIXED**, P1-002 **FIXED**, P1-003 substantially improved (48/48), P1-005 done, P1-006 secrets **FIXED** |
| P2 (Nice to have) | 6+1+1 | 4 | 0 | 4 | P2-001 (SHA pinning) **FIXED**, P2-002 (concurrency) **FIXED**, P2-004 (hardcoded paths) **FIXED**; remaining: P2-003 (error_log), git history, DocChallenge.md paths, LegacyParityTest |

## Audit Methodology

- Full file reads of all PHP source files in `core/src/`, `node/`, `cli/src/`, `scripts/`
- Automated grep scans for debug artifacts, silent catches, hardcoded paths
- CI workflow analysis for timeout, concurrency, action pinning
- Composer dependency review across all 3 packages
- Cross-reference between compiled CLAUDE.md claims and actual tooling
