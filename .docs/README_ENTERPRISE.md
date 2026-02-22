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
| 9 | **Adversarial robustness** | 9 ADV scenarios test hallucination, injection, noise resistance across configs |
| 10 | **Regression baselines** | Budget ceilings (tokens, duration, MCP calls) with 20% threshold per profile |
| 11 | **Telemetry-first validation** | ToolUse DTOs as primary MCP verification signal, not grep on response text |
| 12 | **Multi-turn session integrity** | `--resume` with sessionId from Init DTO, context preserved across turns |

## Quickstart

```bash
# Compile (standard mode)
brain compile

# Compile (paranoid mode)
STRICT_MODE=paranoid brain compile

# Dry-run: validate all 42 scenarios (full profile)
composer benchmark:dry

# Telemetry-CI (12 scenarios, haiku)
composer benchmark:telemetry

# CI profile (26 scenarios, haiku)
composer benchmark:ci

# Full profile (42 scenarios, sonnet)
composer benchmark

# Matrix stress (4 configs × 4 scenarios, haiku)
composer benchmark:matrix

# Adversarial matrix (4 configs × 9 scenarios, haiku)
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
       +-- CI (26 scenarios, CMD+L1+L2+ST)
       +-- Full (42 scenarios, CMD+L1+L2+L3+ST+MT+MT-LP)
       +-- Cmd-auto (28 scenarios, auto-generated)
       +-- Nightly-live (8 scenarios, live proof set)
       +-- Matrix Stress (4 configs × 4 scenarios)
       +-- Adversarial Matrix (4 configs × 9 scenarios)
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
| Governance L3 | 8 | L3-001..L3-008 | full |
| Single-turn telemetry | 6 | ST-001..ST-006 | ci, full |
| Multi-turn sessions | 4 | MT-001..MT-004 | telemetry-ci, full |
| Multi-turn learn protocol | 4 | MT-LP-001-KNOWLEDGE..MT-LP-003 | telemetry-ci, full |
| Adversarial | 9 | ADV-001..ADV-009 | adversarial-matrix |
| Command auto | 28 | CMD-AUTO-* | cmd-auto |
| Smoke | 1 | S00-000 | smoke, telemetry-ci |
| **Total unique** | **80** | | |

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

**Full gate demo (2-3 min, all gates):** see `.docs/product/18-enterprise-demo-script.md`.

## Repo Topology

This project consists of three independent git repositories co-located on disk (not a monorepo). See `.docs/architecture/repo-topology.md` for the full topology diagram, operator cookbook, and agent guardrails.

## Release State

- **Release capsule (frozen):** `.docs/product/22-release-capsule-v0.2.0.md` — tag-time invariant, reproduce commands, known dev deltas
- **Full gate evidence:** `.docs/product/21-release-readiness-pack.md` — repo-scoped counters, audit detail
- **Pre-publication runbook:** `.docs/product/10-pre-publication.md` — GO PRE-PUB version alignment procedure

## Cost Estimates (haiku)

| Profile | Scenarios | Est. tokens | Est. time | Est. cost |
|---------|-----------|-------------|-----------|-----------|
| smoke | 1 | ~400 | ~20s | ~$0.001 |
| telemetry-ci | 12 | ~11,000 | ~3 min | ~$0.01 |
| ci | 26 | ~23,000 | ~7 min | ~$0.03 |
| full | 42 | ~52,000 | ~15 min | ~$0.06 |
| cmd-auto | 28 | ~34,000 | ~10 min | ~$0.04 |
| nightly-live | 8 | ~15,000 | ~10 min | ~$0.02 |
| matrix | 16 runs | ~12,000 | ~6 min | ~$0.03 |
| adversarial-matrix | 36 runs | ~18,000 | ~9 min | ~$0.04 |
