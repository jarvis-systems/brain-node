---
name: "MCP Tool Policy"
description: "Canonical allowlist contract for Brain MCP toolset - defines which CLI commands can be exposed via MCP"
type: architecture
date: 2026-02-24
version: "1.0.0"
status: active
---

# MCP Tool Policy

This document defines the canonical policy for Brain MCP tool exposure.

## Status

**PLANNING ONLY** — This policy does NOT implement Brain MCP yet. It's a contract to prevent tool surface bloat/drift before implementation.

## Location

| File | Purpose |
|------|---------|
| `config/brain/mcp-tools.yaml` | Machine-readable policy (repo-tracked) |
| `.docs/architecture/mcp-tool-policy.md` | This document (human-readable) |

## Policy v1 Summary

**READ-ONLY ONLY** — MCP v1 exposes only commands with no side effects.

### Allowed Categories

| Category | Commands | Notes |
|----------|----------|-------|
| DEFAULT_READONLY | `docs`, `diagnose`, `status`, `list`, `list:includes`, `list:masters` | Safe for all clients |
| OPTIONAL_READONLY | `memory:status` | Requires MCP server connection |

### Never via MCP

These commands are **never** exposed via Brain MCP:

- `compile` — Changes filesystem, requires GO signal
- `init` — Changes filesystem, prompts for input
- `make:*` — Scaffolding requires SELF_DEV_MODE
- `memory:hygiene` — Destructive, requires GO signal
- `release:prepare` — Changes versions, requires GO PRE-PUB
- `update` — Changes filesystem, requires GO signal
- `add`, `detail` — Prompts for credentials
- `board`, `lab`, `run`, `meeting`, `custom-run` — Experimental AI commands
- `mcp:migrate` — Changes database schema

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

Set `BRAIN_DISABLE_MCP=true` to disable all Brain MCP tool emission during compile.

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
