---
name: "Changelog"
description: "Release changelog for jarvis-brain/node"
---

# Changelog

## [Unreleased]

## [v0.2.0] — 2026-02-21

Enterprise-hardened release. Scorecard: 27.3/30 (91%).

### Added — Enterprise Audit & Automation
- **Audit Script**: `scripts/audit-enterprise.sh` — 16-check automated enterprise audit (syntax, tests, catches, debug, TODO, unsafe, shell, noop, LSB, typos, deps, phpstan, strict_types, secrets, paths, degradation)
- **Secret Scanner**: `scripts/scan-secrets.sh` — standalone CI gate, blocks on leaked credentials
- **MCP Linter**: `scripts/lint-mcp-syntax.sh` — validates MCP pseudo-syntax in compiled output
- **Benchmark Scenario**: `ADV-007` — MCP credential extraction adversarial test
- **Secrets Threat Model**: `.docs/product/09-secrets.md` — attack surfaces, do/don't, key rotation
- **Pre-Publication Kill-Switch**: `.docs/product/10-pre-publication.md` — credential rotation checklist

### Added — Test Suite (Core)
- **Proof Pack v1**: BuilderDeterminismTest (5), MergerInvariantsTest (4), CompilationOutputTest (13)
- **Proof Pack v2**: CompileIdempotencyTest (4), NodeIntegrityTest (8)
- **Proof Pack v3**: RuntimeTest (7), ToolFormatTest (8), VarExporterDegradationTest (8)
- Core: 12 test files, 74 tests, 214 assertions — all pass
- PHPStan level 0: Core (167 files) + CLI (119 files) — 0 errors

### Added — Enterprise Ops Maturity
- **Observability**: `scripts/collect-ops-evidence.sh` — generates `dist/ops-evidence.json`
- **Failure Runbooks**: `.docs/product/07-runbooks-failures.md` — 6 failure scenarios
- **Permissions Contract**: `.docs/product/08-permissions.md` — safe-by-default posture
- **Benchmark Scenario**: `ADV-006-permissions-enforcement` — destructive action refusal test

### Added — Sales Demo + Pilot Pack
- **Enterprise Demo**: `scripts/demo-enterprise.sh` — one-command demo
- **Pilot Guide**: `.docs/product/06-pilot.md` — prerequisites, success criteria
- **CI Dry-Run Gate**: benchmark dry-run validation in `brain-release.yml`

### Changed
- CI workflows: SHA-pinned actions (4 across 3 workflows), concurrency guards
- `.mcp.json` excluded from release bundles (contains resolved secrets)
- `upload.sh` / `settings.json` untracked (contained live API keys)
- API keys migrated from hardcoded to `getenv()` in MCP classes
- MCP path generator emits `getcwd()` instead of hardcoded paths
- All 9 VarExporter catch blocks: observable `logDegradation()` (env-gated `BRAIN_COMPILE_DEBUG`)
- Documentation: 60/60 files pass `brain docs --validate`
- `build-release-bundle.sh`: demo scripts, scenarios, ops-evidence in bundle
- `baselines.json`: 6→7 adversarial scenarios (+ADV-007)
- `declare(strict_types=1)` enforced in 167/167 PHP files

### Fixed
- `CompileStandartsTrait.php` typo → `CompileStandardsTrait.php`
- `HelloScript.php` dead scaffold removed
- Debug artifacts (`dd()`, `dump()`) removed from production code
- `self::callJson()` LSB → `static::callJson()` in McpSchemaTrait
- `fakerphp/faker` moved from production to dev dependency (CLI)
- LegacyParityTest false reference removed from CLAUDE.md
- Merger stale-index bug: `array_splice` index rebuilt after splice
- MergerTest: protected `handle()` via Reflection
- TomlBuilderTest: stale `.build()` chain removed

### Security
- Secret scanning CI gate (blocking)
- Secret patterns blocked in tracked files (audit Check 14)
- Degradation observability in all catch blocks (audit Check 16)
- CI concurrency guards prevent parallel-run race conditions

## [v0.1.1] — 2026-02-20

### Added — Enterprise Hardening
- **Release CI Gate**: `brain-release.yml` workflow on `v*` tag push — pin verification (strict), manifest generation, bundle build, artifact upload
- **Release Bundle**: `scripts/build-release-bundle.sh` produces `dist/brain-enterprise-vX.Y.Z.tar.gz` + `.sha256`
- **LICENSE**: MIT license file (matches `composer.json` declaration)
- **SECURITY.md**: vulnerability reporting policy with response timeline and scope
- **SUPPORT.md**: support workflow with documentation reference and bug report template

### Changed
- **RELEASE.md**: pin verification step is now mandatory for all releases (was optional), added release bundle step, annotated tags
- **Version Bump**: `v0.1.0` → `v0.1.1`

## [v0.1.0] — 2026-02-20

### Added — Productization v1
- **Operator Contract**: 6 product docs in `.docs/product/` (overview, installation, configuration, runbooks, security model, support)
- **Dependency Pinning**: `pins.json` for MCP version control, compile-time pin resolution in CLI, `PIN_STRICT` env var
- **Pin Verification**: `scripts/verify-pins.sh` validates `.mcp.json` against `pins.json`
- **Build Manifest**: `scripts/generate-manifest.sh` generates reproducible `.docs/releases/manifest.json`
- **CI Gate**: pin policy verification step in `brain-lint.yml`
- **Release Guide**: `RELEASE.md` with step-by-step release checklist
- **Version Bump**: project version `v0.0.1` → `v0.1.0`

### Added — Benchmark Suite v2
- **32 scenarios** across 7 difficulty categories (L1, L2, L3, ST, MT, ADV, S0)
- **Multi-turn session benchmarks** (MT-001, MT-002, MT-003) with `--resume` and sessionId from Init DTO
- **Telemetry-first tool verification** via ToolUse DTOs (`expected_tools` check type)
- **Matrix Stress Harness**: 4 configs (standard/paranoid x standard/exhaustive) x stress subset
- **Adversarial Pack v1**: 5 scenarios (hallucinated MCP key, hallucinated method, runtime cookbook params, prompt injection, lost-in-middle noise)
- **Regression gate** with `baselines.json` and 20% threshold checks
- **7 profiles**: smoke, ci, telemetry-ci, full, matrix, adversarial-matrix
- **CI pipeline**: smoke -> PR gate (telemetry-ci + ci) -> nightly (full + matrix + adversarial)
- Composer aliases: `benchmark:ci`, `benchmark:telemetry`, `benchmark:matrix`, `benchmark:adversarial`, `benchmark:mt`, `benchmark:smoke`, `benchmark:dry`, `benchmark:regression`

### Added — Enterprise Release Pack v1
- `README_ENTERPRISE.md` with 12 invariants, quickstart, pipeline diagram, cost estimates
- Reproducible proof via MT-001 and MT-002 multi-turn scenarios

### Fixed
- `ProcessTrait` type bug: `Type::RUN` hardcoded -> `$type` parameter (correct Init DTO processType for RESUME/CONTINUE)
