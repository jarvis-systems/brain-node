---
name: "MCP Tool Policy"
description: "Canonical allowlist contract for Brain MCP toolset - defines which CLI commands can be exposed via MCP"
type: architecture
date: 2026-02-25
version: "1.1.0"
status: active
---

# MCP Tool Policy

This document defines the canonical policy for Brain MCP tool exposure.

## Agent Workflow (Gated Discovery)

For safe and token-efficient tool use, agents MUST follow this discovery-first workflow:

1. **Guardrails Check**: `brain mcp:guardrails`
   - Verify MCP is enabled and check remaining call budget.
2. **Server Discovery**: `brain mcp:list`
   - Identify available servers and their allowed tool names.
3. **Tool Inspection**: `brain mcp:describe --server=<id>`
   - Retrieve the specific input schema for tools on a chosen server.
4. **Gated Call**: `brain mcp:call --server=<id> --tool=<name> --input='<json>'`
   - Execute the tool with validated input. Use `--trace` for debugging.

**Governance Rule**: Never guess tool schemas. Always describe before calling to ensure contract compatibility and budget efficiency.

## Status

**PLANNING ONLY** — This policy does NOT implement Brain MCP yet. It's a contract to prevent tool surface bloat/drift before implementation.

## Canonical Sources

| Location | Type | Purpose |
|----------|------|---------|
| `cli/mcp-tools.allowlist.json` | Default | Ships with CLI package |
| `.brain-config/mcp-tools.allowlist.json` | Override | **Self-hosting only** |
| `.brain/config/mcp-tools.allowlist.json` | Override | Consumer project |

**Resolution order:**
1. `.brain-config/mcp-tools.allowlist.json` (self-hosting)
2. `.brain/config/mcp-tools.allowlist.json` (consumer override)
3. `cli/mcp-tools.allowlist.json` (CLI default)

**Important:** `.brain-config/` is a **self-hosting only** directory. It exists in the development repo for this project. Consumer projects use `.brain/config/` for overrides.

**If CLI default is missing:** CLI install is corrupted — reinstall `jarvis-brain/cli`.

## Policy Consumption

**Source-of-truth:** JSON allowlist files, resolved at runtime by `McpToolPolicyResolver`.

- **Resolver:** `BrainCore\Services\McpToolPolicy\FilePolicyResolver`
- **Not emitted into compile outputs** — policy is runtime configuration
- **Used by:** Future MCP server, optional CLI safety checks
- **Kill-switch:** `BRAIN_DISABLE_MCP=true` disables all tool emission

**Resolution:**
```php
$resolver = new FilePolicyResolver($projectRoot, $cliPackageDir);
$policy = $resolver->resolve(); // ResolvedPolicy DTO
```

**Wildcard patterns:** `never` supports `prefix:*` to block command groups (e.g., `make:*` blocks `make:command`, `make:master`, etc.)

## Policy v1 Summary

**STDIO-ONLY CLI EXECUTION** — MCP v1 is designed exclusively as purely functional CLI stdio wrappers. It exposes only read-only commands with no side effects.

### Explicit Non-goals
The Brain MCP implementation explicitly and intentionally DOES NOT implement or support:
- Background MCP servers
- Daemons or persistent processes
- `start`, `stop`, `status` lifecycle commands
- Process supervisors or service managers

**Terminology note**: In MCP v1, "server" means a **logical schema adapter** — a class that declares tool names, input schemas, and validation rules. It is never a running process or network endpoint.

### Schemas-as-Tools = Metadata Only

MCP schema definitions provide **descriptive metadata** for tools, NOT product integrations:

- **Purpose**: Describe tool inputs/outputs for agent discovery and validation
- **NOT**: API clients, SDK wrappers, or integration adapters
- **Contract**: Schema validates input structure before stdio call to external MCP server
- **External execution**: Actual tool logic runs in external MCP servers (via `uvx`, `npx`, etc.)

**Example**: `VectorMemorySchema` describes `search_memories` input parameters. The actual vector search is performed by the external `vector-memory-mcp` Python server, not by the Brain codebase.

### Vector-Task Schema Interpretation

The `vector-task` server exposes 3 tools for task management:

| Tool | Required | Purpose |
|------|----------|---------|
| `task_create` | `content`, `title` | Create new task with metadata |
| `task_get` | `task_id` | Retrieve single task by ID |
| `task_list` | none | Query tasks with filters/pagination |

**Agent usage**: Call `mcp:describe --server=vector-task` to get current input_schema. Schema fields are metadata only — actual task storage is handled by external `vector-task-mcp` Python server.

### Allowed Commands

| Command | Notes |
|---------|-------|
| `docs` | Documentation search |
| `diagnose` | System diagnostics |
| `status` | Brain status (redacted) |
| `list` | List MCP servers |
| `list:includes` | List compiled includes |
| `list:masters` | List agent masters |
| `memory:status` | Memory system status |

### Never via MCP

These commands are **never** exposed via Brain MCP:

| Command | Reason |
|---------|--------|
| `compile` | Changes filesystem, requires GO signal |
| `init` | Changes filesystem, prompts for input |
| `make:*` | Scaffolding requires SELF_DEV_MODE |
| `memory:hygiene` | Destructive, requires GO signal |
| `release:prepare` | Changes versions, requires GO PRE-PUB |
| `update` | Changes filesystem, requires GO signal |
| `add`, `detail` | Prompts for credentials |
| `board`, `lab`, `run`, `meeting`, `custom-run` | Experimental AI commands |
| `mcp:migrate` | Changes database schema |

