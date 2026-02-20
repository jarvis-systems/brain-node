# C2 Batch Migration Summary

---
type: "migration-summary"
checkpoint: "C2"
status: "completed"
date: "2026-02-20"
---

## Overview

All 34 files with MCP references were migrated from legacy pseudo-JSON to `callValidatedJson()`/`callJson()` PHP API. Zero legacy calls remain.

## Files by Group

### Universal Includes (3 files)

| File | MCP Refs | Migration |
|------|----------|-----------|
| VectorMemoryInclude.php | 5 | callValidatedJson + ModeResolverTrait + cookbook delegation |
| VectorTaskInclude.php | 4 | callValidatedJson + ModeResolverTrait + cookbook delegation |
| CompilationSystemKnowledgeInclude.php | 1 | Documentation example updated |

Individual docs: `VectorMemoryInclude.md`, `VectorTaskInclude.md`, `CompilationSystemKnowledgeInclude.md`

### Task Command Includes (12 files, 120+ calls)

| File | MCP Refs | Key Changes |
|------|----------|-------------|
| TaskCreateInclude.php | 10 | VectorMemoryMcp + VectorTaskMcp + SequentialThinkingMcp + Context7Mcp |
| TaskDecomposeInclude.php | 14 | All 4 MCP classes |
| TaskSyncInclude.php | 34 | Highest density — all 4 MCP classes |
| TaskAsyncInclude.php | 34 | Mirror of Sync with async delegation |
| TaskValidateInclude.php | 36 | Highest total — VectorMemoryMcp + VectorTaskMcp + Context7Mcp |
| TaskValidateSyncInclude.php | 28 | Sync validation variant |
| TaskTestValidateInclude.php | 16 | Test validation |
| TaskBrainstormInclude.php | 12 | VectorMemoryMcp + VectorTaskMcp + Context7Mcp |
| TaskStatusInclude.php | 10 | VectorTaskMcp only |
| TaskListInclude.php | 2 | VectorTaskMcp only |
| TaskCommandCommonTrait.php | 12 | Shared trait for all task commands |

All calls use `callValidatedJson()` with schema validation. Mode resolved via `SharedCommandTrait`.

### Do Command Includes (6 files, 49 calls)

| File | MCP Refs | Key Changes |
|------|----------|-------------|
| DoSyncInclude.php | 6 | VectorMemoryMcp + SequentialThinkingMcp |
| DoAsyncInclude.php | 8 | VectorMemoryMcp + SequentialThinkingMcp |
| DoValidateInclude.php | 10 | VectorMemoryMcp + VectorTaskMcp + SequentialThinkingMcp |
| DoTestValidateInclude.php | 7 | VectorMemoryMcp + VectorTaskMcp |
| DoBrainstormInclude.php | 11 | VectorMemoryMcp + VectorTaskMcp + SequentialThinkingMcp |
| DoCommandCommonTrait.php | 7 | Shared trait |

### Memory Command Includes (6 files, 20 calls)

| File | MCP Refs |
|------|----------|
| MemListInclude.php | 2 |
| MemGetInclude.php | 2 |
| MemStoreInclude.php | 4 |
| MemSearchInclude.php | 2 |
| MemStatsInclude.php | 4 |
| MemCleanupInclude.php | 6 |

All VectorMemoryMcp-only. Mechanical migration — no architectural changes.

### Init Command Includes (5 files, 43 calls)

| File | MCP Refs |
|------|----------|
| InitBrainInclude.php | 14 |
| InitAgentsInclude.php | 8 |
| InitVectorInclude.php | 5 |
| InitTaskInclude.php | 13 |
| InitDocsInclude.php | 3 |

### Other (2 files)

| File | MCP Refs |
|------|----------|
| DocWorkInclude.php | 8 |
| SharedCommandTrait.php | 1 |

### Node Source (1 file)

| File | MCP Refs | Migration |
|------|----------|-----------|
| DoCommand.php (.brain/node) | 13 | Hardcoded mcp__ strings → VectorMemoryMcp::callValidatedJson() |

## Invariants (All Files)

1. **JSON-only**: Every MCP call uses `callValidatedJson()` or `callJson()`
2. **Schema-validated**: VectorTask/VectorMemory calls pass through McpSchemaValidator
3. **Deterministic**: ksortRecursive guarantees byte-identical output
4. **Lint-clean**: 0 legacy patterns across 67 compiled files

## Files NOT Touched (18 includes)

Agent/, Brain/, and some Universal includes without MCP references were not modified. Full list in exploration agent report.

## Totals

| Metric | Value |
|--------|-------|
| Files migrated | 34 |
| Total MCP references | 339 |
| Legacy calls remaining | 0 |
| Lint warnings | 0 |
| Schema test coverage | 10 tests, 16 assertions |
