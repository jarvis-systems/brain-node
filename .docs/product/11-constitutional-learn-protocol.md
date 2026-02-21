---
name: "Constitutional Learn Protocol"
description: "Automated failure capture protocol — trigger signals, required lesson format, non-trigger rules, and benchmark enforcement"
type: product
date: 2026-02-21
version: "1.0.0"
status: active
---

# Constitutional Learn Protocol

Automated mechanism for capturing failures as reusable lessons in vector memory. Operates on trigger signals — stores lessons ONLY when specific failure conditions are detected.

## Trigger Signals

Store a lesson to vector memory when a task reports ANY of these signals:

| Signal | Source | Example |
|--------|--------|---------|
| `retries > 0` | Task comment | `ATTEMPT [exec]: 2/3` |
| `stuck` tag | Task tags | Circuit breaker activated |
| `validation-fix` tag | Subtask created | Test failures, PHPStan errors |
| `blocked` in comment | Task comment | Waiting for external dependency |
| User correction | Session | Direct user feedback correcting approach |

## Non-Triggers (MUST NOT Store)

- Task completed without errors (adds noise to memory)
- Task was `stopped` by user (cancelled, not failed)
- `strict:relaxed` + `cognitive:minimal` mode without any trigger signals above

## Required Lesson Format

Every stored lesson MUST follow this structure:

```
FAILURE: {specific error description}
ROOT CAUSE: {why it happened}
FIX: {how it was resolved}
PREVENTION: {how to avoid in future}
CONTEXT: Task #{id}, {domain area}
```

Storage parameters: `category: "bug-fix"`, `tags: ["type:lesson", "signal:{trigger}", "{domain}"]`

## Category Discipline

Lessons and proposals are strictly separated:

| Intent | Category | Required Tags |
|--------|----------|---------------|
| Lesson from failure | `bug-fix` / `debugging` | `type:lesson`, `signal:{X}` |
| Self-improvement proposal | `architecture` | `type:proposal`, `status:pending` |
| Working pattern | `code-solution` | `type:pattern` |
| Architecture decision | `architecture` | `type:decision` |

## Benchmark Enforcement

Constitutional Learn Protocol is enforced via live benchmark scenarios:

| Scenario | Tests | Enforcement |
|----------|-------|-------------|
| MT-LP-001 | Trigger signal → MUST store lesson | `expected_tools: [store_memory]` |
| MT-LP-002 | Clean completion → MUST NOT store | `banned_tools: [store_memory]` |
| MT-LP-003 | Relaxed mode + no signals → MUST NOT store | `banned_tools: [store_memory]` |

Gate authority: Enterprise Definition of Done (`.docs/audits/enterprise-codebase/ENTERPRISE-DOD.md`).

## Search-Before-Store Rule

ALWAYS search vector memory for similar content before storing a new lesson. This prevents memory pollution and duplicate entries.
