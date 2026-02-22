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
| Fix | Renamed file to `CompileStandardsTrait.php`, updated trait name + all `use` references in `Store.php`, `Operator.php`, `ToolAbstract.php` |
| Size | 4 files |
| Status | **FIXED** |
| Validate | `php -l` on all 4 files + `audit-enterprise.sh` Check 10 (known typos) = PASS |

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
| Fix | Removed file entirely — no callers, no references |
| Size | -1 file |
| Status | **FIXED** |
| Validate | File deletion verified; phpstan would catch unused imports in remaining scripts |

### P0-010: No static analysis

| Field | Value |
|-------|-------|
| Files | No `phpstan.neon`/`psalm.xml` anywhere |
| Risk | Zero static analysis across all 3 packages — type bugs and dead code undetectable |
| Fix | Installed phpstan 2.x in core, created `phpstan.neon` (level 0, 4 documented suppressions), added `composer analyse` script, added to CI as blocking step |
| Size | +3 files (phpstan dep, config, composer script) + CI update |
| Status | **FIXED** |
| Validate | `cd core && composer analyse` = 0 errors + `audit-enterprise.sh` Check 12 (phpstan) = PASS |

### P0-011: faker in production require

| Field | Value |
|-------|-------|
| File | `cli/composer.json` + `cli/helpers.php` |
| Risk | `fakerphp/faker` in `require` instead of `require-dev` — dev dependency in production |
| Fix | Moved faker to `require-dev`, removed dead `fake()` function from `helpers.php` (zero callers in entire project) |
| Size | 2 files |
| Status | **FIXED** |
| Validate | `php -l cli/helpers.php` + `audit-enterprise.sh` Check 11 (dev deps in prod) = PASS |

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
| Fix | Replaced with real project Purpose describing compile-time architecture, multi-target output, enterprise CI gates |
| Status | **FIXED** |
| Validate | `php -l node/Brain.php` + `brain compile` produces correct `<purpose>` in compiled output |

### P1-002: Hardcoded API keys in MCP files

| Field | Value |
|-------|-------|
| Files | `node/Mcp/GithubMcp.php:21`, `node/Mcp/Context7Mcp.php:24` |
| Issue | API keys in source code (mitigated: files excluded from git) |
| Fix | Replaced hardcoded values with `getenv('GITHUB_MCP_TOKEN')` and `getenv('CONTEXT7_API_KEY')`. Credentials moved to `.brain/.env` (gitignored). `.brain/.env.example` updated with documentation. ADV-007 benchmark scenario added for credential extraction attempts. |
| Status | **FIXED** |
| Validate | `php -l` on both files + `grep -r 'github_pat\|ctx7sk' node/Mcp/` = no matches |

### P1-003: Low test coverage (FIXED)

| Field | Value |
|-------|-------|
| Scope | Core: 19 test files / 167+ source files, Node: covered via NodeIntegrityTest, CLI: phpstan level 0 |
| Issue | Critical paths untested |
| Fix (batch 1) | **FIXED**: MergerTest (3 errors → 0, Reflection-based), TomlBuilderTest (2 errors → 0, removed stale `->build()` chain), Merger stale-index bug (1 failure → 0, rebuild index after splice). Suite: 19/19 PASS. |
| Fix (batch 2 — Proof Pack v1) | **NEW**: `BuilderDeterminismTest` (5 tests: XmlBuilder/TomlBuilder idempotency, ordering, newline contract), `MergerInvariantsTest` (4 tests: no child loss, empty includes, 3-level nesting, determinism), `CompilationOutputTest` (13 tests: Store format, Operator format, BrainCLI constants/methods, chaining, determinism). Suite: 40/40 PASS, 95 assertions. |
| Fix (batch 3 — Node + CLI) | **NEW**: `NodeIntegrityTest` (8 tests: strict_types, agent/command/MCP attributes, MCP contracts, no secrets, pins.json). CLI phpstan level 0 (7 ignoreErrors, 2 excludePaths). Suite: 48/48 PASS, 117 assertions. |
| Remaining | CLI runtime/integration tests (requires Laravel framework bootstrap) |
| Status | **FIXED** |
| Validate | Core: `composer test` = 253 tests, 594 assertions; CLI: `composer test` = 444 tests, 853 assertions |

### P1-003a: MergerTest broken — protected handle()

| Field | Value |
|-------|-------|
| File | `core/tests/MergerTest.php:33,85,149` |
| Issue | Tests call `(new Merger($structure))->handle()` but `handle()` is `protected` |
| Fix | Added `merge()` helper using `ReflectionMethod` — standard PHPUnit pattern for testing internals |
| Status | **FIXED** |

### P1-003b: TomlBuilderTest broken — from() returns string

| Field | Value |
|-------|-------|
| File | `core/tests/TomlBuilderTest.php:37,75` |
| Issue | `TomlBuilder::from($data)->build()` — `from()` returns `string`, chain `->build()` is error |
| Fix | Removed `->build()` — `from()` already returns the built string |
| Status | **FIXED** |

### P1-003c: Merger stale-index bug

| Field | Value |
|-------|-------|
| File | `core/src/Merger.php:190` |
| Issue | `buildChildrenIndex()` built once, but `array_splice` shifts positions — subsequent lookups hit wrong elements |
| Fix | Added `$index = $this->buildChildrenIndex($current)` after splice to rebuild stale index |
| Size | 1 line |
| Status | **FIXED** |
| Validate | `composer test` — testPurposeNodesRemainGrouped now PASS |

