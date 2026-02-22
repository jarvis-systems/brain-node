---
name: "Memory Hygiene Runbook"
description: "Operational procedure for vector memory health: ledger snapshots, compaction survival smoke tests, and semantic dedup policy"
type: runbook
date: 2026-02-22
version: "1.2.0"
status: active
---

# Memory Hygiene Runbook

## Principle

Vector memory is the inter-session knowledge bus. Without hygiene, retrieval degrades silently — context compaction drops critical invariants, semantic drift buries operational knowledge under implementation details, and stale memories pollute search results.

## Artifacts

| File | Purpose |
|------|---------|
| `.work/memory-hygiene/ledger.json` | Snapshot of memory state (counts, categories, tags, top accessed) |
| `.work/memory-hygiene/probe-set.json` | 15 probes defining critical retrieval invariants |
| `.work/memory-hygiene/smoke-results.json` | Last smoke test results with gap analysis |

## When to Run

- After any `mem:cleanup` or bulk memory operation
- Before starting a new roadmap (baseline capture)
- After context compaction if retrieval feels degraded
- Monthly as routine health check

## Procedure

### Step 1: Capture Ledger

Run inside Claude Code session:

```
mcp__vector-memory__get_memory_stats()
mcp__vector-memory__get_unique_tags()
mcp__vector-memory__list_recent_memories(limit=10)
```

Update `.work/memory-hygiene/ledger.json` with current counts.

### Step 2: Run Smoke Test

Execute all 15 probes from `probe-set.json` via `mcp__vector-memory__search_memories(query=..., limit=3)`.

For each probe, evaluate:
1. Is the top result **semantically relevant** to the expected concept?
2. Is `similarity >= 0.40`?
3. Mark PASS or FAIL

### Step 3: Score and Act

| Pass Rate | Action |
|-----------|--------|
| >= 12/15 (80%) | HEALTHY. No action needed. |
| 9-11/15 (60-73%) | WARNING. Store missing invariants. Review failed probes. |
| < 9/15 (< 60%) | CRITICAL. Immediate remediation: store operational invariants, consider re-seeding. |

### Step 4: Remediate Gaps

For each FAIL probe:
1. Check if the knowledge exists in memory but query doesn't match (retrieval failure)
2. If knowledge missing: store a focused memory covering the expected concept
3. If retrieval failure: consider re-storing with better keywords/tags

### Step 5: Update Results

Write results to `.work/memory-hygiene/smoke-results.json`.

### Step 6: Rank Safety Check (Post-Consolidation Gate)

**When:** After ANY topic consolidation (storing new canonical memories). Run BEFORE declaring consolidation success.

**Purpose:** Verify new canonicals do not outrank critical anchors or expected top-1 memories for sensitive probes. Catches embedding overlap — the primary risk when storing consolidated content.

**Scope:** 7 critical probes + sensitive non-critical probes (P04, P11, P12 minimum).

**Procedure:**

1. For each probe in scope, run `search_memories(query=..., limit=5)`
2. Record top-5 results with IDs and similarity scores
3. Check each probe:
   - Is the expected anchor/memory at position 1?
   - Does any new canonical appear in top-5?
   - If a canonical appears: calculate `anchor_similarity - canonical_similarity` = margin
4. Apply overlap threshold (default: 0.01):

| Margin | Verdict | Action |
|--------|---------|--------|
| > 0.01 | SAFE | No action needed |
| <= 0.01 and > 0 | OVERLAP_RISK | Flag for review. Recommend: add keyword to anchor OR update probe expectations |
| <= 0 (canonical outranks) | OVERLAP_FAIL | Immediate rollback of offending canonical. Defer cluster. |

5. Write results to `.work/memory-hygiene/rank-safety-results.json`

**Acceptance criteria:**
- All 7 critical probes: expected memory at position 1
- Zero OVERLAP_FAIL results
- Any OVERLAP_RISK documented with actionable mitigation

**Key finding (Batch 2B.1):** MiniLM-L6-v2 embedding space has tight semantic neighborhoods. Adjacent content domains (expression syntax vs pseudo-syntax) can interfere at margins as small as 0.001-0.002. Content rewording alone may not resolve overlap — cluster deferral is the safe fallback.

## Probe Domains

