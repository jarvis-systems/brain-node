---
name: "Installation Guide"
description: "Prerequisites, installation steps, and first-run verification for Brain"
type: "product"
version: "v0.1.0"
status: "active"
---

# Installation Guide

## Prerequisites

| Requirement | Version | Check |
|-------------|---------|-------|
| PHP | 8.2+ | `php -v` |
| ext-posix | * | `php -m \| grep posix` |
| ext-pcntl | * | `php -m \| grep pcntl` |
| Composer | 2.x | `composer --version` |
| Node.js | 20+ | `node -v` |
| npm | 9+ | `npm -v` |
| Python (uvx) | 3.10+ | `python3 --version` |
| jq | 1.6+ | `jq --version` |

## Install Brain CLI

```
composer global require jarvis-brain/cli
```

Verify: `brain --version`

## Install AI CLI (Claude Code)

```
npm install -g @anthropic-ai/claude-code
```

Verify: `claude --version`

## Install MCP Servers

MCP servers are invoked at runtime via `uvx` (Python) and `npx` (Node.js). No pre-installation needed — they download on first use.

**Pinned servers** (versions controlled via `pins.json`):
- `vector-memory-mcp` — Vector memory storage
- `vector-task-mcp` — Vector task management

**Unpinned servers** (latest):
- `@anthropic-ai/context7-mcp` — Context7 documentation
- `@anthropic-ai/sequential-thinking-mcp` — Sequential thinking

## First Compile

```
brain compile
```

This generates all compilation targets (claude, codex, opencode).

## Verify Installation

```
brain list              # List available CLI commands
brain compile --help    # Show compile options
composer benchmark:dry  # Validate benchmark scenarios (no LLM calls)
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `ext-posix` not found | `brew install php` (macOS) or enable in `php.ini` |
| `ext-pcntl` not found | Only available on Unix/macOS. Not supported on Windows. |
| `brain: command not found` | Add Composer global bin to PATH: `export PATH="$HOME/.composer/vendor/bin:$PATH"` |
| `uvx: command not found` | Install uv: `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| Compile fails silently | Enable debug: `BRAIN_CLI_DEBUG=1 brain compile` |
| MCP server timeout | Check network connectivity. MCP servers download packages on first run. |
