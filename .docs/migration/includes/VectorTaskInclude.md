# VectorTaskInclude Migration Contract

---
file: "core/src/Includes/Universal/VectorTaskInclude.php"
checkpoint: "B"
status: "planned"
lines_before: 183
lines_target: ~60
---

## Migration Summary

Transform from static guidelines to cookbook-delegating Iron Rules.

## What Stays in Include (Iron Rules)

Conditional gates only — "WHEN mandatory", not "HOW to do".

### 1. MCP-Only-Access [CRITICAL]
```
TRIGGER: Always
RULE: ALL task operations MUST use MCP tools via VectorTaskMcp.
WHY: Ensures embedding generation and data integrity.
ON VIOLATION: Use VectorTaskMcp::callJson() or callValidatedJson().
EXAMPLE (JSON-strict):
  VectorTaskMcp::callValidatedJson("task_create", {"title":"Fix bug","content":"...","estimate":2.0}, mode)
```

### 2. Explore-Before-Execute [CRITICAL]
```
TRIGGER: Always (except trivial inline fixes <0.25h)
RULE: MUST explore task context (parent, children, related) BEFORE execution.
WHY: Prevents duplicate work, discovers dependencies, ensures alignment.
ON VIOLATION: task_get({task_id}) + parent + children BEFORE task_update({status:"in_progress"})
```

### 3. Estimate-Required [CRITICAL] — CONDITIONAL
```
TRIGGER: strict>=strict OR task scope > single trivial change
RULE: EVERY task MUST have estimate in hours.
WHY: Enables planning, prioritization, decomposition.
ON VIOLATION: Add estimate. Leaf tasks ≤4h, parent = sum of children.
SKIP WHEN: minimal+relaxed AND inline fix <0.25h
```

### 4. Parent-Readonly [CRITICAL]
```
TRIGGER: Always
RULE: $PARENT task is READ-ONLY context. NEVER call task_update on parent.
WHY: Parent lifecycle managed externally. Prevents loops, hierarchy corruption.
ON VIOLATION: ABORT any task_update targeting parent_id. Only update $TASK.
```

### 5. Timestamps-Auto [CRITICAL]
```
TRIGGER: Always
RULE: NEVER set start_at/finish_at manually. System auto-manages.
WHY: Manual values corrupt timeline.
ON VIOLATION: Remove from task_update. Use only for user-requested corrections.
```

### 6. Single-In-Progress [HIGH] — CONDITIONAL
```
TRIGGER: strict>=standard
RULE: Only ONE task in_progress per agent.
WHY: Prevents context switching, ensures focus.
ON VIOLATION: Complete current before starting new.
SKIP WHEN: minimal+relaxed AND explicitly parallel-capable setup
```

## What Goes to Cookbook

All "HOW to do" patterns → delegated via cookbook calls:

| Pattern | Cookbook Query |
|---------|----------------|
| Task-first workflow | `case_category="essential-patterns"` |
| Deep exploration | `case_category="search-query"` |
| Hierarchy/decomposition | `case_category="hierarchy-decomposition"` |
| Status lifecycle | `case_category="status-time-tracking"` |
| Parallel execution | `case_category="parallel-execution", priority="critical"` |
| Comment strategy | `case_category="comment-context"` |

## Cookbook Presets for Include

Include will call cookbook based on mode:

```python
# minimal + relaxed
cookbook(include="init")

# standard (default)  
cookbook(include="cases", case_category="essential-patterns,task-execution", limit=15)

# deep OR strict
cookbook(include="cases", case_category="plan,validate,hierarchy-decomposition", cognitive="deep", limit=25)

# exhaustive OR paranoid
cookbook(include="cases", case_category="gates-rules,essential-patterns,parallel-execution", priority="critical", strict="paranoid", limit=40)
```

## Content Removal (→ Cookbook)

- [ ] Task-first workflow phases (5 lines)
- [ ] MCP tools create/read/update/delete/stats (30 lines)
- [ ] Deep exploration guidelines (4 lines)
- [ ] Search flexibility patterns (4 lines)
- [ ] Comment strategy (5 lines)
- [ ] Memory-task relationship (4 lines)
- [ ] Hierarchy explanation (4 lines)
- [ ] Decomposition phases (4 lines)
- [ ] Status flow (3 lines)
- [ ] Priority explanation (3 lines)

Estimated removal: ~66 lines of guidelines

## Content Retained

- [x] 6 Iron Rules (conditional)
- [ ] Cookbook preset logic
- [ ] Mode-aware conditional triggers

## Target Structure

```php
class VectorTaskInclude extends IncludeArchetype
{
    use ModeResolverTrait;

    protected function handle(): void
    {
        // === IRON RULES ===
        
        $this->rule('mcp-only-access')->critical()
            ->text('ALL task operations MUST use MCP tools via VectorTaskMcp.')
            ->why('Ensures embedding generation and data integrity.')
            ->onViolation('Use VectorTaskMcp::callJson() or callValidatedJson().');

        $this->rule('explore-before-execute')->critical()
            ->text('MUST explore task context (parent, children) BEFORE execution.')
            ->why('Prevents duplicate work, discovers dependencies.')
            ->onViolation('task_get + parent + children BEFORE task_update.');

        if ($this->isJsonStrictRequired() || !$this->isTrivialTask()) {
            $this->rule('estimate-required')->critical()
                ->text('EVERY task MUST have estimate in hours.')
                ->why('Enables planning, prioritization, decomposition.')
                ->onViolation('Leaf tasks ≤4h, parent = sum of children.');
        }

        $this->rule('parent-readonly')->critical()
            ->text('$PARENT is READ-ONLY. NEVER update parent task.')
            ->why('Parent lifecycle managed externally.')
            ->onViolation('ABORT task_update on parent_id.');

        $this->rule('timestamps-auto')->critical()
            ->text('NEVER set start_at/finish_at manually.')
            ->why('Manual values corrupt timeline.')
            ->onViolation('Remove from task_update.');

        if (!$this->isMinimalRelaxed()) {
            $this->rule('single-in-progress')->high()
                ->text('Only ONE task in_progress per agent.')
                ->why('Prevents context switching.')
                ->onViolation('Complete current before starting new.');
        }

        // === COOKBOOK DELEGATION ===
        $preset = $this->getCookbookPreset('task');
    }
}
```

## Tests Required

- [ ] cookbook() returns expected categories
- [ ] Conditional rules fire correctly by mode
- [ ] callValidatedJson() works with schema
- [ ] Parent update blocked
- [ ] Manual timestamps rejected in paranoid

## Risks

| Risk | Mitigation |
|------|------------|
| AI skips cookbook | Gate enforcement in strict/paranoid |
| Missing patterns in cookbook | Verify all categories exist |
| Estimate fatigue in minimal | Conditional trigger |
