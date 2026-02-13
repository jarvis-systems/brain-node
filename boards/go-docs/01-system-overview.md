---
name: "System Overview"
description: "High-level architecture of the Brain orchestration system: PHP reality and Go design target"
part: 1
type: "architecture"
date: "2026-02-13"
version: "1.0.0"
---

# System Overview

## What Is Brain

Brain is a **declarative configuration compiler** for AI agent orchestration. It takes PHP source files describing agents, commands, skills, and includes, and compiles them into target-specific output (XML for Claude, JSON for Codex/Gemini, YAML for Qwen, TOML experimental).

**It is NOT a runtime.** Brain produces static configuration artifacts that AI platforms consume. The "orchestration" happens at the AI platform level, guided by the compiled instructions.

## Two-Package Architecture

### Package 1: `jarvis-brain/core` (Library)
- Namespace: `BrainCore\`
- DTO-based blueprints for configuration structure
- Merger system for flattening include chains
- Format builders (XmlBuilder, TomlBuilder)
- Compilation pseudo-syntax generators (Runtime, Operator, Store, Tools)
- PHP Attributes (#[Meta], #[Purpose], #[Includes])
- MCP transport definitions (Stdio, Http, SSE)
- Variation presets (Scrutinizer brain, Master agent)
- ~160 PHP files

### Package 2: `jarvis-brain/node` (Project)
- Namespace: `BrainNode\`
- User-defined components that extend Core archetypes
- Brain.php (main orchestrator definition)
- Agents/*.php (8 agent definitions)
- Commands/*.php (27 command definitions)
- Mcp/*.php (6 MCP server configs)
- Skills/*.php (empty, user-extensible)
- Includes/*.php (empty, user-extensible)
- ~44 PHP files

### Package 3: Brain CLI (Standalone App)
- Separate Laravel-based CLI application
- Handles compilation, scaffolding, documentation indexing
- Located in `cli/` (or `.brain/cli/`)
- ~112 PHP files
- Entry point: `bin/brain`

## Data Flow

```
Source PHP files (.brain/node/*.php)
  │
  ├── PHP Attributes extracted (#[Meta], #[Purpose], #[Includes])
  ├── handle() method executed → builds DTO tree
  ├── Includes resolved recursively (max 255 depth)
  │
  ▼
DTO Tree (Bfg\Dto hierarchy)
  │
  ├── Merger flattens include chains
  ├── Merges children by element+identifier matching
  │
  ▼
Flat Associative Array
  │
  ├── XmlBuilder → XML/Markdown hybrid → .claude/CLAUDE.md
  ├── JsonBuilder → JSON → .codex/, .gemini/
  ├── TomlBuilder → TOML → experimental
  │
  ▼
Compiled Output (read-only artifacts)
  ├── .claude/CLAUDE.md (Brain config)
  ├── .claude/agents/*.md (per-agent)
  ├── .claude/commands/*.md (per-command)
  ├── .claude/skills/*.md (per-skill)
  └── .mcp.json (MCP server configs)
```

## Compilation Variable Substitution

During compilation, placeholder variables like `{{ PROJECT_DIRECTORY }}` are replaced with actual values. This happens via the `Runtime` class constants and the `Brain::getVariables()` + env system.

## Key Design Decisions (PHP)

1. **DTO-based**: All blueprints extend `Bfg\Dto\Dto` (third-party library) - provides `toArray()`, `fromEmpty()`, `fromAssoc()`, events
2. **PHP Attributes for metadata**: `#[Meta]`, `#[Purpose]`, `#[Includes]` - extracted via reflection at instantiation
3. **Builder pattern for rules/guidelines**: Fluent API (`$this->rule('id')->critical()->text(...)`)
4. **Include = compile-time merge**: Not runtime composition - includes disappear after compilation
5. **Pseudo-syntax compilation**: PHP static methods compile to human-readable instruction language (IF/FOREACH/TASK/STORE etc.)
6. **Facade pattern**: `Brain` facade wraps `Core` singleton for variable storage and env access

## Go Design Target

The Go version should implement the same compilation pipeline:
1. **Source parsing**: Read PHP-like or Go-native configuration files
2. **DTO tree construction**: Build typed struct hierarchy
3. **Include resolution**: Recursive merge with depth limit
4. **Format building**: Multiple output formats
5. **Variable substitution**: Template engine for placeholders

**Critical**: The Go version replaces the PHP compiler, NOT the AI runtime. Output format must be identical.
