---
name: "Memory Hygiene Runbook"
description: "Operational procedure for vector memory health: ledger snapshots, compaction survival smoke tests, and semantic dedup policy"
type: runbook
date: 2026-02-22
version: "1.0.0"
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

### Recommended Next Steps (Batch 2B)

1. **Consolidate step-by-step memories**: #64-#68 → 1 record, #130-#135 → 1 record (~10 merges)
2. **Consolidate validation pairs**: keep re-validation only (#119→delete, keep #123, etc.) (~7 deletes)
3. **Consolidate CustomRunCommand subtopics**: 8 ternary memories → 1-2 summaries (~6 merges)
4. **Expected net reduction**: ~25 memories (204 → ~179)

### Artifacts

| File | Purpose |
|------|---------|
| `.work/memory-hygiene/dedup-snapshot.json` | Pre-dedup baseline (204 memories, categories, smoke test) |
| `.work/memory-hygiene/dedup-plan.json` | Full analysis: thresholds, clusters, topic concentration, strategies |

## Anti-Patterns

| Do NOT | Why |
|--------|-----|
| Delete memories without snapshot | No rollback if critical knowledge lost |
| Store Iron Rules in memory | They live in CLAUDE.md, not vector memory |
| Over-index on similarity score | Semantic relevance matters more than raw score |
| Run dedup without smoke test baseline | No way to measure if dedup improved or degraded retrieval |

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
