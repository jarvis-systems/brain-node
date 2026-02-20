# Brain Integration Guide

---
name: "Brain Integration Guide"
description: "Metacognitive constitution for Brain-Cookbook-Task-Memory orchestration"
part: 1
type: "guide"
date: "2026-02-19"
version: "1.0.0"
---

## Purpose

This document defines the **metacognitive contract** between:
- Brain (orchestrator)
- Task MCP (execution tracking)
- Memory MCP (knowledge storage)

It establishes **constitutional rules** that ensure consistency, prevent drift, and enable self-improvement without overengineering.

---

## Section A: Constitutional Learn Protocol [CRITICAL]

### Purpose

Capture failure patterns automatically to prevent repeated mistakes. This is NOT optional philosophy—it is a mandatory execution step.

### Trigger Signals

Learn Protocol triggers when ANY of these signals are present:

| Signal | Detection | Example |
|--------|-----------|---------|
| `retries > 0` | Task comment contains "ATTEMPT" count > 0 | "ATTEMPT [exec]: 2/3" |
| `stuck` tag | Task has tag `stuck` | Circuit breaker activated |
| `validation-fix` tag | Subtask created for validation issues | Test failures, code quality |
| `blocked` in comment | Comment contains "BLOCKED:" | External dependency missing |
| User correction | User explicitly corrected agent output | "No, do it this way" |

### Non-Triggers

Learn Protocol does NOT trigger when:

- Task completed cleanly (no retries, no corrections)
- Task was `stopped` by user request (cancelled, not a failure)
- `strict:relaxed` + `cognitive:minimal` AND no signals above

### Execution Format

```python
# After task completion with trigger signals:

mcp__vector-memory__store_memory({
    "content": """FAILURE: {what_failed}
ROOT CAUSE: {why_it_failed}
FIX: {how_fixed}
PREVENTION: {how_to_prevent}
CONTEXT: Task #{task_id}, {brief_context}""",
    "category": "bug-fix",  # or "debugging" for investigation-only
    "tags": ["type:lesson", "signal:{trigger_signal}", "{domain}"]
})
```

### Required Tags

| Tag Type | Format | Example |
|----------|--------|---------|
| Type | `type:lesson` | Always required |
| Signal | `signal:{trigger}` | `signal:retry`, `signal:stuck`, `signal:validation-fix` |
| Domain | `{area}` | `auth`, `api`, `database`, `parallel` |

### Forbidden Actions

- NEVER store if task was clean (pollutes memory)
- NEVER store without ROOT CAUSE (useless pattern)
- NEVER store raw error logs (extract pattern, not logs)
- NEVER store proposals here (use Suggestion Mode instead)

---

## Section B: Category Discipline Contract

### Principle

Categories provide first-level filtering. Tags provide second-level. Discipline prevents cross-contamination.

### Category Assignment Rules

| Intent | Category | Required Tags | Forbidden |
|--------|----------|---------------|-----------|
| **Lesson from failure** | `bug-fix` or `debugging` | `type:lesson` | `type:proposal` |
| **Architecture decision** | `architecture` | `type:decision` | `type:lesson` |
| **Self-improvement proposal** | `architecture` | `type:proposal`, `status:pending` | `type:lesson` |
| **Working pattern** | `code-solution` | `type:pattern` | `type:proposal` |
| **Tool usage discovery** | `tool-usage` | `type:insight` | `type:proposal` |
| **Project convention** | `project-context` | `type:convention` | `type:proposal` |

### Critical Separation

```
LESSONS (past failures) ≠ PROPOSALS (future improvements)

Lessons:
  - category: bug-fix / debugging
  - tags: [type:lesson, signal:X]
  - content: what failed + why + fix + prevention

Proposals:
  - category: architecture
  - tags: [type:proposal, status:pending]
  - content: what to improve + why + how + expected benefit
```

### Why This Matters

Memory MCP uses OR logic for tags. Without category discipline:
- `search_memories(tags=["type:proposal"])` returns lessons too (noise)
- Category provides clean separation: `bug-fix` ≠ `architecture`

---

## Section C: Standard Search Patterns

### Canonical Search Format

Since tags use OR logic, combine category + query for precision:

```python
# Find lessons about authentication failures
mcp__vector-memory__search_memories({
    "category": "bug-fix",
    "query": "type:lesson auth",
    "limit": 10
})

# Find pending self-improvement proposals
mcp__vector-memory__search_memories({
    "category": "architecture",
    "query": "type:proposal status:pending",
    "limit": 10
})

# Find accepted patterns for feature X
mcp__vector-memory__search_memories({
    "category": "code-solution",
    "query": "type:pattern {feature_name}",
    "limit": 5
})

# Find what to AVOID (failures)
mcp__vector-memory__search_memories({
    "category": "debugging",
    "query": "type:lesson signal:stuck",
    "limit": 10
})
```

