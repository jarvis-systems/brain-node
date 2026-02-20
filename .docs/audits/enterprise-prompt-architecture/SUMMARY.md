# Enterprise Prompt Architecture — Checkpoint Summary

---
date: "2026-02-20"
version: "1.0.0"
status: "checkpoint"
---

## Current Baseline

The Brain prompt compilation system has undergone three optimization phases:

1. **C2 MCP Migration** — 209+ legacy pseudo-JSON calls eliminated, 100% schema-validated MCP
2. **Phase 1: Deep-Cognitive Gating** — Reference-heavy Brain includes gated via `isDeepCognitive()`
3. **Phase 1b: Sequential Reasoning Gating** — Phase detail guidelines gated in universal agent include
4. **Cookbook Governance Policy** — Compile-time-only cookbook, banned uncertainty triggers

## What Changed and Why

### Rationale: Lost-in-the-Middle + Cognitive Overload

Research shows models degrade on long prompts when critical instructions sit in the middle. Reference-heavy guidelines (authority levels, delegation types, workflow phases, error playbooks, validation thresholds, reasoning phase details) contribute to cognitive overload in standard operations without proportional benefit.

**Approach**: Gate verbose reference material behind `isDeepCognitive()` at compile time. Keep operational summaries always-on. Zero runtime branching — model sees only one baked configuration.

### Changes Applied

| Phase | Target | Technique | Lines Saved |
|-------|--------|-----------|-------------|
| Phase 1 | DelegationProtocolsInclude | Gate 14 guidelines (levels, types, workflows) | ~80 in Brain |
| Phase 1 | ResponseValidationInclude | Early return in standard (4 guidelines) | ~20 in Brain |
| Phase 1 | ErrorHandlingInclude | Gate 5 error guidelines | ~30 in Brain |
| Phase 1b | SequentialReasoningInclude | Gate 4 phase details, keep phase-flow | 160 across 5 agents |
| Cookbook | VectorTaskInclude + VectorMemoryInclude | +1 rule, +2 guidelines each | +25 in Brain (policy) |

## Final Metrics

### Brain (CLAUDE.md)

| Mode | Lines | vs Original (489) |
|------|-------|--------------------|
| standard/standard | **362** | -127 (-26%) |
| paranoid/exhaustive | **756** | +267 (policy + full reference) |

### Agents (compiled, standard mode)

| Agent | Before | After | Delta |
|-------|--------|-------|-------|
| commit-master | 342 | 310 | -32 |
| documentation-master | 307 | 275 | -32 |
| explore | 350 | 318 | -32 |
| vector-master | 279 | 247 | -32 |
| web-research-master | 372 | 340 | -32 |
| **Total** | **1650** | **1490** | **-160** |

### Verification

| Check | Result |
|-------|--------|
| verify-compile-metrics.sh | 15/15 PASS |
| lint-mcp-syntax.sh | PASSED (67 files) |
| McpSchemaValidatorTest | OK (10 tests, 16 assertions) |
| Mode leakage (standard) | 0 gated content found |
| Uncertainty triggers | 0 in both modes |
