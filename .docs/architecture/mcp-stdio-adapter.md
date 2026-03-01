---
name: "MCP Stdio Adapter"
description: "Canonical execution contract for MCP v1 Stdio wrapping and brain-tools internal MCP server"
type: architecture
date: 2026-02-27
version: "1.1.0"
status: active
---

# MCP Stdio Adapter Contract

The Brain MCP v1 implementation treats external MCP servers strictly as CLI `stdio` tools. This document defines the canonical boundaries for how Brain orchestrates, spawns, and parses responses from external tools.

## BrainTools MCP Server (Internal)

**brain-tools** is the canonical stdio-only MCP adapter over BrainCLI commands. It exposes Brain functionality via JSON-RPC 2.0 without daemons, registries, or external dependencies.

### Design Principles

- **No Daemons**: Single-request execution. Each MCP call is one CLI invocation.
- **No Registry**: No mcp:list/describe/call concepts. Direct tool invocation only.
- **In-Process Execution**: Uses Artisan/Kernel + BufferedOutput, never shell_exec/proc_open.
- **Stdout-Only**: All responses are JSON-RPC on stdout. Stderr is byte-empty in normal mode.

### ONLY ENTRYPOINT

**Clients MUST use `mcp:serve` as the ONLY entrypoint for brain-tools.**

```bash
php cli/bin/brain mcp:serve
```

This is the single canonical entrypoint for all brain-tools MCP operations:
- `docs_search` → via `mcp:serve` with `tools/call` JSON-RPC method
- `diagnose` → via `mcp:serve` with `tools/call` JSON-RPC method
- `list_masters` → via `mcp:serve` with `tools/call` JSON-RPC method

**BrainMcpBridge** (used by clients when `BRAIN_CLIENT_MCP=1`) spawns ONLY:
```
php cli/bin/brain mcp:serve
```

### FORBIDDEN (brain-tools Internal)

The following are FORBIDDEN for brain-tools internal operations:

| Forbidden | Reason |
|-----------|--------|
| `mcp:list` | External MCP only (context7, vector-memory) |
| `mcp:describe` | External MCP only (context7, vector-memory) |
| `mcp:call` | External MCP only (context7, vector-memory) |
| `shell_exec/proc_open` in serve path | Must use in-process dispatch |
| `node/Mcp/*` classes for brain-tools | brain-tools is CLI-only |

**NOTE:** `mcp:list`, `mcp:call`, `mcp:describe` are legitimate CLI commands for EXTERNAL MCP servers (context7, vector-memory, etc.). They are only forbidden for brain-tools internal routing.

### I/O Contract

**One request → One response. No extras.**

| Constraint | Requirement |
|------------|-------------|
| stdout | Exactly 1 JSON-RPC response object per request |
| stderr | Must be byte-empty (0 bytes) for ALL paths |
| Framing | Single line, single JSON object, no banners/debug |

**Stdout Format:**

Success:
```json
{"jsonrpc":"2.0","id":<id>,"result":{...}}
```

Error:
```json
{"jsonrpc":"2.0","id":<id>,"error":{"code":<int>,"message":"...","data":{"reason":"...","hint":"..."}}}
```

**Stable Error Codes:**

| Code | Name | Message | Reason |
|------|------|---------|--------|
| -32700 | PARSE_ERROR | "Parse error" | Invalid JSON input |
| -32600 | INVALID_REQUEST | "Invalid Request" | Missing required field |
| -32601 | METHOD_NOT_FOUND | "Method not found" | Unknown method name |
| -32602 | INVALID_INPUT | "Invalid params" | INVALID_INPUT (unknown tool/arg) |
| -32001 | MCP_DISABLED | "MCP operations are disabled..." | MCP_DISABLED (kill-switch) |

**Enforcement:** Check 53 validates all 10 framing/I/O scenarios.

### Non-goals (Hard Boundaries)

brain-tools is a thin adapter. These are permanently out of scope:

- **No background servers/daemons/supervisors** — Single stdio process per request
- **No MCP discovery/call layer** — mcp:serve is the only entrypoint
- **No duplicate implementations** — All logic lives in existing CLI commands (DocsCommand, DiagnoseCommand, ListMastersCommand)
- **No new tools** — Exactly 3 tools: docs_search, diagnose, list_masters
- **No shell execution** — All dispatch is in-process via ArrayInput + BufferedOutput

