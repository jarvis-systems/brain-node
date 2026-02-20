---
name: "Product Overview"
description: "Architecture overview of Brain — declarative prompt compiler for AI agent orchestration"
type: "product"
version: "v0.1.0"
status: "active"
---

# Product Overview

## What Brain Is

Brain is a **declarative prompt compiler** that transforms PHP source definitions into platform-specific AI agent configurations. It converts structured archetypes (Brain, Agents, Skills, Commands, Includes, MCP) into compiled artifacts consumed by AI CLI tools.

Brain is a **build-time tool**, not a runtime service. It produces static artifacts that AI agents read at startup.

## What Brain Is NOT

- Not a SaaS platform or hosted service
- Not an API server or runtime daemon
- Not a chat interface or LLM wrapper
- Not a package manager for AI models

## Architecture

**Source → Compile → Artifacts → AI CLI**

1. **Source** (`.brain/node/*.php`): PHP classes defining agent behavior, rules, guidelines, MCP configs
2. **Compile** (`brain compile`): Brain CLI reads sources, merges includes, applies builders
3. **Artifacts** (`.claude/`, `.mcp.json`): Platform-specific output files
4. **AI CLI** (Claude Code, Codex, etc.): Reads artifacts as system instructions

## Components

| Component | Package | Role |
|-----------|---------|------|
| Core | `jarvis-brain/core` | DTO blueprints, merger, format builders (XML/JSON/YAML/TOML) |
| Node | `jarvis-brain/node` | Executable archetypes, project-specific definitions |
| CLI | `jarvis-brain/cli` | Compile command, scaffolding generators, docs tool |

## Compilation Targets

| Target | Format | Output |
|--------|--------|--------|
| claude | XML | `.claude/CLAUDE.md` |
| codex | JSON | `.codex/CODEX.json` |
| qwen | YAML | `.qwen/QWEN.yaml` |
| gemini | JSON | `.gemini/GEMINI.json` |

## Archetypes

- **Brain**: Main orchestrator. Delegates tasks, never executes directly.
- **Agents**: Specialized execution units invoked by Brain via Task tool.
- **Skills**: Reusable capability modules shared across agents.
- **Commands**: User-triggered slash commands (e.g., `/commit`).
- **Includes**: Compile-time fragments merged into targets. Not visible at runtime.
- **MCP**: Model Context Protocol server configurations.
