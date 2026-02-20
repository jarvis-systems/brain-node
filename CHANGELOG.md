---
name: "Changelog"
description: "Release changelog for jarvis-brain/node"
---

# Changelog

## [Unreleased] — 2026-02-20

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