### Search Pattern Table

| Find | Category | Query Pattern |
|------|----------|---------------|
| Lessons | `bug-fix` | `type:lesson {domain}` |
| Pending proposals | `architecture` | `type:proposal status:pending` |
| Accepted proposals | `architecture` | `type:proposal status:accepted` |
| Patterns | `code-solution` | `type:pattern {feature}` |
| Decisions | `architecture` | `type:decision {topic}` |
| What to avoid | `debugging` | `type:lesson signal:{signal}` |

---

## Section D: Trigger-based Suggestion Mode [HIGH]

### Purpose

Allow agents to propose improvements to instructions they execute, but only when triggered—not continuously.

### Triggers

Suggestion Mode activates when ANY:

| Trigger | Detection |
|---------|-----------|
| `strict:paranoid` | Task has `strict:paranoid` tag |
| `cognitive:exhaustive` | Task has `cognitive:exhaustive` tag |
| User request | User asks "how to improve this?" or similar |
| Multiple retries | Task comment shows 3+ attempts |
| High time_spent | `time_spent` significantly exceeds `estimate` |

### Budget Constraints

- **Max proposals per session:** 3
- **Max content length:** 500 characters
- **Required format:** Problem + Solution + Expected benefit
- **Status:** Always `status:pending` (never auto-accept)

### Execution Format

```python
mcp__vector-memory__store_memory({
    "content": """PROPOSAL: {what_to_improve}
PROBLEM: {current_issue}
SOLUTION: {proposed_change}
BENEFIT: {expected_improvement}
CONTEXT: Instruction {file}:{section}, Task #{task_id}""",
    "category": "architecture",
    "tags": ["type:proposal", "status:pending", "source:self"]
})
```

### Acceptance Flow

```
1. Agent stores proposal with status:pending
2. Brain/Human reviews proposal
3. If accepted:
   - Update instruction file
   - Update memory: tags.remove("status:pending"), tags.add("status:accepted")
4. If rejected:
   - Update memory: tags.remove("status:pending"), tags.add("status:rejected")
   - Add rejection reason to content
```

---

## Section E: Lightweight Lawyer Gate [HIGH]

### Purpose

Prevent proposals that violate system integrity. Self-verification before storing.

### Verification Checklist

Before storing ANY proposal, verify:

| Check | Question | Pass Condition |
|-------|----------|----------------|
| **Iron Rules** | Does this violate any Iron Rule? | NO violation → PASS |
| **Measurable** | Can benefit be measured? | Has metric → PASS |
| **Reversible** | Can this be undone? | Has rollback → PASS |
| **Scope** | Does this expand task scope? | Same scope → PASS |
| **Security** | Does this affect security? | No change OR improvement → PASS |

### Decision Matrix

| Checks Passed | Action |
|---------------|--------|
| 5/5 | Store proposal |
| 4/5 (Security fail) | REJECT or escalate |
| < 4/5 | REJECT, explain why |

### Format in Memory

```python
# Approved proposal
"tags": ["type:proposal", "status:pending", "gate:passed"]

# Rejected proposal (store for learning)
"content": """PROPOSAL: {what}
GATE FAILED: {which_check}
REASON: {why_failed}
LESSON: {what_we_learned}"""
"tags": ["type:proposal", "status:rejected", "gate:failed"]
```

---

## Section F: Six Constitutional Gates [CRITICAL]

### Purpose

Six mandatory gates that protect system integrity. Each gate is self-contained and MUST be enforced.

### Gates Overview

| Gate | Purpose | Trigger |
|------|---------|---------|
| **1. MCP-JSON-ONLY** | All MCP calls via JSON-RPC | Any operation |
| **2. Lightweight Lawyer Gate** | Proposals pass 5-check | Self-improvement |
| **3. Constitutional Learn Protocol** | Failures store lessons | Trigger signals |
| **4. Category Discipline** | Fixed categories only | Any storage |
| **5. Cookbook-First** | Check cookbook before assuming | Uncertainty |
| **6. Failure Escalation** | Escalate by severity | Any failure |

### Enforcement

```python
# Gate enforcement check
for gate in SIX_CONSTITUTIONAL_GATES:
    if gate.triggered():
        if not gate.passed():
            if gate.severity == "CRITICAL":
                STOP + ESCALATE
            else:
                WARN + LOG
```

