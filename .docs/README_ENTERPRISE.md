---
name: "Enterprise Release Pack v1"
description: "Enterprise invariants, quickstart, pipeline overview, and reproducible proof for Brain Benchmark Suite"
---

# Enterprise Release Pack v1

## Invariants

These 12 properties hold across every release. CI enforces them automatically.

| # | Invariant | Enforcement |
|---|-----------|-------------|
| 1 | **Schema-enforced scenarios** | `--dry-run` validates all JSON scenario files before any AI call |
| 2 | **Deterministic compilation** | `brain compile` produces identical output for same source + mode |
| 3 | **Lint gate** | `composer analyse` (PHPSTAN) + `composer test` (PHPUnit) must pass |
| 4 | **Governance rules** | Iron rules compiled into Brain artifacts; banned patterns checked per scenario |
| 5 | **Single-mode invariant** | `no-mode-self-switch` (CRITICAL): mode is compile-time only, no runtime changes |
| 6 | **CI PR gate** | PR gate runs dry-run schema validation (zero API cost) + brain-lint (tests, phpstan, audit, secrets) |
| 7 | **Nightly benchmarks** | Nightly-live profile (8 scenarios) with sonnet + matrix stress + adversarial matrix |
| 8 | **Matrix stress** | 4 configs (standard/paranoid × standard/exhaustive) × 4 stress scenarios nightly |
| 9 | **Adversarial robustness** | 7 ADV scenarios test hallucination, injection, noise resistance across configs |
| 10 | **Regression baselines** | Budget ceilings (tokens, duration, MCP calls) with 20% threshold per profile |
| 11 | **Telemetry-first validation** | ToolUse DTOs as primary MCP verification signal, not grep on response text |
| 12 | **Multi-turn session integrity** | `--resume` with sessionId from Init DTO, context preserved across turns |

## Quickstart

```bash
# Compile (standard mode)
brain compile

# Compile (paranoid mode)
STRICT_MODE=paranoid brain compile

# Dry-run: validate all 38 scenarios (full profile)
composer benchmark:dry

# Telemetry-CI (12 scenarios, haiku)
composer benchmark:telemetry

# CI profile (25 scenarios, haiku)
composer benchmark:ci

# Full profile (38 scenarios, sonnet)
composer benchmark

# Matrix stress (4 configs × 4 scenarios, haiku)
composer benchmark:matrix

# Adversarial matrix (4 configs × 7 scenarios, haiku)
composer benchmark:adversarial

# Single scenario
bash scripts/benchmark-llm-suite.sh --scenario MT-001 --model haiku

# Regression check
composer benchmark:regression benchmark-report.json
```

## Pipeline

```
.brain/node/*.php
       |
       v
  brain compile (standard | paranoid)
       |
       v
.claude/CLAUDE.md + agents/ + skills/ + commands/ + .mcp.json
       |
       v
  Benchmark Suite (scripts/benchmark-llm-suite.sh)
       |
       +-- Smoke (1 scenario, S00)
       +-- Telemetry-CI (12 scenarios, S00+L1+L2+ST+MT+MT-LP)
       +-- CI (25 scenarios, CMD+L1+L2+ST)
       +-- Full (38 scenarios, CMD+L1+L2+L3+ST+MT+MT-LP)
       +-- Cmd-auto (28 scenarios, auto-generated)
       +-- Nightly-live (8 scenarios, live proof set)
       +-- Matrix Stress (4 configs × 4 scenarios)
       +-- Adversarial Matrix (4 configs × 7 scenarios)
       |
       v
  Regression Gate (baselines.json, 20% threshold)
       |
       v
  CI Pipeline
       +-- PR: dry-run validation (zero API cost)
       +-- Nightly: smoke → nightly-live (sonnet) + matrix (haiku) + adversarial (haiku)
       +-- Manual: any profile via workflow_dispatch
```

## Scenario Coverage

| Category | Count | IDs | Profile |
|----------|-------|-----|---------|
| Command core | 6 | CMD-001..CMD-006 | telemetry-ci, ci, full |
| Knowledge L1 | 7 | L1-001..L1-007 | ci, full |
| Knowledge L2 | 7 | L2-001..L2-007 | ci, full |
| Governance L3 | 7 | L3-001..L3-007 | full |
| Single-turn telemetry | 5 | ST-001..ST-005 | ci, full |
| Multi-turn sessions | 3 | MT-001..MT-003 | telemetry-ci, full |
| Multi-turn learn protocol | 3 | MT-LP-001..MT-LP-003 | telemetry-ci, full |
| Adversarial | 7 | ADV-001..ADV-007 | adversarial-matrix |
| Command auto | 28 | CMD-AUTO-* | cmd-auto |
| Smoke | 1 | S00-000 | smoke, telemetry-ci |
| **Total unique** | **74** | | |

## Demo: Reproducible Proof

Two multi-turn scenarios serve as reproducible proof of session integrity:

**MT-001 — Memory: store -> search -> verify**
- Turn 1: Store a fact in vector memory (tag: benchmark-test)
- Turn 2: Resume session, search for the stored fact, verify retrieval
- Validates: Init DTO sessionId extraction, `--resume` session continuity, MCP tool execution

**MT-002 — Task: create -> list -> validate**
- Turn 1: Create a test task via vector-task MCP
- Turn 2: Resume session, list tasks, confirm the created task appears
- Validates: Same session mechanics + cross-turn data persistence

Run locally:
```bash
bash scripts/benchmark-llm-suite.sh --scenario MT-001 --model haiku --yolo
bash scripts/benchmark-llm-suite.sh --scenario MT-002 --model haiku --yolo
```

## Cost Estimates (haiku)

| Profile | Scenarios | Est. tokens | Est. time | Est. cost |
|---------|-----------|-------------|-----------|-----------|
| smoke | 1 | ~400 | ~20s | ~$0.001 |
| telemetry-ci | 12 | ~11,000 | ~3 min | ~$0.01 |
| ci | 25 | ~22,000 | ~7 min | ~$0.03 |
| full | 38 | ~50,000 | ~15 min | ~$0.06 |
| cmd-auto | 28 | ~34,000 | ~10 min | ~$0.04 |
| nightly-live | 8 | ~15,000 | ~10 min | ~$0.02 |
| matrix | 16 runs | ~12,000 | ~6 min | ~$0.03 |
| adversarial-matrix | 28 runs | ~14,000 | ~7 min | ~$0.03 |
