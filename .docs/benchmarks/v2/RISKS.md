---
name: "Benchmark v2 Risks"
description: "Risk analysis and mitigation strategies for multi-turn and telemetry benchmarks"
type: "risk-analysis"
date: "2026-02-20"
version: "2.0"
---

# Risk Analysis

## Non-determinism

AI responses vary between runs. Multi-turn amplifies this: turn 2 depends on turn 1 output.

**Mitigation**: Broad pattern alternatives via `|`, simple recall tasks (store/search), well-defined governance policies with clear yes/no answers.

## Session expiry

Claude sessions may expire between turns if processing takes too long.

**Mitigation**: Per-scenario `timeout_s` limits total duration. Turns execute sequentially within one script invocation. Session expiry would cause `session-init` check to fail clearly.

## MCP unavailability

Vector memory or vector task MCP servers may be down during benchmark runs.

**Mitigation**: MT-003 (governance) requires 0 MCP calls. MT-001/MT-002 fail clearly with `mcp-range` check if MCP unavailable. ST-001 `expected_tools` check catches missing MCP calls explicitly.

## Side effects

MT-001 stores data in vector memory. MT-002 creates tasks in vector-task. These persist after benchmark runs.

**Mitigation**: All benchmark data tagged with `benchmark-test` for optional cleanup. Side effects are read-only safe (no destructive operations). Manual cleanup: search by tag and delete.

## ProcessTrait type bug

Init DTO's `processType` was hardcoded to `RUN`, ignoring actual type parameter.

**Mitigation**: One-line fix (`Type::RUN` → `$type`). Low risk, improves correctness for resume/continue operations.

## Profile count mismatches

Adding ST/MT scenarios changes profile counts. CI consumers may have hardcoded expectations.

**Mitigation**: CI profile explicitly excludes MT (via `case MT-*) continue`). telemetry-ci includes MT-001/MT-002 by explicit ID. Smoke profile unchanged (S0 only).

## Cost increase

6 new scenarios increase full suite cost. Multi-turn scenarios cost ~2x per scenario (2-3 API calls).

**Mitigation**: telemetry-ci profile caps at 9 scenarios. CI excludes MT. Use `--model haiku` for routine runs. Reserve `--model sonnet` for validation.
