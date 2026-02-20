---
name: "Phase 2: WebRecursiveResearchInclude Gating — PLAN"
description: "Implementation plan for Phase 2 WebRecursiveResearchInclude gating"
date: "2026-02-20"
---

# Phase 2: WebRecursiveResearchInclude Gating — PLAN

## Candidate Selection

| Candidate | Agents | Lines gateable | Total ROI |
|-----------|--------|----------------|-----------|
| BrainScriptsInclude | 0 (commented out in BrainIncludesTrait + SystemMaster only = no .claude/ output) | 0 | **ZERO** |
| WebRecursiveResearchInclude | 1 (web-research-master) | ~58 | **-58 lines** |

**Decision**: WebRecursiveResearchInclude. Only viable candidate.

## Gating Strategy

**Always-on** (operational constraints):
- New `research-workflow` compact summary (flow + limits + abort condition) — 5 lines
- `source-priority` — 6 lines (source selection order, required for quality)
- 3 rules (`recursion-limit`, `source-citation`, `no-speculation`) — 13 lines

**Deep-only** (detailed step-by-step phases):
- `phase-query` + `limits-query` — 11 lines
- `phase-evaluation` — 6 lines
- `phase-fetch` + `limits-fetch` — 11 lines
- `phase-recursion` + `limits-recursion` — 12 lines
- `phase-aggregation` — 7 lines
- `phase-output` — 7 lines

## Rationale

The 6 research phases are reference material for step-by-step execution. The compact `research-workflow` summary provides the same execution flow + all numeric limits in 5 lines. Standard mode retains: workflow order, all limits, source priority, and all 3 safety rules.
