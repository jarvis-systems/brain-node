---
name: "Phase 2: WebRecursiveResearchInclude Gating — DIFF"
description: "File diffs for Phase 2 WebRecursiveResearchInclude gating implementation"
date: "2026-02-20"
---

# Phase 2: WebRecursiveResearchInclude Gating — DIFF

## Modified Files

### core/src/Includes/Agent/WebRecursiveResearchInclude.php
- Added `use ModeResolverTrait;`
- Added new `research-workflow` compact guideline (flow + limits + abort) — always-on
- Moved `source-priority` and 3 rules before the gate — always-on
- Wrapped 6 phase guidelines + 3 limits guidelines in `if ($this->isDeepCognitive()) { ... }`
- Deep-only: `phase-query`, `limits-query`, `phase-evaluation`, `phase-fetch`, `limits-fetch`, `phase-recursion`, `limits-recursion`, `phase-aggregation`, `phase-output`