### Reference

Full gate specifications in `CASES.md` → "Gates & Rules Scenarios" → "Six Constitutional Gates".

---

## Section G: Non-Goals [CRITICAL]

### What We Do NOT Do (Now)

These are explicitly out of scope to prevent overengineering:

| Non-Goal | Why Not Now |
|----------|-------------|
| **AND filters for tags** | Category + query achieves 99% precision without code change |
| **Structural case parser** | Regex parser works; AST is overkill |
| **Auto-checklist tools** | Text-based self-verify is sufficient |
| **Dynamic post-hooks** | Constitutional blocks in docs are simpler |
| **New categories (lesson, proposal)** | Add only when noise becomes real problem |
| **Automatic proposal acceptance** | Human review is required safety gate |
| **Continuous suggestion mode** | Trigger-based prevents token waste |

### When to Reconsider

Revisit non-goals ONLY when:

1. **AND filters:** Search noise > 20% in production
2. **New categories:** Category discipline fails repeatedly
3. **Auto-accept:** Review queue becomes bottleneck (>50 pending)
4. **Structural parser:** Case maintenance becomes unmanageable

### Escalation Path

```
Problem identified → Document in memory → 
Discuss with human → Measure impact → 
Decide: accept pain OR implement solution
```

---

## Section H: Tag Taxonomy

### Prefix Standards

| Prefix | Purpose | Values |
|--------|---------|--------|
| `type:` | Content classification | `lesson`, `proposal`, `pattern`, `decision`, `insight`, `convention` |
| `status:` | Lifecycle state | `pending`, `accepted`, `rejected`, `deprecated` |
| `signal:` | Trigger indicator | `retry`, `stuck`, `validation-fix`, `blocked` |
| `source:` | Origin | `self`, `user`, `agent`, `external` |

### Tag Combination Rules

```python
# Lesson from retry
["type:lesson", "signal:retry", "auth"]

# Pending proposal from self-analysis
["type:proposal", "status:pending", "source:self", "parallel-execution"]

# Accepted pattern
["type:pattern", "status:accepted", "api"]

# Rejected proposal (gate failed)
["type:proposal", "status:rejected", "gate:failed"]
```

### Max Tags

- Maximum 10 tags per entry (Memory MCP limit)
- Minimum 2 tags: `type:` + domain
- Recommended: `type:` + `status:`/`signal:` + 1-2 domain tags

---

## Section I: Brain-Cookbook Integration

### When Brain Calls Cookbook

| Scenario | Include | Filters |
|----------|---------|---------|
| Starting task | `init` | None |
| Need patterns | `cases` | `case_category`, `query` |
| Critical rules only | `cases` | `priority="critical"` |
| Deep research mode | `cases` | `cognitive="deep,exhaustive"` |
| Paranoid security | `cases` | `strict="strict,paranoid"` |

### Cognitive-Strict Matrix

| Cognitive | Strict | Behavior |
|-----------|--------|----------|
| `minimal` | `relaxed` | Fast path, minimal checks |
| `standard` | `standard` | Normal execution |
| `deep` | `strict` | Extra research, careful validation |
| `exhaustive` | `paranoid` | Maximum research, all gates active |

### Suggestion Mode Activation

```python
# Check if suggestion mode should activate
if task_has_tag("strict:paranoid") or task_has_tag("cognitive:exhaustive"):
    suggestion_mode = True
elif user_requested_improvement():
    suggestion_mode = True
else:
    suggestion_mode = False
```

---

## Appendix: Quick Reference Card

### Learn Protocol

```
IF (retries OR stuck OR validation-fix OR blocked):
    store_memory(
        content = "FAILURE: ... ROOT CAUSE: ... FIX: ... PREVENTION: ..."
        category = "bug-fix"
        tags = ["type:lesson", "signal:{signal}", "{domain}"]
    )
```

### Suggestion Mode

```
IF (strict:paranoid OR cognitive:exhaustive OR user_request OR high_time_spent):
    IF gate_checks_pass():
        store_memory(
            content = "PROPOSAL: ... PROBLEM: ... SOLUTION: ... BENEFIT: ..."
            category = "architecture"
            tags = ["type:proposal", "status:pending", "source:self"]
        )
```

### Search Patterns

```
Lessons:     category="bug-fix", query="type:lesson {domain}"
Proposals:   category="architecture", query="type:proposal status:{status}"
Patterns:    category="code-solution", query="type:pattern {feature}"
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-19 | Initial constitutional framework |
