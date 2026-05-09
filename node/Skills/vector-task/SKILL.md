---
name: "vector-task"
description: "Use vector tasks safely with task context exploration, JSON MCP payloads, estimates, and lifecycle discipline"
---

# Vector Task

Use this skill when creating, decomposing, executing, updating, validating, or reporting vector tasks.

## Rules

- Use MCP tool calls with JSON object payloads only.
- Read task context before execution: task, parent, children, and relevant siblings.
- Do not update parent tasks directly.
- Do not set manual timestamps.
- Every new task needs an estimate in hours.
- Keep one active in-progress task per agent unless orchestration explicitly owns parallel work.

## References

- `references/lifecycle.md`: task lifecycle and update rules.
