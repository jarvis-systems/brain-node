---
name: "Benchmark Cookbook Coverage Report"
description: "Maps benchmark scenarios to cookbook case_categories and identifies coverage gaps"
type: "coverage-analysis"
date: "2026-02-20"
version: "1.0"
---

# Cookbook Coverage Report

Maps benchmark scenarios to cookbook case_categories and identifies gaps requiring new cookbook cases.

## Scenario → Cookbook Mapping

### Multi-turn Scenarios

| Scenario | MCP Server | Expected Operations | Cookbook Categories | Gap |
|----------|-----------|--------------------|--------------------|-----|
| MT-001 (memory store→search) | vector-memory | store_memory, search_memories | `store`, `search` | No `store-then-verify` workflow case |
| MT-002 (task create→list) | vector-task | task_create, task_list | `plan`, `create` | No `create-then-validate` workflow case |
| MT-003 (governance turns) | none | governance knowledge | — | Not MCP-dependent |

### Key Single-turn Scenarios

| Scenario | MCP Server | Expected Operations | Cookbook Categories | Gap |
|----------|-----------|--------------------|--------------------|-----|
| ST-001 (force MCP call) | vector-memory | search_memories | `search` | Covered |
| L2-001 (task MCP format) | vector-task | task_create (format) | `create` | No `format-validation` case |
| L2-002 (memory MCP format) | vector-memory | search_memories (format) | `search` | No `format-validation` case |
| L2-005 (memory budget) | vector-memory | search_memories (limits) | `search` | No `budget-aware-search` case |
| L3-002 (search-before-store) | vector-memory | search + store governance | `search`, `store` | No `governance-check` workflow case |

## Coverage Matrix

| Cookbook Category | Existing Cases | Benchmark Coverage | Gap Level |
|-----------------|---------------|-------------------|-----------|
| `search` | Standard search workflows | ST-001, L2-002, L2-005 | Low — well covered |
| `store` | Standard store workflows | MT-001 turn 1 | Medium — no verify step |
| `plan` | Task planning workflows | MT-002 | Medium — no create→validate flow |
| `create` | Task creation workflows | L2-001, MT-002 turn 1 | Medium — no format validation |
| `governance` | Policy compliance | MT-003, L3-001..L3-008 | High — no cookbook cases exist |
| `workflow` | Multi-step sequences | MT-001, MT-002 | High — no multi-step cases |

## Identified Gaps (Priority Order)

### Gap 1: No multi-step workflow cookbook cases
**Impact**: MT-001 and MT-002 test store→search and create→list workflows, but cookbook has no cases guiding agents through multi-step MCP sequences.

### Gap 2: No governance-specific cookbook category
**Impact**: MT-003 and L3-* scenarios test governance compliance. Cookbook lacks a `governance` category with cases for policy enforcement during MCP operations.

### Gap 3: No format-validation cookbook cases
**Impact**: L2-001 and L2-002 test MCP call format correctness. No cookbook case explicitly documents expected JSON structures.

### Gap 4: No budget-aware operation cases
**Impact**: L2-005 tests memory budget limits. No cookbook case addresses operation budgets.

## Proposed Cookbook Cases

### For vector-memory-mcp (target: CASES_AGENTS.md)

#### Case 1: `workflow:store-then-verify`
- **Category**: `workflow`
- **Priority**: high
- **Description**: After storing a memory, immediately search to verify storage succeeded. Prevents silent store failures.
- **Example MCP calls**:
  ```
  mcp__vector-memory__store_memory({"content":"...", "tags":["..."], "category":"..."})
  mcp__vector-memory__search_memories({"query":"<stored content summary>", "limit":1})
  ```
- **Governance**: No additional cookbook pulls needed. Uses compile-time preset.

#### Case 2: `governance:search-budget-enforcement`
- **Category**: `governance`
- **Priority**: high
- **Description**: Before executing a search, verify remaining budget (max 3 searches per operation per iron rule `memory-limit`). Track search count in context.
- **Example MCP calls**:
  ```
  mcp__vector-memory__search_memories({"query":"...", "limit":3})
  # Track: search_count += 1. If search_count >= 3, STOP.
  ```
- **Governance**: Iron rule `memory-limit` takes precedence. No runtime cookbook pull.

### For vector-task-mcp (target: CASES.md)

#### Case 3: `workflow:create-then-validate`
- **Category**: `workflow`
- **Priority**: high
- **Description**: After task_create, immediately task_get to confirm fields persisted correctly. Prevents phantom tasks.
- **Example MCP calls**:
  ```
  mcp__vector-task__task_create({"title":"...", "description":"...", "tags":["..."]})
  mcp__vector-task__task_get({"task_id":"<returned_id>"})
  ```
- **Governance**: Uses `explore-before-execute` iron rule pattern. No extra pulls.

#### Case 4: `governance:parent-readonly-enforcement`
- **Category**: `governance`
- **Priority**: medium
- **Description**: Before any task_update, verify target task is NOT a parent task. Parent tasks are read-only per iron rule `parent-readonly`.
- **Example MCP calls**:
  ```
  mcp__vector-task__task_get({"task_id":"<target>"})
  # Check: if task has children AND is not assigned to agent, treat as parent → SKIP update
  mcp__vector-task__task_update({"task_id":"<target>", ...})  # Only if NOT parent
  ```
- **Governance**: Iron rule `parent-readonly` is CRITICAL. Violation = abort update.

#### Case 5: `format:mcp-call-structure`
- **Category**: `format`
- **Priority**: medium
- **Description**: Documents the exact JSON structure required for all task operations. Prevents malformed MCP calls that silently fail.
- **Example MCP calls**:
  ```
  # Correct: JSON object with required fields
  mcp__vector-task__task_create({"title":"Required", "description":"Required"})

  # Incorrect: missing required fields → silent failure
  mcp__vector-task__task_create({"title":"Missing description"})
  ```
- **Governance**: Iron rule `mcp-json-only` applies. All payloads must be valid JSON objects.

## Summary

| Case | Target | Category | Priority | Benchmark Coverage |
|------|--------|----------|----------|-------------------|
| workflow:store-then-verify | vector-memory | workflow | high | MT-001 |
| governance:search-budget-enforcement | vector-memory | governance | high | L2-005, L3-002 |
| workflow:create-then-validate | vector-task | workflow | high | MT-002 |
| governance:parent-readonly-enforcement | vector-task | governance | medium | L3-006 |
| format:mcp-call-structure | vector-task | format | medium | L2-001, L2-002 |

## Next Steps

1. Submit cases 1-3 (high priority) to MCP repos as PR
2. After merge, run `composer benchmark:telemetry` to verify no regressions
3. Submit cases 4-5 (medium priority) in follow-up PR
4. Add benchmark scenarios that specifically test cookbook case retrieval (future)
