---
name: "Phase 2: WebRecursiveResearchInclude Gating — RISKS"
description: "Risk assessment for Phase 2 WebRecursiveResearchInclude gating"
date: "2026-02-20"
---

# Phase 2: WebRecursiveResearchInclude Gating — RISKS

## Residual Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Standard mode agent lacks step-by-step research phases | Low | Compact `research-workflow` provides flow order + all numeric limits. Agent understands: query → evaluate → fetch → recurse → aggregate → output. Detailed phases available in deep/exhaustive. |
| Limits duplicated between compact summary and deep guidelines | Low | Compact summary has numeric limits inline. Deep guidelines have separate limits-* guidelines. Consistent values, no conflict. |
| Only 1 agent affected | N/A | Modest ROI (58 lines) but establishes pattern for agent-specific includes. |
