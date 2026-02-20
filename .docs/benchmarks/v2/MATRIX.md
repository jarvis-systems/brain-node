---
name: "Matrix Stress Harness"
description: "Enterprise matrix testing across mode/cognitive configurations for governance and budget validation"
---

# Matrix Stress Harness

## Why Matrix Exists

Standard benchmarks run under a single `standard/standard` configuration. But Brain compiles differently under different modes:

- **standard** mode: baseline rules, normal cognitive depth
- **paranoid** mode: stricter governance, elevated constraints
- **exhaustive** cognitive: deeper reasoning chains, more tokens

A single-config pass proves nothing about cross-mode stability. Matrix stress validates:

1. Governance rules hold across ALL mode/cognitive combinations
2. Token budgets don't blow up under exhaustive cognitive depth
3. MCP tool execution works regardless of mode
4. Multi-turn sessions maintain integrity across configs

## Configurations

| # | STRICT_MODE | COGNITIVE_LEVEL | Purpose |
|---|-------------|-----------------|---------|
| 1 | standard | standard | Baseline behavior |
| 2 | standard | exhaustive | Token budget stress |
| 3 | paranoid | standard | Governance strictness |
| 4 | paranoid | exhaustive | Maximum stress (both axes) |

Environment variables per config:
- `STRICT_MODE` — passed to Brain CLI subprocess
- `COGNITIVE_LEVEL` — passed to Brain CLI subprocess

## Stress Subset

Only high-value scenarios run in matrix mode (cost control):

| ID | Type | Turns | Why |
|----|------|-------|-----|
| MT-001 | multi-turn | 2 | Memory store + search with session resume |
| MT-002 | multi-turn | 2 | Task create + list with session resume |
| MT-003 | multi-turn | 3 | Governance continuity across turns (L3) |
| ST-001 | single-turn | 1 | Forced MCP call with telemetry verification |

Total: 4 scenarios x 4 configs = 16 runs per matrix execution.

Stress scenarios are configured in `baselines.json` under `profiles.matrix.stress_scenarios`.

## Checks (Telemetry-First)

Per config, all existing scenario checks apply:

- **Governance**: global banned patterns = 0 matches across all scenarios
- **Tool telemetry**: ST-001 must show `mcp__vector-memory__search_memories` in ToolUse DTOs
- **MCP ranges**: MT-001/MT-002 scenario-level `expected_mcp_calls.min >= 2`
- **Session integrity**: MT-* scenarios must extract valid sessionId from Init DTO
- **Token budget**: per-scenario `max_output_tokens` enforced
- **Cost guard**: per-config total checked against baselines via regression check (`--strict`)

## Cost Control Strategy

Each config has budget baselines in `baselines.json` under `profiles.matrix`:

| Metric | Baseline | Hard Cap (x1.2) |
|--------|----------|-----------------|
| Output tokens | 6,000 | 7,200 |
| Duration | 480s (8 min) | 576s (9.6 min) |
| MCP calls | 15 | 18 |

If any config exceeds its hard cap: marked `FAIL:regression` via `benchmark-regression-check.sh --strict`.

### Cost Estimates

| Model | Est. tokens/config | Est. time/config | Full matrix |
|-------|-------------------|------------------|-------------|
| haiku | ~3,000 | ~90s | ~12,000 tokens, ~6 min |
| sonnet | ~5,000 | ~120s | ~20,000 tokens, ~8 min |

Haiku matrix: ~$0.03 per run. Sonnet matrix: ~$0.15 per run.

## Usage

```bash
# Dry-run (validate scenario schemas)
bash scripts/benchmark-llm-suite.sh --matrix --dry-run --json

# Matrix run with haiku
bash scripts/benchmark-llm-suite.sh --matrix --json --model haiku --yolo

# Matrix run with sonnet
bash scripts/benchmark-llm-suite.sh --matrix --json --model sonnet --yolo

# Composer alias
composer benchmark:matrix
```

## JSON Output Schema

```json
{
  "matrix": true,
  "model": "haiku",
  "dry_run": false,
  "stress_scenarios": ["MT-001", "MT-002", "MT-003", "ST-001"],
  "configs": [
    {
      "mode": "standard",
      "cognitive": "standard",
      "total": 4,
      "passed": 4,
      "failed": 0,
      "errors": 0,
      "pass_rate": "100.0%",
      "total_input_tokens": 30,
      "total_output_tokens": 2500,
      "total_duration_ms": 90000,
      "total_mcp_calls": 5,
      "budget_status": "OK",
      "scenarios": [...]
    }
  ],
  "summary": {
    "total_configs": 4,
    "configs_passed": 4,
    "total_scenarios": 16,
    "total_passed": 16,
    "total_failed": 0,
    "total_errors": 0,
    "total_input_tokens": 120,
    "total_output_tokens": 10000,
    "total_duration_ms": 360000,
    "total_mcp_calls": 20
  }
}
```

## CI Integration

- **PR gate**: unchanged (telemetry-ci + ci in standard/standard)
- **Nightly**: matrix stress with haiku (automatic)
- **Manual**: matrix stress with haiku or sonnet (workflow_dispatch with profile=matrix)