### Thin Adapter Lock (Drift Prevention)

The following constraints are enforced by automated checks:

1. **Only mcp:serve exists for brain-tools** — No other entrypoint for brain-tools internal tools
2. **No brain-tools wrapper commands** — These files are FORBIDDEN in `cli/src/Console/Commands/`:
   - `McpDocsSearchCommand.php` — would shadow docs_search
   - `McpDiagnoseCommand.php` — would shadow diagnose
   - `McpListMastersCommand.php` — would shadow list_masters
   
   NOTE: `mcp:list`, `mcp:call`, `mcp:describe`, etc. are for EXTERNAL MCP servers (context7, vector-memory) and are NOT forbidden.
3. **No node/Mcp server classes for brain-tools** — brain-tools is CLI-only
4. **Toolset freeze** — tools/list returns EXACTLY `["docs_search", "diagnose", "list_masters"]` in this order
5. **Mapping freeze** — Internal routing must map:
   - `docs_search` → `DocsCommand::class`
   - `diagnose` → `DiagnoseCommand::class`
   - `list_masters` → `ListMastersCommand::class`

### Invocation

```bash
php cli/bin/brain mcp:serve
```

**IMPORTANT: Always use the repo-local entrypoint `cli/bin/brain`. Never use the global composer stub `brain`.**

Reads JSON-RPC 2.0 requests from stdin, writes responses to stdout.

### Canonical Invocation

**In scripts:** Source `scripts/lib/brain-cli.sh` and use `brain_cli`:

```bash
source scripts/lib/brain-cli.sh
brain_cli mcp:serve
brain_cli docs --validate
```

**Direct invocation:**
```bash
php cli/bin/brain mcp:serve
```

**Never use:**
- `brain ...` — global composer stub, version mismatch risk
- `php vendor/bin/brain ...` — wrong for this repo structure

### Available Tools

| Tool | Description | CLI Command |
|------|-------------|-------------|
| `docs_search` | Search Brain documentation | `brain docs` |
| `diagnose` | Get Brain environment diagnostics | `brain diagnose --json` |
| `list_masters` | List available subagent masters | `brain list:masters --json` |

### Examples

