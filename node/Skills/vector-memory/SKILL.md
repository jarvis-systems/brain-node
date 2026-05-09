---
name: "vector-memory"
description: "Use vector memory safely with MCP JSON payloads, cookbook governance, multi-probe search, and search-before-store discipline"
---

# Vector Memory

Use this skill when searching, storing, normalizing, or reasoning from vector memory.

## Rules

- Use MCP tool calls with JSON object payloads only.
- Search before storing. Store only durable implementation, debugging, architecture, security, or performance insights.
- Use 2-3 targeted probes for non-trivial searches; one broad query misses semantic neighborhoods.
- Cookbook pulls are deterministic: use the compiled preset or explicit onViolation guidance. Do not call cookbook because of vague uncertainty.
- Do not store secrets, raw logs, or transient command dumps.

## References

- `references/workflow.md`: search/store and cookbook workflow.
