---
name: "MCP Stdio Adapter"
description: "Canonical execution contract for MCP v1 Stdio wrapping"
type: architecture
date: 2026-02-26
version: "1.0.0"
status: active
---

# MCP Stdio Adapter Contract

The Brain MCP v1 implementation treats external MCP servers strictly as CLI `stdio` tools. This document defines the canonical boundaries for how Brain orchestrates, spawns, and parses responses from external tools like `laravel-boost`.

## The `stdio` Adapter

All remote MCP servers MUST integrate with Brain via a generic `StdioAdapter`.

### Constraints
1. **No Daemons / Supervisors**: Servers must execute ephemerally per CLI invocation.
2. **Byte-Empty Stderr**: In normal execution mode, servers MUST NOT emit any output to `stderr`. Any non-empty `stderr` buffer is an immediate contract violation and causes policy blockage.
3. **Piped RPC Enforcement**: Requests are pipelined via `stdin` as a JSON-RPC 2.0 payload.
4. **JSON Mux Response**: The server must write the JSON-RPC response on `stdout`.
5. **Redaction First**: Output is normalized into a unified DTO and passed through `McpRedactor` before surfacing to any client layer.

### Envelope Definitions

**Stdin Request Envelope:**
```json
{
  "jsonrpc": "2.0",
  "id": "brain-<uniqid>",
  "method": "tools/call",
  "params": {
    "name": "<tool_name>",
    "arguments": { ... }
  }
}
```

**Stdout Unified Response Envelope:**
```json
{
  "ok": true|false,
  "enabled": true,
  "kill_switch_env": "BRAIN_DISABLE_MCP",
  "data": { ... },
  "error": {
    "code": "...",
    "reason": "...",
    "message": "...",
    "hint": "..."
  },
  "server": "<server_id>",
  "tool": "<tool_name>"
}
```

### Exit Codes & Retries

| Code | Meaning | Behavior |
|------|---------|----------|
| `0`  | Success | Pass payload to Redactor. |
| `1`  | Handled Error | Extract `error` JSON block from output and propagate. |
| `2`  | Misconfiguration | Fails validation (invalid registry, missing class). |
| `3`  | Policy Blocked | Tool forbidden by allowlist or kill-switch. |

**Retries (Transport Only)**: If the binary execution fails (non-zero exit without a valid JSON representation), the Adapter evaluates `McpCallRetryPolicy`. Typical HTTP timeout or pipe flush errors map to `transport_error`, triggering backoff up to 3 times.

### Budget Semantics

The generic **logical-call budget** applies seamlessly. `brain mcp:call` executes the adapter, decrementing the budget strictly once. Stdio-adapter transport retries (e.g., pipes failing) do NOT deduct extra budget counters.
