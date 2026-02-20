---
name: "Phase 1: Deep-Cognitive Gating"
description: "Audit phase 1: compile-time deep-cognitive gating to reduce standard prompt by 31%"
type: "audit"
version: "1.0.0"
date: "2026-02-20"
status: "implemented"
prerequisite: "enterprise-readiness.md"
---

# Phase 1: Deep-Cognitive Gating

## Executive Summary

Phase 1 reduces the standard/standard compiled Brain prompt by 31% through compile-time gating. Reference-heavy guidelines (authority levels, delegation types, workflow phases, error playbooks, validation thresholds) are gated behind `isDeepCognitive()`, emitting only in deep/exhaustive modes. Iron rules and operational summaries remain always-on in all modes.

**Result:** 489 → 337 lines (-152, -31%) in standard/standard. Zero impact on paranoid/exhaustive (731 lines unchanged). Zero mode leakage. Zero regressions.

---

## What Changed

### Files Modified (3 PHP source files in `core/`)

| File | Change | Always-on | Deep-only |
|------|--------|-----------|-----------|
| `core/src/Includes/Brain/DelegationProtocolsInclude.php` | +ModeResolverTrait, gate 14 guidelines | 5 rules + exploration-delegation | level-*, type-*, workflow-*, validation-delegation, fallback-delegation |
| `core/src/Includes/Brain/ResponseValidationInclude.php` | +ModeResolverTrait, early return | Nothing (CoreInclude quality-gate covers compact version) | All 4 guidelines: validation-semantic, -structural, -policy, -actions |
| `core/src/Includes/Brain/ErrorHandlingInclude.php` | +ModeResolverTrait, gate 5 guidelines | escalation-policy | error-delegation-failed, -agent-timeout, -invalid-response, -context-loss, -resource-exceeded |

### Pattern Used

Follows the existing exemplar in `VectorTaskInclude.php`:
```php
use BrainCore\Variations\Traits\ModeResolverTrait;

class XxxInclude extends IncludeArchetype
{
    use ModeResolverTrait;

    protected function handle(): void
    {
        // Always-on rules/guidelines here

        if ($this->isDeepCognitive()) {
            // Reference-heavy guidelines here
        }
    }
}
```

No new abstractions. No new files. No new traits. Identical pattern to 3 existing includes that already use ModeResolverTrait.

---

## Before / After Metrics

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| CLAUDE.md (standard/standard) | 489 lines | 337 lines | **-152 (-31%)** |
| CLAUDE.md (paranoid/exhaustive) | 731 lines | 731 lines | **0 (unchanged)** |
| Gated keywords in standard | present | 0 | **eliminated** |
| Gated keywords in exhaustive | present | present | **preserved** |
| lint-mcp-syntax.sh | PASS | PASS | **no regression** |
| McpSchemaValidatorTest | 10 tests, 16 assertions | 10 tests, 16 assertions | **no regression** |

---

## Verification Checklist

All commands run from project root.

### 1. Compile standard/standard and check line count
```bash
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
wc -l .claude/CLAUDE.md
# Expected: 337
```

### 2. Verify gated content absent in standard
```bash
grep -cE 'level-brain|level-architect|level-specialist|level-tool|type-task|type-analysis|type-validation' .claude/CLAUDE.md
# Expected: 0

grep -cE 'error-delegation-failed|error-agent-timeout|error-invalid-response|error-context-loss|error-resource-exceeded' .claude/CLAUDE.md
# Expected: 0

grep -cE 'validation-semantic|validation-structural|validation-policy|validation-actions' .claude/CLAUDE.md
# Expected: 0

grep -cE 'workflow-request-analysis|workflow-agent-selection|workflow-delegation|workflow-synthesis|workflow-knowledge-storage' .claude/CLAUDE.md
# Expected: 0
```