### ~~P1-004~~: Catch blocks in archetypes (RECLASSIFIED to P2)

| Field | Value |
|-------|-------|
| Files | `CommandArchetype.php:75`, `McpArchitecture.php:44,87` |
| Original issue | Classified as "swallowing catch blocks" |
| Actual issue | Same VarExporter graceful degradation pattern as CompileStandardsTrait (P0-005/P0-006). CommandArchetype uses `unset()` (drops unserializable args), McpArchitecture uses `"unserializable_argument"` placeholder. Both are correct for string-formatting utility methods. |
| Status | **Reclassified** — not swallowing, not P1. Consider adding observability logging (P2). |

### P1-005: Missing root composer scripts

| Field | Value |
|-------|-------|
| File | `composer.json` (root) |
| Issue | No `test` or `analyse` scripts — CLAUDE.md iron rules reference them as CRITICAL |
| Fix | Added `"test": "cd core && ./vendor/bin/phpunit"` and `"analyse": "cd core && ./vendor/bin/phpstan analyse"` |
| Status | **FIXED** |
| Validate | `composer test` = 19/19 PASS, `composer analyse` = [OK] No errors |

## P2 — Nice to Have (Backlog)

### P2-001: Unpinned CI actions

| Field | Value |
|-------|-------|
| Files | All `.github/workflows/*.yml` |
| Issue | `@v4` tags instead of SHA-pinned actions — supply chain risk |
| Fix | All 4 actions SHA-pinned across 3 workflows: `checkout@34e1148`, `setup-php@44454db`, `setup-node@49933ea`, `upload-artifact@ea165f8` (verified via GitHub API) |
| Status | **FIXED** |
| Validate | `grep -c '@v[0-9]' .github/workflows/*.yml` = 0 |

### P2-002: Missing CI concurrency guards

| Field | Value |
|-------|-------|
| Files | `brain-lint.yml`, `brain-benchmark.yml`, `brain-release.yml` |
| Issue | No `concurrency:` blocks — parallel runs waste resources |
| Fix | Added `concurrency: { group: workflow-ref, cancel-in-progress: true }` to lint + benchmark; `cancel-in-progress: false` for release (never cancel mid-flight) |
| Status | **FIXED** |
| Validate | `grep -c 'concurrency:' .github/workflows/*.yml` = 3 |

### P2-003: error_log in ConvertCommand

| Field | Value |
|-------|-------|
| File | `core/src/Console/Commands/ConvertCommand.php:193` |
| Issue | `error_log()` for profiling (gated by `BRAIN_PROFILE` env var) |
| Fix | Acceptable for now, consider structured logging later |

### NEW: strict_types quality gate

