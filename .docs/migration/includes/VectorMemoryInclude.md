---
name: "VectorMemoryInclude Migration Contract"
description: "Migration contract for VectorMemoryInclude: transform to cookbook-delegating iron rules"
file: "core/src/Includes/Universal/VectorMemoryInclude.php"
checkpoint: "B"
status: "planned"
lines_before: 124
lines_target: ~50
---

# VectorMemoryInclude Migration Contract

## Migration Summary

Transform from static guidelines to cookbook-delegating Iron Rules.

## What Stays in Include (Iron Rules)

Conditional gates only — "WHEN mandatory", not "HOW to do".

### 1. MCP-Only-Access [CRITICAL]
```
TRIGGER: Always
RULE: ALL memory operations MUST use MCP tools via VectorMemoryMcp.
WHY: Ensures valid JSON, embedding generation, data integrity.
ON VIOLATION: Use VectorMemoryMcp::callJson() or callValidatedJson().
EXAMPLE (JSON-strict):
  VectorMemoryMcp::callValidatedJson("search_memories", {"query":"auth","limit":5}, mode)
```

### 2. Multi-Probe-Mandatory [CRITICAL] — CONDITIONAL
```
TRIGGER: strict>=strict OR cognitive>=deep OR query is compound/ambiguous
RULE: Complex queries require 2-3 focused probes. Single query = missed context.
WHY: Vector search has semantic radius. Multiple probes cover more knowledge space.
ON VIOLATION: cookbook(include="cases", case_category="search", priority="critical")
SKIP WHEN: minimal+relaxed AND simple query AND no critical context needed
```

### 3. Search-Before-Store [HIGH] — CONDITIONAL
```
TRIGGER: strict>=strict OR cognitive>=standard
RULE: ALWAYS search for similar content before storing.
WHY: Prevents memory pollution. Keeps knowledge base clean.
ON VIOLATION: VectorMemoryMcp::callJson("search_memories", {"query":"{insight}","limit":3})
SKIP WHEN: minimal+relaxed AND user explicitly requests direct store
```

### 4. Triggered-Suggestion [HIGH]
```
TRIGGER: strict:paranoid OR cognitive:exhaustive OR user request OR high time_spent
RULE: Suggestion mode ONLY when triggered.
WHY: Continuous proposals waste tokens and clutter memory.
ON VIOLATION: Check task tags before storing proposals.
```

## What Goes to Cookbook

All "HOW to do" patterns → delegated via cookbook calls:

| Pattern | Cookbook Query |
|---------|----------------|
| Multi-probe strategy | `case_category="search", priority="critical"` |
| Query decomposition | `case_category="search", query="decomposition"` |
| Smart store protocol | `case_category="store", priority="high"` |
| Categories taxonomy | `include="categories"` |
| Pre-task mining | `case_category="search", query="pre-task"` |

## Cookbook Presets for Include

Include will call cookbook based on mode:

```python
# minimal + relaxed
cookbook(include="init")

# standard (default)
cookbook(include="cases", case_category="search", limit=15)

# deep OR strict
cookbook(include="cases", case_category="search,store", cognitive="deep", limit=25)

# exhaustive OR paranoid
cookbook(include="cases", case_category="gates-rules,essential-patterns", priority="critical", strict="paranoid", limit=40)
```

## Content Removal (→ Cookbook)

- [ ] Multi-probe search strategy (9 lines)
- [ ] Query decomposition patterns (4 lines)
- [ ] Inter-agent context passing (4 lines)
- [ ] Pre-task mining protocol (4 lines)
- [ ] Smart store protocol (4 lines)
- [ ] Content quality guidelines (4 lines)
- [ ] Efficiency guards (4 lines)
- [ ] MCP tools reference (6 lines)
- [ ] Categories list (6 lines)

Estimated removal: ~45 lines of guidelines

## Content Retained

- [x] 4 Iron Rules (conditional)
- [ ] Cookbook preset logic
- [ ] Mode-aware conditional triggers

## Target Structure

```php
class VectorMemoryInclude extends IncludeArchetype
{
    use ModeResolverTrait;

    protected function handle(): void
    {
        // === IRON RULES (conditional) ===
        
        $this->rule('mcp-only-access')->critical()
            ->text('ALL memory operations MUST use MCP tools via VectorMemoryMcp.')
            ->why('Ensures valid JSON, embedding generation, data integrity.')
            ->onViolation('Use VectorMemoryMcp::callJson() or callValidatedJson().');

        if ($this->isJsonStrictRequired() || $this->isDeepCognitive()) {
            $this->rule('multi-probe-mandatory')->critical()
                ->text('Complex queries require 2-3 focused probes.')
                ->why('Vector search has semantic radius. Multiple probes cover knowledge space.')
                ->onViolation('cookbook(include="cases", case_category="search", priority="critical")');
        }

        // ... other conditional rules

        // === COOKBOOK DELEGATION ===
        $preset = $this->getCookbookPreset('memory');
        // Include will reference: mcp__vector-memory__cookbook($preset)
    }
}
```

## Tests Required

- [ ] cookbook() returns expected categories
- [ ] Conditional rules fire correctly by mode
- [ ] callValidatedJson() works with schema
- [ ] Legacy call() warns in standard, fails in paranoid

## Risks

| Risk | Mitigation |
|------|------------|
| AI skips cookbook | Gate enforcement in strict/paranoid |
| Missing patterns in cookbook | Verify cookbook has all categories before merge |
| Backward compatibility | Keep legacy call() working with warning |
