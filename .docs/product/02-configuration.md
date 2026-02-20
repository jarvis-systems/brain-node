---
name: "Configuration Reference"
description: "Environment variables, modes, pin strict policy, and configuration files"
type: "product"
version: "v0.1.0"
status: "active"
---

# Configuration Reference

## Environment Variables

All environment variables are set in `.brain/.env` (which resolves to `.env` via the `.brain` symlink).

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `LANGUAGE` | Any language | `Ukrainian` | Response language |
| `STRICT_MODE` | `relaxed`, `standard`, `strict`, `paranoid` | `standard` | Rule enforcement level |
| `COGNITIVE_LEVEL` | `minimal`, `standard`, `deep`, `exhaustive` | `standard` | Reasoning depth |
| `VERBOSITY` | `minimal`, `low`, `medium`, `high`, `maximum` | `medium` | Output detail level |
| `SELF_DEV_MODE` | `true`, `false` | `false` | Brain self-development mode |
| `PIN_STRICT` | `0`, `1` | `0` | MCP version pinning enforcement |

## Strict Mode

Controls how strictly Brain enforces its iron rules and quality gates.

| Mode | Behavior |
|------|----------|
| `relaxed` | Minimal enforcement, prototyping use |
| `standard` | Balanced enforcement for routine work |
| `strict` | Full enforcement for production features |
| `paranoid` | Maximum enforcement for security-critical and compliance work |

## Cognitive Level

Controls reasoning depth and thoroughness of analysis.

| Level | Behavior |
|-------|----------|
| `minimal` | Quick decisions, minimal analysis |
| `standard` | Standard analysis depth |
| `deep` | Thorough analysis with edge case consideration |
| `exhaustive` | Maximum depth, multi-probe verification |

## Pin Strict Policy

`PIN_STRICT` controls MCP package version enforcement at compile time.

| Value | Behavior |
|-------|----------|
| `0` | MCP packages use latest version (dev mode) |
| `1` | MCP packages pinned to versions from `pins.json` |

**`pins.json`** is the single source of truth for pinned versions. Located at project root.

When `PIN_STRICT=1`:
- `brain compile` appends `==version` to uvx package arguments
- `scripts/verify-pins.sh` validates `.mcp.json` against `pins.json`
- CI enforces pin policy via repository variable

**When to use PIN_STRICT=1:**
- Release builds
- CI pipelines
- Production deployments
- After MCP server version bump and validation

**When to use PIN_STRICT=0:**
- Local development
- Testing new MCP server versions
- Rapid iteration

## Configuration Files

| File | Purpose | Editable |
|------|---------|----------|
| `.env` / `.brain/.env` | Environment variables | Yes |
| `.env.example` | Environment template | Yes |
| `pins.json` | MCP version pins | Yes |
| `.mcp.json` | Compiled MCP configs | No (generated) |
| `composer.json` | Project metadata, version | Yes |
| `.claude/CLAUDE.md` | Compiled Brain output | No (generated) |