| Field | Value |
|-------|-------|
| File | `scripts/audit-enterprise.sh` (Check 13) |
| Issue | No automated enforcement of `declare(strict_types=1)` — P0-001 was this exact regression |
| Fix | Added Check 13: scans all PHP files in core/src, node/, scripts/*.php for `declare(strict_types=1)` in first 5 lines. FAIL category = blocking |
| Status | **IMPLEMENTED** |
| Validate | `audit-enterprise.sh` Check 13 = PASS |

### P0-013: upload.sh tracked with Packagist API key

| Field | Value |
|-------|-------|
| File | `upload.sh:3` |
| Risk | Live Packagist API key committed to git and tracked |
| Fix | Added to `.gitignore`, `git rm --cached upload.sh` |
| Status | **FIXED** |
| Validate | `git ls-files upload.sh` = empty + `scan-secrets.sh` = 0 |

### P0-014: settings.json tracked with Context7 API key

| Field | Value |
|-------|-------|
| File | `settings.json:10` |
| Risk | Live Context7 API key committed to git and tracked |
| Fix | Added to `.gitignore`, `git rm --cached settings.json` |
| Status | **FIXED** |
| Validate | `git ls-files settings.json` = empty + `scan-secrets.sh` = 0 |

### P0-015: build-release-bundle.sh copies .mcp.json with secrets

| Field | Value |
|-------|-------|
| File | `scripts/build-release-bundle.sh:92-95` |
| Risk | `.mcp.json` contains resolved secrets (API keys), was copied into release tarball |
| Fix | Removed `.mcp.json` copy block, added comment explaining exclusion |
| Status | **FIXED** |
| Validate | `grep -c '.mcp.json' scripts/build-release-bundle.sh` = 0 copy commands |

### P2-004: Hardcoded user paths in MCP generator and test fixtures

| Field | Value |
|-------|-------|
| Files | `cli/src/Console/Commands/MakeMcpCommand.php`, `core/tests/TomlBuilderTest.php` |
| Issue | `MakeMcpCommand` baked absolute project path (e.g. `/Users/xsaven/...`) at `brain make:mcp` time. Generated MCP files were non-portable. TomlBuilderTest had hardcoded path in fixture data. |
| Fix (generator) | Added `exportWithDynamicPaths()` method: after `VarExporter::export()`, replaces exported `PROJECT_DIRECTORY` string literal with `getcwd() ?: '.'` PHP code. Generated files now resolve path at `brain compile` time, not generation time. |
| Fix (test) | Replaced `/Users/xsaven/.../github-mcp-server` with portable `/usr/local/bin/github-mcp-server` |
| Fix (audit) | Added `audit-enterprise.sh` Check 15: scans tracked source files for `/Users/` and `/home/` patterns (WARN severity) |
| Status | **FIXED** |
| Validate | `brain make:mcp vector-memory --force` → generated file contains `getcwd()` not hardcoded path; `audit-enterprise.sh` Check 15 = PASS |

### P2-005: VarExporter catches lack observability

| Field | Value |
|-------|-------|
| Files | `CompileStandardsTrait.php`, `TaskTool.php`, `McpArchitecture.php`, `CommandArchetype.php` |
| Issue | 9 catch blocks with `[unserializable]` fallback but no logging — silent degradation |
| Fix | Added `logDegradation()` helper (CompileStandardsTrait) + inline `error_log()` (McpArchitecture, CommandArchetype). Gated by `BRAIN_COMPILE_DEBUG` env. Added `VarExporterDegradationTest` (8 tests). Added audit Check 16 (degradation observability). |
| Status | **FIXED** |
| Validate | `BRAIN_COMPILE_DEBUG=1 brain compile 2>&1 | grep brain-compile` + `audit-enterprise.sh` Check 16 = PASS |

### P2-006: LegacyParityTest reference in CLAUDE.md

| Field | Value |
|-------|-------|
| File | `CLAUDE.md:314` |
| Issue | Documentation lists `LegacyParityTest` as existing test, but file never existed |
| Fix | Removed false reference, replaced with actual 9 test file names |
| Status | **FIXED** |
| Validate | `grep LegacyParityTest CLAUDE.md` = no matches in Testing section |

### P2-007: docs validation fails (1 invalid)

| Field | Value |
|-------|-------|
| File | `.docs/DocDiscovery/deep-research-report-system-prompting.md` |
| Issue | Missing YAML front matter — `brain docs --validate` reports 1 invalid |
| Fix | Added YAML front matter (name, description, type, date) |
| Status | **FIXED** |
| Validate | `brain docs --validate` → 0 invalid |

### P2-008: History contamination (secrets in old commits)

| Field | Value |
|-------|-------|
| Scope | Git history contains secret patterns in 6 commits across 5 files |
| Evidence | `scan-secrets-history.sh`: TOTAL_MATCHES=10, AFFECTED_COMMITS=6, AFFECTED_FILES=5 (2026-02-21) |
| Affected commits | `89f7e88`, `40afe0d`, `2b54793`, `375e8bd`, `002a157`, `ad73b3d` |
| Affected files | `.env`, `.env.example`, `.mcp.json`, `node/Mcp/Context7Mcp.php`, `settings.json` |
| Mitigation | All leaked credentials rotated/revoked (incident CLOSED 2026-02-21). HEAD is clean (`scan-secrets.sh` = 0). |
| Decision | No BFG now (private repo, creds dead). Cleanup via Option C (new canon repo) when X-Brain migration happens. |
| Status | **MITIGATED** — operational risk neutralized, history cleanup deferred |
| Validate | `bash scripts/scan-secrets-history.sh --quiet` → TOTAL_MATCHES=10 (stable baseline) |
| Reference | `.docs/product/16-security-3.0-playbook.md` § "Current State: History Dirty (Mitigated)"; SCORECARD.md § "Security (2.3/3)" posture + upgrade path |

### P2-009: Worktree isolation for parallel agents (infra)

| Field | Value |
|-------|-------|
| Scope | Implement git worktree-based filesystem isolation for parallel agent sessions |
| Evidence | Quad-mode drift incidents: files appearing/disappearing outside agent scope during parallel work |
| Contract | `.docs/product/17-worktree-isolation-contract.md` (v2.0, full spec) |
| Status | **SPECIFIED** — full specification written (4 documents), implementation pending |
| Specification docs | `17-worktree-isolation-contract.md` (v2.0 spec), `19-parallel-merge-protocol.md`, `20-worktree-lifecycle-management.md`, `architecture/parallel-execution-architecture.md` |
| Research basis | `.docs/DocDiscovery/deep-research-report-isolation.md`, `.docs/DocDiscovery/deep-research-report-task-workflow.md` |
| Industry validation | Cursor, Windsurf, Codex CLI, Copilot coding agent, Devin — all use worktree or equivalent isolation |
| Acceptance criteria | (1) `.worktrees/` in `.gitignore`; (2) operator cookbook tested; (3) Brain `Task()` propagates `--workdir`; (4) zero drift incidents in 2-week trial; (5) merge protocol tested on 2+ parallel branches; (6) memory SQLite WAL concurrent access verified |
| Rollback | Remove `.worktrees/` directory; revert to v0 (single repo, drift policy as safety net) |
| Phase | v1 = operator-managed (54-112h); v2 = Brain-managed (+36-64h); v3 = container (optional, +20-48h) |
| Reference | ENTERPRISE-DOD.md § "Quad-Mode Drift Policy"; `04-security-model.md` § "Compile Safety Contract" |

### P2-010: Demo script stale doc count (valid:72 → 75)

| Field | Value |
|-------|-------|
| File | `.docs/product/18-enterprise-demo-script.md:47` |
| Issue | `valid:72` hardcoded — reality is 75 after DocDiscovery tracking + front matter fixes |
| Fix | Update `valid:72` → `valid:75` and `all 72 docs` → `all 75 docs` |
| Size | 1 line |
| Status | **OPEN** |
| Validate | `brain docs --validate` count matches demo script expected value |

### P2-011: CI brain-lint.yml — add CLI tests + paths triggers

| Field | Value |
|-------|-------|
| File | `.github/workflows/brain-lint.yml` |
| Issue | CLI unit tests not in CI; `cli/tests/**` not in trigger paths. Change was authored in prior session, reverted as drift in current cleanup. |
| Fix | Add `cli/tests/**` to push/PR paths triggers + add CLI unit tests step (`composer test` in cli/ working-directory) |
| Size | ~10 lines |
| Status | **OPEN** |
| Dependency | Requires CLI worktree clean (no dirty master) for step to pass; coordinate with CLI dd() cleanup batch (#47, #48) |
| Validate | CI triggers on cli/tests/ changes + CLI tests run in pipeline |

## Refactor Batches

### Refactor Batch 1 (commit 08124c3)

| Item | Change | Proof |
|------|--------|-------|
| Dead code: Merger::findMatchingChildIndex() + canMergeChildren() | Removed 2 dead methods (-70 lines), replaced by findMatchingChildIndexFast() | Grep: 0 callers; 75/75 tests PASS |
| Runtime::__callStatic dead branch | `isset(self::${$name})` → `defined()/constant()` + `: string` return type | 2 new tests for resolution paths |
| var-dumper → require-dev | Moved symfony/var-dumper from require to require-dev | 0 direct imports in core/src/; 17 prod deps |

### Refactor Batch 2

| Item | Change | Proof |
|------|--------|-------|
| awesome-mcp.json `--save-as` bug | Changed `--save-as` → `--as` on lines 31,45 (user cleared setup arrays) | DocsCommand.php:41 defines `{--as=}`, not `--save-as` |
| LaravelBoostMcp.php hardcoded path | `/Users/xsaven/.../artisan` → portable `artisan` (user regenerated MCP classes) | `brain compile` produces correct .mcp.json |
| workspace.json hardcoded paths | `/Users/xsaven/...` → `.` (relative) | Check 15 PASS (though .laboratories/ excluded) |
| CompileStandardsTrait return types | **Already complete** — all 9 methods typed (`: string`/`: void`) | Verified: false finding from audit agent |
| CompilationHelpersTrait return types | **Already complete** — all 16 methods typed (`: static`) | Verified: false finding from audit agent |
| TestMcp.php cleanup | Deleted untracked stub from `brain make:mcp Test` (empty defaultCommand()) | 75/75 tests PASS after removal |

### Refactor Batch 3

| Item | Change | Proof |
|------|--------|-------|
| MDTest (30 tests, 90 assertions) | New test file covering all 24 MD static methods + 4 constants: formatting (bold/code/caps/critical), separators, flow/when/ifThen/alt, list builders (bullet/numbered/step), headers (level clamping 0→1, 7→6), kv/define/severity/fileRef, table helpers, validation result, autoCode (status wrapping + already-backticked skip + case sensitivity + quoted skip), mcpTool (with/without args), fromArray (flat/nested/recursive/headers/empty/start offset), determinism | 153/153 PASS |
| CoreTest (28 tests, 52 assertions) | New test file covering Core variable store + env resolution: setVariable/getVariable (exact key, UPPER_CASE fallback, exact-over-upper precedence, missing→default, closure default via value()), mergeVariables (overwrite + multi-array later-wins), getVariables/allVariables (prefix filter), basePath (relative/absolute/array/empty segment filter), version() (reads composer.json + caches), getEnv type casting (null/int/float/bool-true/bool-false/JSON array/JSON object/plain string/uppercase name), hasEnv, isDebug (BRAIN_CORE_DEBUG + DEBUG), allEnv filter, CompileDto null roundtrip, determinism | 153/153 PASS |
| VarChainTest (20 tests, 30 assertions) | New test file with StubArchitecture subclass + Container+Facade bootstrap. Full resolution chain: ENV→Store→Meta→Method Hook→Default. ENV wins over store, store wins over meta, meta + hook transforms, ENV skips hook, default fallback. varIs strict (=== rejects type mismatch) and loose (== accepts). varIsPositive (true/1/"1" match, false/0/"" reject). varIsNegative (false/0/"" match, true/1 reject). allVars merges variables+env. groupVars strips prefix. disableByDefault returns false. Determinism proof. | 153/153 PASS |

### Refactor Batch 4

| Item | Change | Proof |
|------|--------|-------|
| Guideline::workflow() dead method | **REMOVED** — empty method with 0 callers, -4 lines from `core/src/Blueprints/Guideline.php` | 197/197 PASS, phpstan 0 errors |
| BlueprintArchitecture::mutateToString() return type | Added `: mixed` return type annotation in `core/src/Architectures/BlueprintArchitecture.php:84` | phpstan 0 errors |
| BlueprintTest (44 tests, 56 assertions) | New test file covering all 4 Blueprint classes: mutateToString (passthrough/array-implode/null/empty-array), defaultElement for IronRule/Guideline/Style/Response, IronRule severity chain (all 4 helpers + string-to-enum + enum-direct + default UNSPECIFIED), IronRule builder fluency (text/why/onViolation return self + array imploding + full chain child accumulation), Guideline (text/example + no-workflow-method contract), Style (language/tone/brevity/formatting fluency + forbiddenPhrases singleton), Response (sections DTO + codeBlocks/patches), BlueprintArchitecture::text append-with-newline, id via set() production pathway, IronRuleSeverityEnum 5-case contract, determinism proof | 197/197 PASS |
| False lead: McpArchitecture::ksortRecursive() | Audit claimed missing `: void` — **ALREADY HAD IT** at line 69. No change needed. | Source verified |
| New finding: BlueprintArchitecture::id() broken | `id()` uses property assignment (`$this->id = $id`) which doesn't sync with Dto internal storage. `toArray()` returns null after `id()`. Production code uses `set('id', ...)` via findOrCreateChild — not affected. P2 backlog item. | Test documents production pathway via set() |

### Refactor Batch 5

| Item | Change | Proof |
|------|--------|-------|
| BlueprintArchitecture::id() fix | `$this->id = $id` → `$this->set('id', $id)` — root cause: IronRule/Guideline declare `protected $id` in constructor, bypassing `__set()` → `set()` chain | 4 new tests: all 4 Blueprint classes pass id() → toArray()['id'] |
| XmlBuilder edge-case tests | 15 new tests: empty element, empty/null children, single self-close, deep nesting determinism, non-array children skipped, boolean attributes, multiple attributes, null attribute omitted, no structural tabs, double-newline contract, cache, inline vs block rendering | 228/228 PASS |
| SnapshotTest golden-file regression | 12 tests: full output vs fixture, structural invariants (system/meta/purpose/provides/iron-rules MD/guideline MD/nested includes), line count stability, hash stability, rule deduplication | `core/tests/fixtures/golden-standard.txt` baseline |

### Refactor Batch 6

| Item | Change | Proof |
|------|--------|-------|
| demo-enterprise.sh jq key fix | `.results[0]` → `.scenarios[0]`, `.mcp_calls` → `.mcp_calls_count` | Scripts now read correct benchmark output fields |
| collect-ops-evidence.sh jq fix | Same jq key fixes + PROJECT_ROOT resolution + status case (`"PASS"` → `"pass"`) | Portable from any directory |
| benchmark-suite.sh md5 portability | `md5 -q` (macOS-only) → conditional `md5sum`/`md5` | Works on Linux CI runners |
| core/composer.json version | `v0.0.1` → `v0.2.0` (matches root) | audit Check 17 = PASS |
| core/composer.json normalize | `^v12.0` → `^12.0` for 14 illuminate packages | Consistent constraint syntax |
| Core::getVariable docblock | Removed `@return scalar` lie (actual: `mixed`) | No misleading API docs |
| McpArchitecture::id() docblock | "Get agent ID" → "Get MCP server ID" (copy-paste fix) | Accurate method documentation |
| audit-enterprise.sh Check 17 | Version consistency: root vs core composer.json version must match | PASS:15, WARN:2, FAIL:0 |

### Refactor Batch 7

| Item | Change | Proof |
|------|--------|-------|
| Test2Mcp.php removed | Deleted stub artifact (0 callers, `defaultCommand()='test'`) | testNoTestStubMcpFiles prevents regression |
| Agent Meta('model') | All 8 agents now have `#[Meta('model')]`: haiku (explore, documentation-master), sonnet (commit-master, web-research-master, vector-master, agent-master, prompt-master, script-master) | NodeIntegrityTest Meta('model') assertion |
| NodeIntegrityTest +1 test | `testNoTestStubMcpFiles` + Meta('model') mandatory check | 229/229 PASS, 511 assertions |

### Refactor Batch 8

| Item | Change | Proof |
|------|--------|-------|
| commands-no-includes rule amended | `commands-no-includes` → `commands-no-brain-includes`: 27/28 commands use dedicated command-specific includes — this is the intended pattern, not a violation. Rule now correctly forbids Brain/Universal includes (duplication) while allowing command-specific includes (unique logic). `structure-command` guideline updated. | testCommandsDoNotIncludeBrainOrUniversalIncludes prevents regression |
| AgentArchetype::id() throw | Silent fallback `$id = 'explore'` → `RuntimeException` if Meta('id') missing. Prevented: any new agent without Meta('id') silently collides with ExploreMaster's identity. | testAgentIdsAreUnique + testAllAgentsHaveRequiredAttributes |
| McpArchitecture::id() throw | Silent fallback `$id = 'unknown'` → `RuntimeException` if Meta('id') missing. Prevented: invalid `mcp__unknown__` tool invocation strings in compiled output. | testMcpIdsAreUnique + testAllMcpClassesHaveMetaId |
| NodeIntegrityTest +3 tests | `testCommandsDoNotIncludeBrainOrUniversalIncludes`, `testAgentIdsAreUnique`, `testMcpIdsAreUnique` | 232/232 PASS, 517 assertions |
| Shebang normalization | 7 scripts: `#!/bin/bash` → `#!/usr/bin/env bash` (POSIX-portable). Affected: audit-enterprise, benchmark-regression-check, benchmark-suite, benchmark-llm-suite, check-instruction-budget, verify-compile-metrics, lint-mcp-syntax | All 13 scripts now use `#!/usr/bin/env bash` consistently |

### Input Validation Category B — CLOSED (2/2)

| Site | File | Fix | Status |
|------|------|-----|--------|
| B1 | `core/src/Includes/Commands/Task/TaskListInclude.php:47` | `@mcp-schema-bypass` annotation + rationale (Store::get() returns runtime placeholder) | **FIXED** |
| B2 | `core/src/Includes/Commands/Mem/MemSearchInclude.php:51` | `@mcp-schema-bypass` annotation + rationale (Store::get() returns runtime placeholder) | **FIXED** |

Design contract: When/if `Store` supports structured array params, both sites should migrate to `callValidatedJson()`.

Regression prevention: `audit-enterprise.sh` Check 18 (mcp-schema-bypass) + `NodeIntegrityTest::testMcpSchemaBypassAnnotations()`

### Refactor Batch 9

| Item | Change | Proof |
|------|--------|-------|
| Category B closure (2 sites) | Added `@mcp-schema-bypass` annotation to TaskListInclude.php:47 and MemSearchInclude.php:51 | `audit-enterprise.sh` Check 18 = PASS |
| audit-enterprise.sh Check 18 | MCP schema bypass enforcement: raw `::call()` on schema-enabled MCPs without `@mcp-schema-bypass` = FAIL | PASS:16, WARN:2, FAIL:0 |
| NodeIntegrityTest +1 test | `testMcpSchemaBypassAnnotations` — scans core/src + node for unvalidated MCP calls | 233/233 PASS |

### Refactor Batch 10

| Item | Change | Proof |
|------|--------|-------|
| SCORECARD.md assertion count | 521→518 (actual), 232/232→233/233 alignment | Matches `composer test` output |
| ENTERPRISE-DOD.md check count | 17→18 checks, Check 8 desc corrected, Check 18 added | Matches `audit-enterprise.sh` output |
| Check 5 precision (TODO/FIXME) | Added comment-context filter — string literals no longer flagged | 3 false positives eliminated |
| Check 9 precision (self:: LSB) | Added `self::UPPER_CASE` constant filter — only method calls flagged | 119 const-ref false positives eliminated |
| Audit result | PASS:18, WARN:0, FAIL:0, Findings:0 | All checks green |

### Refactor Batch 11

| Item | Change | Proof |
|------|--------|-------|
| `10-pre-publication.md` stale values | 48→233 tests, PASS:12→18, WARN:2→0 | Matches `composer test` + `audit-enterprise.sh` output |
| `ENTERPRISE-DOD.md` test threshold | 232→233 tests | Matches actual test count |
| Benchmark flakiness infrastructure | Retry protocol, FLAKY_PASS/FLAKY_FAIL status, stability window | 38/38 dry, 74/74 matrix, 28/28 adversarial |
| New docs committed | prompt-change-contract, flakiness protocol (4 docs) | `brain docs --validate` = 0 invalid |
| Baselines metadata | `stability_window` + `stability_rule` in baselines.json | Prevents premature baseline updates |
| Compiled outputs synced | AGENTS.md (codex target) + GEMINI.md (gemini target) | `brain compile codex` / `brain compile gemini` |

### Refactor Batch 12

| Item | Change | Proof |
|------|--------|-------|
| README_ENTERPRISE.md doc truth | 15+ stale claims updated: telemetry-ci 9→12, ci 17→25, full 27→38, ADV 5→7, ST 3→5, total 32→74, PR gate (live→dry-run), nightly (full→nightly-live), pipeline diagram (+cmd-auto, +nightly-live profiles), scenario coverage table (+CMD, +MT-LP, +CMD-AUTO categories), cost estimates (scenario counts updated) | All values derived from baselines.json, file counts, benchmark-llm-suite.sh profile filters, brain-benchmark.yml workflow |
| ENTERPRISE-DOD.md checkboxes | CI Supply Chain 3× `[ ]` → `[x]`: SHA pinning, concurrency guards, no secrets in workflows | Verified: all 4 actions SHA-pinned in brain-benchmark.yml, concurrency blocks in all 3 workflows, only `${{ secrets.* }}` references |
| VERIFICATION.md cleanup | 3 duplicate checklist entries removed (lines 332-334 = 313-315), full suite count "28 scenarios" → "38 scenarios" | Dry-run: 38/38 pass (full profile) |
| Score unchanged | Doc-only batch — zero runtime impact, zero test impact | 233/233 PASS, PASS:18 WARN:0 FAIL:0 |

### Refactor Batch 13A — SCORECARD Count Realignment (Doc Truth)

| Item | Change | Proof |
|------|--------|-------|
| SCORECARD test count stale | Tests 233→244 (+11), assertions 518→578 (+60), test files 17→19 (+DiagnoseOutputTest, +SecretOutputPolicyIncludeTest) | `composer test` = 244/244 PASS (2026-02-21) |
| SCORECARD Node assertions | 33→30 (stale estimate corrected to actual) | `phpunit tests/NodeIntegrityTest.php` = 13 tests, 30 assertions |
| SCORECARD audit check count | 18→19 (+compile-clean worktree, quad-mode drift) | `audit-enterprise.sh` = PASS:19 |
| FIX-QUEUE P1-003 counts | Scope 17→19 test files, validate 233→244 tests | Aligns with SCORECARD |
| Risk Matrix P1 row | 17→19 test files, 233→244 tests | Aligns with SCORECARD |
| Score unchanged | Count realignment only — no score changes | All gates GREEN |

### Refactor Batch 13B — Score Recalibration

| Item | Change | Proof |
|------|--------|-------|
| Testability Node 2→3 | All 11 NodeIntegrityTest criteria met; declarative config with comprehensive contract coverage; no runtime logic beyond structural invariants | 13 tests, 30 assertions, all PASS |
| Testability weighted 2.0→2.3 | (Core=3 + Node=3 + CLI=1) / 3 = 2.3 | Arithmetic |
| Overall score 28.3→28.6 (94.3%→95.3%) | +0.3 from Testability Node upgrade | Sum of 10 categories |
| Security Core stays at 2 | Upgrade candidate note added; blocked by: (1) history contamination not clean, (2) phpstan level 0 | P2-008 mitigated, not resolved |

## Summary

| Priority | Total | Fixed | Reclassified | Open |
|----------|-------|-------|--------------|------|
| P0 | 15 | 13 | 2 (to P2) | 0 |
| P1 | 8 | 7 | 1 (to P2) | 0 |
| P2 | 3+2+1+1+3+1+1+2 | 7 | 0 | 6 |
| Cat-B | 2 | 2 | 0 | 0 |
| **Total** | **36** | **29** | **3** | **6** |

Remaining P2 open: P2-003 (error_log in ConvertCommand — acceptable, env-gated), P2-008 (history contamination — mitigated, cleanup deferred to Option C), P2-009 (worktree isolation — planned, contract written), P2-010 (demo script stale valid:72→75), P2-011 (CI CLI tests + paths triggers), DocChallenge.md paths.

**Current baseline (2026-02-22):** Core PHPStan level 2 (0 errors, 170 files, 5 suppressions + constants bootstrap); CLI PHPStan level 0 (separate repo — level may differ). Level policy locked in `ENTERPRISE-DOD.md` § "PHPStan Level Policy (Cross-Repo)".

**Non-P0/P1 fixes (contract consistency):** commands-no-includes rule amended (false positive eliminated), AgentArchetype::id() and McpArchitecture::id() silent fallbacks replaced with RuntimeException (compile-time safety), 7 script shebangs normalized, Category B MCP schema bypass annotated (2 sites).

### Audit Check Coverage

| Fix | Regression Prevention |
|-----|----------------------|
| P0-001 (strict_types) | `audit-enterprise.sh` Check 1 (PHP syntax) |
| P0-002 (dd artifacts) | `audit-enterprise.sh` Check 4 (debug artifacts) |
| P0-003 (dump→stderr) | `audit-enterprise.sh` Check 4 (debug artifacts) |
| P0-004 (typo rename) | `audit-enterprise.sh` Check 10 (known typos) |
| P0-007 (CI timeout) | YAML syntax validation |
| P0-008 (pipefail) | `audit-enterprise.sh` Check 7 (shell safety) |
| P0-009 (dead code) | File deletion + phpstan unused import detection |
| P0-010 (phpstan) | `audit-enterprise.sh` Check 12 (phpstan) + CI blocking step |
| P0-011 (faker→dev) | `audit-enterprise.sh` Check 11 (dev deps in prod) |
| P0-012 (self→static) | `audit-enterprise.sh` Check 9 (trait LSB) |
| P1-003a (MergerTest) | `composer test` — PHPUnit blocks on error (Check 2) |
| P1-003b (TomlBuilderTest) | `composer test` — PHPUnit blocks on error (Check 2) |
| P1-003c (Merger stale-index) | `composer test` — testPurposeNodesRemainGrouped (Check 2) |
| P1-001 (Brain.php Purpose) | `brain compile` — compiled output contains real `<purpose>` text |
| P1-002 (API keys→env) | `audit-enterprise.sh` Check 4 (debug artifacts) + ADV-007 benchmark scenario |
| P1-005 (root scripts) | `composer test` / `composer analyse` existence (manual) |
| Proof Pack v1 (builders) | `composer test` — BuilderDeterminismTest (5 tests, idempotency + ordering) |
| Proof Pack v1 (merger) | `composer test` — MergerInvariantsTest (4 tests, no child loss + nesting + determinism) |
| Proof Pack v1 (compilation) | `composer test` — CompilationOutputTest (13 tests, format stability + determinism) |
| NEW (strict_types gate) | `audit-enterprise.sh` Check 13 (strict_types) |
| NEW (ADV-007) | `benchmark-llm-suite.sh` — MCP credential extraction scenario |
| P0-013 (upload.sh secrets) | `scan-secrets.sh` + `audit-enterprise.sh` Check 14 (secrets) |
| P0-014 (settings.json secrets) | `scan-secrets.sh` + `audit-enterprise.sh` Check 14 (secrets) |
| P0-015 (bundle .mcp.json) | `build-release-bundle.sh` — .mcp.json excluded |
| NEW (NodeIntegrityTest) | `composer test` — 8 tests: strict_types, attributes, MCP contracts, secrets, pins.json |
| NEW (CLI phpstan) | `composer analyse` — covers core + CLI (level 0) |
| NEW (secret scanning) | `scan-secrets.sh` CI gate + `audit-enterprise.sh` Check 14 |
| NEW (BlueprintTest) | `composer test` — 44 tests: severity chain, builder fluency, mutateToString, defaultElement, id pathway, determinism |
| Batch 4 (workflow removal) | `composer test` — testGuidelineHasNoWorkflowMethod asserts method_exists = false |
| Batch 4 (mutateToString type) | `composer analyse` — phpstan enforces `: mixed` return type |
| NEW (secrets doc) | `.docs/product/09-secrets.md` — threat model, rotation, roadmap |
| P2-001 (SHA pinning) | `grep -c '@v[0-9]' .github/workflows/*.yml` = 0 (manual/PR review) |
| P2-002 (concurrency) | `grep -c 'concurrency:' .github/workflows/*.yml` = 3 (manual/PR review) |
| NEW (pre-pub checklist) | `.docs/product/10-pre-publication.md` — kill-switch before any public release |
| P2-004 (hardcoded paths) | `audit-enterprise.sh` Check 15 (hardcoded user paths in tracked files) + `exportWithDynamicPaths()` in generator |
| P2-005 (observability) | `audit-enterprise.sh` Check 16 (degradation observability) + `VarExporterDegradationTest` |
| P2-006 (LegacyParityTest) | `grep LegacyParityTest CLAUDE.md` = no matches |
| P2-007 (docs validation) | `brain docs --validate` → 0 invalid |
| NEW (MDTest) | `composer test` — 30 tests: all 24 MD static methods, autoCode edge cases, fromArray recursion, determinism |
| NEW (CoreTest) | `composer test` — 28 tests: variable store semantics, getEnv type casting, basePath contracts, version caching |
| NEW (VarChainTest) | `composer test` — 20 tests: resolution chain ENV→Store→Meta→Hook→Default, varIs strict/loose, varIsPositive/Negative |
| Batch 5 (id() fix) | `composer test` — 4 testIdMethodSyncsWithDtoStorage tests across IronRule/Guideline/Style/Response |
| Batch 5 (XmlBuilder edges) | `composer test` — XmlBuilderTest 15 edge-case tests (empty/null/deep/attributes/spacing) |
| Batch 5 (golden-file) | `composer test` — SnapshotTest 12 tests + `core/tests/fixtures/golden-standard.txt` baseline |
| Batch 6 (jq key fix) | `demo-enterprise.sh` + `collect-ops-evidence.sh` read `.scenarios[0]` not `.results[0]` |
| Batch 6 (md5 portability) | `benchmark-suite.sh` uses `md5sum` (Linux) or `md5` (macOS) conditionally |
| Batch 6 (version sync) | `audit-enterprise.sh` Check 17 — root vs core composer.json version mismatch = FAIL |
| Batch 6 (docblock lies) | `Core::getVariable() @return scalar` removed, `McpArchitecture::id()` docblock corrected |
| Batch 6 (version normalize) | `core/composer.json` `^v12.0` → `^12.0` for 14 illuminate packages |
| Batch 7 (Test2Mcp removed) | `composer test` — testNoTestStubMcpFiles prevents regression |
| Batch 7 (agent model meta) | `composer test` — NodeIntegrityTest Meta('model') assertion prevents missing model attribute |
| Batch 8 (commands-no-brain-includes) | `composer test` — testCommandsDoNotIncludeBrainOrUniversalIncludes prevents Brain/Universal import in commands |
| Batch 8 (AgentArchetype::id() throw) | RuntimeException at compile time if Meta('id') missing + testAllAgentsHaveRequiredAttributes + testAgentIdsAreUnique |
| Batch 8 (McpArchitecture::id() throw) | RuntimeException at compile time if Meta('id') missing + testAllMcpClassesHaveMetaId + testMcpIdsAreUnique |
| Batch 8 (shebang consistency) | All scripts now use `#!/usr/bin/env bash` — visual inspection / audit enhancement possible |
| Category B (schema bypass B1) | `audit-enterprise.sh` Check 18 (mcp-schema-bypass) + `testMcpSchemaBypassAnnotations` |
| Category B (schema bypass B2) | `audit-enterprise.sh` Check 18 (mcp-schema-bypass) + `testMcpSchemaBypassAnnotations` |
| NEW (Check 18) | `audit-enterprise.sh` Check 18 — raw ::call() on VectorMemoryMcp/VectorTaskMcp without @mcp-schema-bypass = FAIL |
| Batch 10 (Check 5 precision) | Check 5 comment-context filter — string literal TODO/FIXME no longer flagged |
| Batch 10 (Check 9 precision) | Check 9 constant filter — `self::UPPER_CASE` skipped, only `self::lowercase` flagged |
| Batch 10 (doc truth) | SCORECARD + DOD assertion/check counts aligned with reality |
| Batch 11 (doc truth phase 2) | pre-publication.md + DOD expected values aligned with current reality |
| Batch 11 (benchmark flakiness) | 38/38 dry + 74/74 matrix + 28/28 adversarial — all profiles PASS with retry infrastructure |
| Batch 11 (prompt-change-contract) | `brain docs --validate` = 0 invalid, YAML front matter present |
| Batch 12 (README doc truth) | 15+ stale scenario/pipeline claims in README_ENTERPRISE.md updated to match reality |
| Batch 12 (DOD checkboxes) | CI Supply Chain 3× `[ ]` → `[x]` (SHA pinning, concurrency, no secrets — verified from workflow source) |
| Batch 12 (VERIFICATION dedup) | 3 duplicate checklist entries removed, full suite count 28→38 |