| Domain | Critical | What It Tests |
|--------|----------|---------------|
| compile-safety | Yes | Single-writer lock, flock mutex |
| ci-gates | Yes | composer test + analyse mandatory |
| project-structure | Yes | Dual-repo topology |
| memory-rules | Yes | search-before-store, mcp-json-only |
| delegation | Yes | Brain as orchestrator, not executor |
| pseudo-syntax | Yes | Operator standardization with END markers |
| security | Yes | no-secret-output, compile safety contract |
| static-analysis | No | PHPStan L2 zero errors |
| release-ritual | No | Roadmap closure process |
| bridge-pattern | No | CommandBridgeAbstract handle pattern |
| lab-architecture | No | ReactPHP async REPL |
| semantic-tags | No | execute/mission/provides tags |
| benchmark | No | JSONL benchmark runner |
| delegation-rules | No | async/sync threshold (30s/5s) |
| bug-fix-recall | No | Historical bug fix retrieval |

## Batch 2: Semantic Dedup Analysis (2026-02-22)

Phase 2A dry run complete. Key finding: **zero pairs reach 0.85 cosine similarity threshold**.

### Threshold Scan Results

| Threshold | Clusters | Pairs | Action |
|-----------|----------|-------|--------|
| >= 0.90 | 0 | 0 | No near-identical memories |
| >= 0.85 | 0 | 0 | Original threshold — no candidates |
| >= 0.80 | 0 | 0 | Closest: #239↔#240 at 0.788 |
| >= 0.75 | 1 | 1 | #239↔#240 YAML env vars (LOW risk) |
| >= 0.70 | 4 | 5 | All within CustomRunCommand domain |

### Root Cause: Topic Concentration, Not Duplication

The real issue is **topic bloat** — 51% of code-solution memories cover 2 feature areas:

| Topic | Memories | % of code-solution | Consolidation |
|-------|----------|-------------------|---------------|
| CustomRunCommand features | 31 | 25% | HIGH potential |
| Lab Screen / Tab Bar UI | 32 | 26% | HIGH potential |
| Task validation reports | 15 | 12% | MEDIUM potential |

### Recommended Next Steps (Batch 2B) — COMPLETED

See Batch 2B section below for results.

### Artifacts

| File | Purpose |
|------|---------|
| `.work/memory-hygiene/dedup-snapshot.json` | Pre-dedup baseline (204 memories, categories, smoke test) |
| `.work/memory-hygiene/dedup-plan.json` | Full analysis: thresholds, clusters, topic concentration, strategies |

## Batch 2B: Topic Consolidation (2026-02-22)

Phase 2B.1 applied. Strategy: consolidate step-by-step implementation memories into single canonical summaries. Non-destructive — original memories remain, superseded status tracked in apply-log only (MCP lacks update_memory).

### Clusters Consolidated

| Cluster | Canonical | Supersedes | Topic |
|---------|-----------|------------|-------|
| A_docblock_steps | #280 | #64, #65, #66, #67, #68 | Task #13 Lab Docblock Documentation |
| B_tabbar_steps | #281 | #130, #132, #133, #134, #135 | Task #6 Tab Bar & Navigation |
| C1_conditional_syntax | #282 | #219-#225 (7 memories) | CustomRunCommand Conditional Syntax |

### Cluster Deferred

| Cluster | Original Memories | Reason |
|---------|-------------------|--------|
| C2_null_coalescing | #227, #229 | Embedding overlap with P11 pseudo-syntax probe. Two attempts (IDs 283, 284) both outranked anchor #267. Margin: 0.002 → 0.001. Deferred until probe query tuning. |

### Key Finding: Embedding Overlap Risk

MiniLM-L6-v2 (384-dim) has tight semantic neighborhoods. Adjacent content domains (expression syntax operators vs pseudo-syntax Operator.php) cannot be reliably separated by content rewording alone. When canonical content shares vocabulary with an existing probe's query space, the new memory can outrank the correct anchor by slim margins (0.001-0.002 cosine similarity).

**Mitigation:** Always run full smoke test after storing canonicals. If any probe regresses, roll back the offending canonical immediately.

### Results

| Metric | Before (2A) | After (2B.1) |
|--------|-------------|--------------|
| Total memories | 204 | 207 |
| Active memories | 204 | 190 |
| Logically superseded | 0 | 17 |
| Canonicals stored | 0 | 3 |
| Pass rate | 12/15 (80%) | 12/15 (80%) |
| Critical probes | 7/7 PASS | 7/7 PASS |
| Probes affected | — | None (after C2 rollback) |

