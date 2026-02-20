---
name: "Benchmark v2 Plan"
description: "Why v2: multi-turn sessions, telemetry-primary validation, workflow correctness"
type: "plan"
date: "2026-02-20"
version: "2.0"
---

# Benchmark v2 — Multi-turn + Workflow Correctness

## Motivation

v1 delivered 22 single-turn scenarios with grep-based checks. Limitations:

1. **Single-turn only** — cannot test multi-step workflows (store → search, create → list)
2. **Grep-primary** — MCP tool invocation validated by response text, not actual telemetry
3. **No session continuity** — cannot verify governance holds across conversation turns

## What v2 Adds

### Multi-turn scenarios (MT-*)
- Session resume via `--resume <sessionId>` extracted from Init DTO
- Per-turn checks: required_patterns, banned_patterns, expected_mcp_calls, expected_tools
- Scenario-level aggregation: total tokens, total MCP calls, global banned patterns

### Telemetry-primary validation
- `expected_tools` check type: validates exact tool names from ToolUse DTOs
- L2-001/L2-002 tightened: `expected_mcp_calls.min` 0 → 1
- ST-001: forces specific MCP call, validated via telemetry

### Workflow correctness
- MT-001: Memory store → search → verify retrieval
- MT-002: Task create → list → validate fields
- MT-003: Governance continuity across 3 turns (cookbook limits)

## Scope

- 6 new scenarios (3 MT + 3 ST)
- Runner extended: `parse_cli_output()` + init DTO, `expected_tools`, `run_multi_turn_scenario()`
- Profile filters updated for MT/ST inclusion
- ProcessTrait CLI bug fix (Type::RUN → $type)

## Non-goals

- Agent-to-agent delegation testing (requires different infrastructure)
- Subjective response quality evaluation
- Automated cleanup of MT side effects (tagged for manual cleanup)
