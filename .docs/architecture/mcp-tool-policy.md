---
name: "MCP Tool Policy"
description: "Canonical allowlist contract for Brain MCP toolset - defines which CLI commands can be exposed via MCP"
type: architecture
date: 2026-02-24
version: "1.0.2"
status: active
---

# MCP Tool Policy

This document defines the canonical policy for Brain MCP tool exposure.

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

**READ-ONLY ONLY** — MCP v1 exposes only commands with no side effects.

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

## Related

- `.docs/architecture/instruction-surfaces.md` — Surface map and model-tier mapping
- `.docs/product/08-permissions.md` — Permission model
- `.docs/product/04-security-model.md` — Security posture
