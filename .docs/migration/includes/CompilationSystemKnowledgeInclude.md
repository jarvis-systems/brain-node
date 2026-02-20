# CompilationSystemKnowledgeInclude Mode Gating

---
file: "core/src/Includes/Universal/CompilationSystemKnowledgeInclude.php"
type: "migration"
status: "proposed"
date: "2026-02-20"
lines_before: 332
lines_target_minimal: ~80
lines_target_full: ~332
---

## Problem

CompilationSystemKnowledgeInclude is the largest Universal include (332 lines source, ~210 lines compiled). It emits full PHP API reference to ALL modes, including minimal/standard where the scanning workflow already forces reading source files — making the reference redundant with scan output.

## Proposed Split

### Must-Know (ALL modes) — ~80 compiled lines

Content that is essential regardless of mode:

| Section | Lines | Reason |
|---------|-------|--------|
| 4 critical rules | ~20 | Safety gates — never optional |
| Scanning workflow (9 phases) | ~12 | Core contract for code generation |
| Compilation flow + directories | ~6 | Where to edit, where not to |
| Directive (5 points) | ~6 | SCAN-FIRST, PHP-API, etc. |

### Reference (deep/exhaustive only) — ~130 additional lines

Content that serves as pre-loaded cross-reference:

| Section | Lines | Why gatable |
|---------|-------|-------------|
| 6 namespace guidelines | ~30 | Scanning reads these from source |
| 5 var system guidelines | ~25 | Available in source after scan |
| 7 API reference guidelines | ~40 | Scan workflow extracts this |
| 4 archetype structures | ~20 | Structure visible in source |
| 3 builder guidelines | ~15 | Builder API in source |
| 2 CLI guidelines | ~10 | CLI commands discoverable |

## Argument

In minimal/standard mode, the scanning workflow (scan-1 through scan-9) forces the agent to read actual source files BEFORE generating code. The agent receives all namespace, API, and structure information from the source files themselves. The reference section is redundant with scan output.

In deep/exhaustive mode, having the reference pre-loaded provides:
1. Cross-check against source (catch drift)
2. Faster initial orientation without full scan
3. Complete API surface in context window

## Token Impact

| Mode | Compiled lines | Estimated tokens |
|------|---------------|-----------------|
| minimal/standard (gated) | ~80 | ~400 |
| deep/exhaustive (full) | ~210 | ~1050 |
| **Savings in minimal/standard** | **~130 lines** | **~650 tokens** |

Per-prompt savings across Brain + all agents + all commands that include this = significant multiplier.

## Diff Plan

```php
// CompilationSystemKnowledgeInclude.php
use BrainCore\Variations\Traits\ModeResolverTrait;

class CompilationSystemKnowledgeInclude extends IncludeArchetype
{
    use ModeResolverTrait;

    protected function handle(): void
    {
        // === ALWAYS (all modes) ===
        // scanning-workflow, critical rules, compilation-flow, directories, directive

        // === REFERENCE (deep/exhaustive only) ===
        if ($this->isDeepCognitive()) {
            // namespaces-*, var-*, api-*, structure-*, builder-*, cli-*
        }
    }
}
```

## Implementation Steps

1. Add `use ModeResolverTrait` to CompilationSystemKnowledgeInclude
2. Wrap reference sections in `if ($this->isDeepCognitive())` guard
3. Keep all critical rules and scanning workflow outside the guard
4. Run `brain compile` with both modes and verify output difference
5. Run `bash scripts/lint-mcp-syntax.sh` to verify lint passes
6. Run schema tests

## Risks

| Risk | Mitigation |
|------|------------|
| Agent in standard mode can't find API | Scanning workflow forces source reading — API info comes from source |
| Namespace typos without reference | Critical rules still enforce PHP-API usage — errors caught at compile |
| Missing ModeResolverTrait in cli/vendor | Verify cli/vendor copy is updated |

## Test Method

```bash
# Verify minimal output has rules but no reference
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
grep -c "Namespaces\|Api " .claude/CLAUDE.md  # should be 0

# Verify full output has everything
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile
grep -c "Namespaces\|Api " .claude/CLAUDE.md  # should be > 0
```
