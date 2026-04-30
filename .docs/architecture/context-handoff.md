---
name: "Context Handoff"
description: "Compact warm-context reuse protocol for vector task lifecycle commands"
type: architecture
date: 2026-05-01
version: "1.0.0"
status: active
---

# Context Handoff

Context handoff is a token optimization for `/task:sync`, `/task:async`, `/task:validate`, `/task:validate-sync`, and `/task:test-validate`.

It does not replace authoritative MCP reads. Every lifecycle command still loads the assigned task with `task_get`, parses the current task comment, checks retry/stuck state, refreshes active parallel sibling state, and runs the final status safety check.

The handoff may reuse only warm context that is expensive and stable: parent summaries, documentation path/hash references, memory IDs, known failure summaries, discovered file lists, and existing pattern notes. Reuse is allowed only when the visible `CONTEXT_HANDOFF v1` block matches the current task ID and the current task fingerprint.

`-c/--cold` disables reuse and forces normal context loading. `-r/--reuse-context` requests reuse but still falls back to cold loading when the fingerprint is missing, mismatched, or uncertain. Default mode is `auto`: reuse valid handoff context when present, otherwise load cold.

Final command output should include a compact `STATUS: [handoff] CONTEXT_HANDOFF v1 ...` line before `RESULT`/`NEXT`. The line must contain pointers and hashes only, not full documents, raw logs, agent JSON, task bodies, or secrets.