### 3. Verify always-on content present in standard
```bash
grep -cE 'delegation-limit|non-recursive|accountability' .claude/CLAUDE.md
# Expected: > 0

grep -c 'escalation-policy' .claude/CLAUDE.md
# Expected: > 0

grep -c 'exploration-delegation' .claude/CLAUDE.md
# Expected: > 0
```

### 4. Compile paranoid/exhaustive and check line count
```bash
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile
wc -l .claude/CLAUDE.md
# Expected: 731
```

### 5. Verify gated content present in exhaustive
```bash
grep -cE 'level-brain|level-architect|level-specialist|level-tool' .claude/CLAUDE.md
# Expected: > 0

grep -cE 'error-delegation-failed|error-agent-timeout' .claude/CLAUDE.md
# Expected: > 0

grep -cE 'validation-semantic|validation-structural' .claude/CLAUDE.md
# Expected: > 0
```

### 6. Restore standard/standard
```bash
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
```

### 7. Lint and tests
```bash
bash scripts/lint-mcp-syntax.sh
# Expected: PASSED

cd core && ./vendor/bin/phpunit tests/McpSchemaValidatorTest.php
# Expected: OK (10 tests, 16 assertions)
```

---

## Non-Goals / Explicitly Not Changed

1. **SequentialReasoningInclude** — Universal include, NOT present in Brain CLAUDE.md (only in agent artifacts). Deferred to Phase 1b.
2. **LifecycleInclude** — Agent-only include. Deferred to Phase 1b.
3. **Command includes (28 files)** — Already have their own gating via `SharedCommandTrait::strictAtLeast()/cognitiveAtLeast()`. Separate epic.
4. **Cookbook Governance Policy** — Policy drafted but not yet implemented. Separate changeset.
5. **Upstream MCP repos** — No changes to vector-task-mcp or vector-memory-mcp.
6. **CoreInclude** — Compact enough (5 guidelines), constitutional content. Not worth gating.
7. **PreActionValidationInclude** — 3 rules + 1 guideline, all operationally critical. Not worth gating.

---

## Residual Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Standard mode may lack delegation reference when Brain encounters novel delegation patterns | Low | CoreInclude workflow guideline provides compact summary; deep/exhaustive available for complex cases |
| ResponseValidation entirely absent in standard — Brain relies solely on CoreInclude quality-gate rule | Medium | quality-gate rule covers threshold (>=0.75) + retry logic (max 2). Sufficient for standard operations |
| Error scenarios absent in standard — only escalation-policy remains | Low | Escalation policy provides 3-tier framework (standard/critical/unrecoverable). Detailed playbooks needed only for deep troubleshooting |
| `core/` is a separate git repo — Phase 1 changes not covered by main repo CI diff-guard | Medium | Changes must be committed in both repos. Document in operational guidance |

---

## Next Planned Iterations

### Phase 1b: Remaining High-ROI Includes
- `SequentialReasoningInclude` — gate 4 phase guidelines, keep phase-flow always-on (~40-50 lines saved per agent)
- `LifecycleInclude` — gate 4 phase guidelines, keep transitions always-on (~40-50 lines saved per agent)

### Phase 2: Medium-ROI Includes
- `WebRecursiveResearchInclude` — gate detailed phases/limits (~40-50 lines per agent)
- `LaravelBoostGuidelinesInclude` — gate workflows (~30-40 lines)
- `LaravelBoostClassToolsInclude` — gate strategies (~25-35 lines)
- `BrainScriptsInclude` — gate detailed workflows (~30-40 lines)

### Phase 3: Cookbook Governance Policy
- Implement 10-rule policy in VectorTaskInclude + VectorMemoryInclude
- Gate 5 "Cookbook-First" Brain-side reinterpretation
- Verification: grep for banned "uncertainty" triggers in compiled output

---

## Audit Trail

- **Audit v1.0** — Initial enterprise prompt architecture review
- **Audit v2.0** — MCP JSON migration verification
- **Audit v3.0** — Deep research digest + holivar protocol + iteration plan
- **Phase 1** — This document. Implementation + verification of deep-cognitive gating
