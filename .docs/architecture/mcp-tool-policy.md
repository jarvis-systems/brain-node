---
name: "MCP Tool Policy"
description: "Canonical allowlist contract for Brain MCP toolset - defines which CLI commands can be exposed via MCP"
type: architecture
date: 2026-02-24
version: "1.0.1"
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
| `.brain/mcp-tools.allowlist.json` | Override | Project-specific (self-hosting) |

**Resolution order:**
1. `.brain/mcp-tools.allowlist.json` (if exists) → project override
2. `cli/mcp-tools.allowlist.json` → CLI default

**Note:** `.brain/` is a symlink to project root in self-hosting mode. In consumer projects, `.brain/` is a real directory created by `brain init`.

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

### Per-Client Enablement

All supported clients get Brain MCP by default:

| Client | Enabled | Categories |
|--------|---------|------------|
| Claude | Yes | DEFAULT_READONLY + OPTIONAL_READONLY |
| Codex | Yes | DEFAULT_READONLY |
| OpenCode | Yes | DEFAULT_READONLY + OPTIONAL_READONLY |
| Gemini | Yes | DEFAULT_READONLY |
| Qwen | Yes | DEFAULT_READONLY |

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
    "claude": {"enabled": true, "categories": ["DEFAULT_READONLY", "OPTIONAL_READONLY"]},
    ...
  }
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

## Related

- `.docs/architecture/instruction-surfaces.md` — Surface map and model-tier mapping
- `.docs/product/08-permissions.md` — Permission model
- `.docs/product/04-security-model.md` — Security posture