**Initialize:**
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | php cli/bin/brain mcp:serve
# {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":[]},"serverInfo":{"name":"brain-tools","version":"1.0.0"}}}
```

**List Tools:**
```bash
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | php cli/bin/brain mcp:serve
# {"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"docs_search",...},{"name":"diagnose",...},{"name":"list_masters",...}]}}
```

**Call docs_search:**
```bash
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"docs_search","arguments":{"query":"mcp","limit":2}}}' | php cli/bin/brain mcp:serve
# {"jsonrpc":"2.0","id":3,"result":{"content":{"type":"text","text":"{\"schema_version\":2,...}"}}}
```

### Kill-Switch

Set `BRAIN_DISABLE_MCP=true` to block tools/call operations. Initialize remains allowed for capability discovery.

```bash
BRAIN_DISABLE_MCP=true php cli/bin/brain mcp:serve <<< '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"diagnose","arguments":{}}}'
# {"jsonrpc":"2.0","id":1,"error":{"code":-32001,"message":"MCP operations are disabled.","data":{"reason":"MCP_DISABLED",...}}}
```

### docs_search Arguments

**docs_search is a thin adapter to `brain docs` and supports the same options 1:1.**

| Argument | Type | Description |
|----------|------|-------------|
| `keywords` | array | Search keywords (OR logic, case-insensitive) |
| `query` | string | Search query string (shorthand; maps to keywords as single element) |
| `limit` | int | Max results (0 = unlimited, default: 5) |
| `exact` | string | Exact phrase search (case-insensitive, use strict for case-sensitive) |
| `strict` | bool | Make exact case-sensitive |
| `headers` | int | Extract headers with line ranges (1=H1, 2=H1+H2, 3=H1+H2+H3, default: 0) |
| `stats` | bool | Include file stats (lines, words, size, hash) |
| `code` | bool | Extract code blocks with detected language and line ranges |
| `snippets` | bool | Include preview of header section content (max 200 chars) |
| `links` | bool | Extract internal/external links from document |
| `extract-keywords` | bool | Extract top 10 frequent terms (maps to --keywords in CLI) |
| `matches` | bool | Show keyword match locations with context |
| `undocumented` | bool | Scan codebase for classes/methods without docs |
| `download` | string | Download doc from URL to .docs/sources/ |
| `as` | string | Filename for download (default: URL basename) |
| `update` | bool | Update all downloaded docs from their source URLs |
| `validate` | bool | Validate documentation files for required fields and quality |
| `scaffold` | string | Scaffold doc files for undocumented classes (or specific class name) |
| `global` | bool | Search all .docs/ folders in project subdirectories |
| `freshness` | int | Include only docs modified within N days (0 = no filter) |
| `trust` | string | Minimum trust level: low, med, high |
| `cache` | string | Cache mode: on (default), off (disable) |
| `cache-stats` | bool | Show cache statistics (entries, hit rate, timings) |
| `cache-health` | bool | Show cache health report with recommendations |
| `clear-cache` | bool | Clear the docs index cache |

Unknown arguments return `INVALID_INPUT` error (generic message, no key leakage).

### diagnose Arguments

**diagnose is a thin adapter to `brain diagnose` with no exposed arguments.**

The underlying command outputs JSON by default. The MCP tool forces `--json` for explicitness but accepts no client arguments.

| Argument | Type | Description |
|----------|------|-------------|
| *(none)* | - | No arguments exposed. Output is always JSON. |

### list_masters Arguments

**list_masters is a thin adapter to `brain list:masters` and supports the same options 1:1.**

| Argument | Type | Description |
|----------|------|-------------|
| `agent` | string | Agent type for compilation (default: `claude`). Values: `claude`, `codex`, `gemini`, `qwen` |

Unknown arguments return `INVALID_INPUT` error (generic message, no key leakage).

### Client Wiring

AI clients (Gemini, OpenCode, etc.) can use the Brain MCP server via the `BrainMcpBridge` service.

**Enable MCP mode for clients:**

```bash
export BRAIN_CLIENT_MCP=1
```

When enabled, clients route docs_search, diagnose, and list_masters operations through MCP instead of direct CLI calls. This provides a deterministic JSON-RPC surface for AI clients while the underlying CLI commands remain unchanged.

**Usage from PHP:**

```php
use BrainCLI\Services\Mcp\BrainMcpBridge;

if (BrainMcpBridge::isEnabled()) {
    $bridge = new BrainMcpBridge();
    
    // Search docs
    $results = $bridge->docsSearch(['query' => 'mcp', 'limit' => 5]);
    
    // Get diagnostics
    $diagnostics = $bridge->diagnose();
    
    // List masters
    $masters = $bridge->listMasters('claude');
}
```

**Key points:**

- Still CLI under the hood - no daemons, no registries
- Uses Symfony Process for stdio communication
- Maintains stderr hygiene (0 bytes in normal mode)
- Returns decoded JSON from underlying commands

---

## External MCP Servers (Stdio Wrapping)

## Language-Agnostic Model

MCP v1 is a **schemas-as-tools** architecture. The term "server" refers exclusively to a
**logical schema adapter** — a static descriptor of available tools, their input schemas,
and validation rules. It is NOT a running process, daemon, or network listener.

- **Transport**: `stdio` only. Every invocation is a single ephemeral CLI execution.
- **No lifecycle**: There is no `start`, `stop`, `status`, or supervisor concept.
- **Schema-first**: Each adapter declares tools via a deterministic schema class.
  The schema is the source of truth for tool discovery and input validation.

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

### Dry-Run Sanitization

The `--dry-run` flag provides a safe preview that MUST NOT expose sensitive infrastructure data:

- **Purpose**: Preview execution plan without side effects
- **Budget**: NOT decremented (safe to run repeatedly)
- **Execution**: NEVER executes external MCP server
- **Sanitization**: All sensitive flags/values replaced with `<REDACTED_ARG>`

**Sanitization Rules:**

1. Sensitive flag + value → single `<REDACTED_ARG>` token
2. Token-pattern values → `<REDACTED_ARG>` 
3. Absolute paths → `[REDACTED_PATH]`

See `.docs/architecture/mcp-tool-policy.md` for the complete sensitive keys list.
