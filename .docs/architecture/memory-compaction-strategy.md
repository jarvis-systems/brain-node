---
name: "Memory Compaction Strategy"
description: "Actionable patterns for memory management, context compaction survival, and vector memory hygiene in Brain orchestration"
type: architecture
date: 2026-02-22
version: "1.0"
status: active
---

# Memory Compaction Strategy

Actionable patterns extracted from deep research on LLM context compaction, mapped to Brain's architecture.

## 1. Patterns Overview

| # | Pattern | Status | Summary |
|---|---------|--------|---------|
| 1 | Memory Ledger | Partially present | Structured in-context block surviving compaction with CORE/DECISIONS/STATE/TASKS |
| 2 | Type-Based Classification | Partially present | Information typed by role (CORE/DECISION/STATE/NOISE) for compression priority |
| 3 | No DROP Semantics | Already have | Never auto-delete; priority-based compression only |
| 4 | Evidence Pointers | Missing | Store file:line refs instead of copying content; prevents fact corruption |
| 5 | Hierarchical Memory (RAM+Disk) | Already have | In-context = RAM, vector memory = disk, MCP = paging |
| 6 | Structured Memory Ops | Already have | search-before-store, multi-probe, MCP-only access |
| 7 | Post-Compaction Recovery | Already have | Untrust all prior state, re-verify from canonical sources |
| 8 | External Compression | Not applicable | No integration point in Claude Code runtime |
| 9 | Compaction Benchmark | Missing | No test suite for compaction survival verification |

## 2. Recommendations

### Adopt Now

1. **Evidence pointer format** — Add `evidence` tag to memory taxonomy. Entries referencing code MUST include file path + line/method or git SHA. Prevents fact corruption during compression.

2. **Post-compaction recovery specifics** — Concretize the existing `error-context-loss` guideline: query `architecture` and `project-context` categories first, minimum 2 probes, verify git status before resuming.

3. **In-context priority tiers** — Define 3 compression tiers: TIER-1 (iron rules, active task, decisions — never compress), TIER-2 (evidence, constraints — conservative), TIER-3 (conversation logs, exploration — aggressive).

### Experiment

| Item | Success Metric |
|------|---------------|
| Memory Ledger Block | After compaction, agent answers 5 predefined questions about session state with 80%+ accuracy |
| Semantic dedup (cosine >0.85 → update) | Memory stabilizes at ~150 records without losing unique insights |
| Compaction survival smoke test | 90% of critical facts recoverable from vector memory alone |

### Reject

| Item | Rationale |
|------|-----------|
| External prompt compression (LLMLingua-2) | No hook for custom prompt preprocessing in Claude Code |
| Auto-delete memories | Violates conservative memory philosophy; manual cleanup is correct granularity |
| Zettelkasten graph links | Overkill for ~200 records; semantic search provides adequate recall at this scale |

## 3. Current System Mapping

| Component | Location | Role |
|-----------|----------|------|
| Memory tag taxonomy | `core/src/Includes/Commands/SharedCommandTrait.php` | Categories + content/scope tags |
| Vector memory rules | `core/src/Includes/Universal/VectorMemoryInclude.php` | Iron rules (search-before-store, multi-probe) |
| Context-loss recovery | `core/src/Includes/Brain/ErrorHandlingInclude.php` | error-context-loss guideline |
| Pre-action validation | `core/src/Includes/Brain/PreActionValidationInclude.php` | Compaction stability check |
| Model 2 compaction | `.docs/product/15-model2-operating-contract.md` §6 | Post-compaction untrust rule |
| Dense storage format | `core/src/Includes/Commands/InitVectorInclude.php` | Manual compression at storage time |

## 4. Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| No evidence pointer standard | Fact corruption during compression | High |
| No in-context type annotation | Compactor treats all history equally | Medium |
| No compaction survival benchmark | Cannot measure improvement | Medium |
| No explicit "load into context" policy | Suboptimal memory-to-context paging | Low |
