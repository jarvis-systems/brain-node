---
name: "Changelog"
description: "Release changelog for jarvis-brain/node"
---

# Changelog

## [Unreleased]

### Added — Sales Demo + Pilot Pack
- **Enterprise Demo**: `scripts/demo-enterprise.sh` — one-command demo running MT-001, MT-002, ADV-003 with consolidated `dist/demo-report.json`
- **Pilot Guide**: `.docs/product/06-pilot.md` — prerequisites, bundle usage, success criteria, support artifacts
- **Composer Alias**: `demo:enterprise` for quick demo execution
- **Release Bundle**: demo script, benchmark runner, and demo scenarios now included in enterprise bundle
- **CI Dry-Run Gate**: benchmark dry-run validation step added to `brain-release.yml`

### Changed
- **00-overview.md**: added pilot deployment reference
- **build-release-bundle.sh**: includes demo-relevant scripts and scenario files

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
