---
name: "Enterprise Prompt Architecture Audit"
description: "Reproducible verification of compile-time deep-cognitive gating and cookbook governance"
type: "audit"
date: "2026-02-20"
---

# Enterprise Prompt Architecture Audit

Reproducible verification of compile-time deep-cognitive gating and cookbook governance policy.

## Quick Verification

```bash
# Full automated check (15 checks, both modes, restores standard)
bash scripts/verify-compile-metrics.sh

# MCP syntax lint (67 compiled files)
bash scripts/lint-mcp-syntax.sh

# Schema validator tests
cd core && ./vendor/bin/phpunit tests/McpSchemaValidatorTest.php
```

## Audit Documents

- `SUMMARY.md` — Baseline metrics, changes, rationale
- `DIFFS.md` — Modified files with change intent
- `VERIFICATION.md` — Full manual verification commands with expected outputs
- `RISKS.md` — Residual risk registry with mitigations

## Phase Closure: Enterprise Prompt Architecture v1

### What Changed

- Deep-cognitive gating: compile-time `gate_mode` variable with standard/exhaustive compilation modes
- Cookbook governance: 4-pull/session budget, compile-time presets baked into Brain context, speculative pulls banned
- Iron rules for vector-memory and vector-task: search-before-store, multi-probe-mandatory, parent-readonly, timestamps-auto
- BrainDocsInclude: 2 new iron rules (yaml-front-matter CRITICAL, validate-before-commit HIGH)
- All 36 .docs/ files validated with YAML front matter — 0 errors, 0 warnings
- LLM Benchmark Suite: 21 behavioral scenarios (L1-L3), bash runner, JSON reports
- S00 live smoke scenario for pipeline health check
- ToolUse DTO pipeline in CLI: full tool_use telemetry from Claude API responses
- CI workflow: nightly benchmarks via GitHub Actions (smoke + full profiles)
- Composer benchmark aliases: `benchmark`, `benchmark:ci`, `benchmark:dry`, `benchmark:smoke`

### How to Verify

```bash
# 1. Compile both modes — must succeed
brain compile
GATE_MODE=exhaustive brain compile

# 2. Docs validation — 0 errors, 0 warnings
brain docs --validate

# 3. Benchmark dry-run — all 21 scenarios validate
bash scripts/benchmark-llm-suite.sh --dry-run --json

# 4. Smoke test (requires ANTHROPIC_API_KEY + claude)
composer benchmark:smoke

# 5. MCP syntax lint
bash scripts/lint-mcp-syntax.sh

# 6. Core tests
cd core && ./vendor/bin/phpunit tests/McpSchemaValidatorTest.php
```

### Budgets Enforced

| Budget | Limit | Scope |
|--------|-------|-------|
| Cookbook pulls | 4/session | Compile-time preset satisfies Gate-5; extra pulls only for explicit onViolation |
| Memory searches | 3/operation | Brain-level vector-memory limit |
| Delegation depth | 2 levels | Brain → Architect → Specialist |
| Token usage gate | < 90% | Pre-action validation blocks at 90% |
| Max response tokens | 1200 | Brain constraint |
| Max execution time | 60s | Brain constraint |

## Metrics Snapshot (2026-02-20)

| Artifact | standard | exhaustive |
|----------|----------|------------|
| CLAUDE.md | 362 | 756 |
| Agents total | 1490 | 1790 |