### Artifacts

| File | Purpose |
|------|---------|
| `.work/memory-hygiene/topic-consolidation-snapshot.json` | Pre-consolidation backup (19 memory metadata, cluster definitions) |
| `.work/memory-hygiene/apply-log.json` | Applied operations, superseded IDs, C2 deferral, rollback instructions |
| `.work/memory-hygiene/smoke-results.json` | Post-consolidation smoke test (v1.2.0) |

### Remaining Consolidation Candidates

| Target | Memories | Strategy | Priority |
|--------|----------|----------|----------|
| C2 null-coalescing | #227, #229 | Deferred — needs probe query tuning first | LOW |
| Validation reports | ~15 memories | Keep re-validation only, delete initial runs | MEDIUM |
| Remaining CustomRunCommand | ~24 memories (post C1 consolidation) | Further topic-level merges | MEDIUM |

## Batch 2C: Rank Safety Gate (2026-02-22)

First execution of the Rank Safety Check (Step 6) against 10 probes (7 critical + P04, P12, P13).

### Results

| Probe | Critical | Expected | Top-1 | Sim | Canonical in Top-5 | Margin | Verdict |
|-------|----------|----------|-------|-----|---------------------|--------|---------|
| P01 | Yes | #276 | #276 | 0.743 | None | — | SAFE |
| P02 | Yes | #277 | #277 | 0.598 | None | — | SAFE |
| P03 | Yes | #278 | #278 | 0.664 | None | — | SAFE |
| P06 | Yes | #17 | #17 | 0.456 | None | — | SAFE |
| P07 | Yes | #3 | #3 | 0.664 | None | — | SAFE |
| P11 | Yes | #267 | #267 | 0.598 | #282 @ rank 5 (0.538) | 0.060 | SAFE |
| P14 | Yes | #279 | #279 | 0.593 | None | — | SAFE |
| P04 | No | — | #120 | 0.500 | None | — | BASELINE_FAIL |
| P12 | No | — | #118 | 0.570 | None | — | BASELINE_FAIL |
| P13 | No | #261 | #261 | 0.528 | None | — | SAFE |

**Verdict:** ALL_CLEAR. Zero overlap risks. All 7 critical anchors at position 1.

### Findings

1. **Canonical #282 (C1 conditional syntax)** appears only in P11 at rank 5 with margin 0.060 — well above 0.01 threshold
2. **Canonicals #280, #281** do not appear in any probe's top-5 — fully isolated embedding neighborhoods
3. **Weakest margin** is P07 at 0.019 (#3 vs #16) but both are delegation-relevant — not a false positive risk
4. **Superseded memories** (#225, #218) still appear in P11 top-5 (logical supersede only, no physical delete)

### Artifacts

| File | Purpose |
|------|---------|
| `.work/memory-hygiene/rank-safety-results.json` | Full top-5 results per probe with margins and overlap analysis |

## Anti-Patterns

| Do NOT | Why |
|--------|-----|
| Delete memories without snapshot | No rollback if critical knowledge lost |
| Store Iron Rules in memory | They live in CLAUDE.md, not vector memory |
| Over-index on similarity score | Semantic relevance matters more than raw score |
| Run dedup without smoke test baseline | No way to measure if dedup improved or degraded retrieval |
| Store canonicals without rank safety check | New content can outrank critical anchors by slim cosine margins |

## Baseline (2026-02-22)

| Metric | Initial | After Anchors |
|--------|---------|---------------|
| Total memories | 200 | 204 |
| Pass rate | 8/15 (53%) | 12/15 (80%) |
| Critical probes | 3/7 PASS | 7/7 PASS |
| Category skew | code-solution: 62% | code-solution: 61% |
| Missing critical | compile-safety, ci-gates, project-structure, security | None |
| Strongest domain | semantic-tags (0.686) | compile-safety (0.743) |
| Anchors stored | - | #276, #277, #278, #279 |

### Remaining Non-Critical Gaps (3/15)

| Probe | Domain | Reason |
|-------|--------|--------|
| P04 | static-analysis | PHPStan file counts not prominent in CI gates memory |
| P05 | release-ritual | Roadmap closure lives in .docs/ only, not memory |
| P12 | benchmark | Retrieval failure: memory #274 exists but probe query diverges |