### Kill-Switch

Set `BRAIN_DISABLE_MCP=true` to disable all Brain MCP tool emission.

## JSON Schema

```json
{
  "version": "1.0.0",
  "kill_switch_env": "BRAIN_DISABLE_MCP",
  "allowed": ["docs", "diagnose", ...],
  "never": ["compile", "init", ...],
  "clients": {
    "claude": {"enabled": true},
    "codex": {"enabled": true},
    ...
  },
  "overrides": {}
}
```

## Validation

Run `scripts/check-mcp-tool-policy.sh` to validate:

```bash
bash scripts/check-mcp-tool-policy.sh
```

This is also integrated into `audit-enterprise.sh` as Check 21.

## Programmatic Access

MCP v1 defines a stable programmatic interface for policy discovery.

### Budget Governance

MCP v1 implements a persistent call budget to prevent unbounded resource consumption and "denial of wallet" scenarios.

### Budget Strategy

- **Type:** `logical` (One logical intent = one budget unit).
- **Retry behavior:** Retries for transport failures do NOT further decrement the budget.
- **Scope:** Global per workspace (persisted).

### Persistence

Budget state is stored in the canonical runtime directory:
- **Location:** `memory/mcp-budget.json` (relative to project root).
- **Git Status:** Ignored (runtime state).
- **Format:** `{"used": N}`

### Reset Rules

1. **Manual Reset:** Deleting the budget file is a permitted manual reset.
2. **Programmatic Reset:** `brain mcp:budget-reset` safely resets the counter to 0.
3. **CI / Test Mode:** When `BRAIN_TEST_MODE=true` is active, the budget is isolated to `dist/tmp/mcp-budget.json` to prevent cross-run pollution.

### Kill-Switch Behavior

When `BRAIN_DISABLE_MCP=true` is set:
- MCP calls are blocked (existing behavior).
- Budget I/O is disabled (no writes to the budget file occur).

## Registry: `mcp:list`

Returns available MCP servers from the canonical registry.

**Command:**
```bash
brain mcp:list
```

**Resolution Order:**
1. `.brain-config/mcp-registry.json` (self-hosting)
2. `.brain/config/mcp-registry.json` (consumer)
3. `cli/mcp-registry.json` (CLI default)

**Stable Output Keys:**
- `enabled`: Global MCP status
- `servers`: Sorted list of server IDs and enabled flags
- `summary`: Counts of total and enabled servers
- `resolved_registry_path`: Active registry source path

### Inspector: `mcp:allowlist`

Returns the full resolved policy as a deterministic JSON object.

**Command:**
```bash
brain mcp:allowlist
```

**Stable Output Keys:**
- `allowed`: Sorted list of permitted commands
- `clients`: Map of client configurations
- `enabled`: Global activation state
- `kill_switch_env`: The ENV variable used for kill-switch
- `never`: Sorted list of strictly forbidden commands/patterns
- `resolved_path`: Path to the active policy source (redacted)
- `schema_version`: Policy version string

This command is used by future MCP server wrappers to discover available tools without re-implementing resolution logic.

## Future Expansion

The following mode-based expansions are **planned but NOT active** in v1:

| Mode | Would Add | Trigger |
|------|-----------|---------|
| SELF_DEV_MODE | `make:*` commands | `SELF_DEV_MODE=true` |
| GO_PRE_PUB | `compile`, `release:*`, `update` | Explicit GO signal |

These require explicit GO and compile changes before activation.

## Policy Consumption

**Source-of-truth:** JSON allowlist files, resolved at runtime by `McpToolPolicyResolver`.

**Resolver:** `BrainCore\Services\McpToolPolicy\FilePolicyResolver`
- Resolution order: `.brain-config/` → `.brain/config/` → CLI default
- Wildcard support: `make:*` in `never` blocks all `make:` prefixes
- Kill-switch: `BRAIN_DISABLE_MCP=true` disables all MCP emission

**Not emitted into compiled outputs.** Policy stays in source files for runtime resolution.

**Future use:** MCP server + optional CLI safety checks.

## No Tool-Name Leakage Policy

To prevent information disclosure and maintain strict security boundaries, MCP error responses must adhere to the following **strict leakage prevention rules**:

1. **Message Content**: Error messages (`error.message`) and hints (`error.hint`) MUST NOT mention any tool name OR server name (even the requested ones).
2. **Generic Hints**: Hints MUST be generic. 
   - **Required Format**: `Run: brain mcp:list ; brain mcp:describe --server=<server>`
3. **Payload Fields**: The top-level `server` and `tool` fields in the root JSON payload are permitted as they echo user-supplied input for client-side correlation.
4. **Policy Privacy**: No portions of the allowlist or denylist (internal policy state) should be printed in error outputs.

This ensures that unauthorized agents cannot "probe" the system to discover available tools or internal server configurations through error responses.

## Related

- `.docs/architecture/instruction-surfaces.md` — Surface map and model-tier mapping
- `.docs/product/08-permissions.md` — Permission model
- `.docs/product/04-security-model.md` — Security posture
