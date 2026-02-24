---
name: "Brain Tool Surface Contract"
description: "Canonical contract for Brain tool surface, ProjectDocs abstraction, Cookbook packaging, and mode-based capability exposure"
type: architecture
date: 2026-02-24
version: "1.0.0"
status: active
---

# Brain Tool Surface Contract

This document defines the canonical contract for Brain's tool surface — what agents see and can use.

## Status

**PLANNING CONTRACT** — Defines the surface map. MCP server is NOT implemented yet (future wrapper).

## Definitions

| Term | Definition |
|------|------------|
| **BrainDocs** | CLI tool (`brain docs`) for indexing, searching, validating `.docs/` documentation. Human-facing, read-only. |
| **ProjectDocs** | Project-owned documentation domain — `.docs/` content that describes the project (product, architecture, operations). Distinct from Brain product docs shipped with CLI. |
| **Cookbook** | Procedural knowledge packs (skills, recipes, patterns) embedded in compiled instructions or retrieved via MCP tools. Contains "how to" not "what is". |
| **Tool Surface** | The set of capabilities exposed to agents via CLI commands, MCP tools, or compiled instruction includes. |

## Source-of-Truth Hierarchy

| Layer | Location | VCS | Purpose |
|-------|----------|-----|---------|
| CANON docs | `.docs/` | Tracked | Project documentation (ProjectDocs) |
| CANON policies | `.brain-config/` (self-hosting) or `.brain/config/` (consumer) | Tracked | Override policies |
| CANON instructions | `.brain/node/*.php` | Tracked | Brain source (Agents, Commands, Skills) |
| BUILD outputs | `.claude/`, `.opencode/` | Gitignored | Compiled client configs |
| RUNTIME data | `.brain/memory/` | Gitignored | SQLite storage |

**Key invariant:** Never write to BUILD or RUNTIME locations manually. Use CLI commands.

## BrainDocs vs ProjectDocs

### BrainDocs (CLI Tool)

The `brain docs` command is a documentation indexer and searcher:

```
brain docs "query"           # Search .docs/
brain docs --validate        # Validate front matter
brain docs --download=<url>  # Persist external docs
brain docs --undocumented    # Find code without docs
```

**Properties:**
- Read-only: never modifies `.docs/` content
- Indexes YAML front matter for search ranking
- Validates front matter (name, description required)
- Returns structured JSON for programmatic use

### ProjectDocs (Content Domain)

ProjectDocs is the content in `.docs/` — the actual documentation:

```
.docs/
├── product/         # Product briefs, features, releases
├── architecture/    # Design decisions, contracts
├── operations/      # Runbooks, procedures
├── instructions/    # Compile-time instruction docs
└── audits/          # Audit reports
```

**Relationship:** BrainDocs indexes ProjectDocs. Agents query BrainDocs to discover ProjectDocs content.

## Cookbook Packaging

Cookbook contains procedural knowledge for Brain operations.

### Location

| Source | Location | Access Method |
|--------|----------|---------------|
| Vector Memory | `mcp__vector-memory__cookbook()` | MCP tool call |
| Vector Task | `mcp__vector-task__cookbook()` | MCP tool call |
| Skills | `.brain/node/Skills/*.php` | Compiled includes |

### Compile-Time Presets

Cookbook presets are baked into compiled instructions at compile time:

```php
// In Brain.php or Agent
#[Includes(VectorMemoryInclude::class)]
#[Includes(VectorTaskInclude::class)]
```

Preset mode is determined by `STRICT_MODE` + `COGNITIVE_LEVEL`:

| Mode | Cookbook Depth |
|------|---------------|
| minimal | Essential cases only |
| standard | Standard cases + high priority |
| exhaustive | All cases + extended docs |

### Runtime Access

Agents access cookbook via MCP tools:

```
mcp__vector-memory__cookbook({"include": "init"})
mcp__vector-memory__cookbook({"include": "cases", "case_category": "search"})
mcp__vector-task__cookbook({"include": "init"})
```

**Governance:** See `Cookbook-governance` iron rule — no speculative pulls, use compile-time preset.

## Tool Exposure Matrix

### Mode Definitions

| Mode | Trigger | Scope |
|------|---------|-------|
| DEFAULT | Normal operation | Read-only, safe commands |
| SELF_DEV_MODE | `SELF_DEV_MODE=true` or autodetected | + Scaffolding tools |
| GO | Explicit "GO" signal from user | + Write/destructive tools |
| GO_PRE_PUB | Explicit "GO PRE-PUB" signal | + Release/publication tools |

### Command Categories

| Category | Commands | DEFAULT | SELF_DEV | GO | GO_PRE_PUB |
|----------|----------|:-------:|:--------:|:--:|:----------:|
| **READ-ONLY** | `docs`, `diagnose`, `status`, `list`, `list:includes`, `list:masters` | ✅ | ✅ | ✅ | ✅ |
| **MEMORY-READ** | `memory:status` | ✅ | ✅ | ✅ | ✅ |
| **SCAFFOLD** | `make:command`, `make:master`, `make:skill`, `make:script`, `make:include` | ❌ | ✅ | ✅ | ✅ |
| **INIT** | `init` | ❌ | ✅ | ✅ | ✅ |
| **WRITE** | `compile`, `update` | ❌ | ❌ | ✅ | ✅ |
| **DESTRUCTIVE** | `memory:hygiene` | ❌ | ❌ | ✅ | ✅ |
| **RELEASE** | `release:prepare` | ❌ | ❌ | ❌ | ✅ |
| **CREDENTIALS** | `add`, `detail` | ❌ | ❌ | ✅ | ✅ |
| **MIGRATION** | `mcp:migrate` | ❌ | ❌ | ✅ | ✅ |
| **EXPERIMENTAL** | `board`, `lab`, `run`, `meeting`, `custom-run` | ❌ | ❌ | ⚠️ | ⚠️ |

Legend: ✅ = allowed, ❌ = blocked, ⚠️ = allowed but experimental

### MCP Allowlist

MCP exposure follows the same matrix but is more restrictive. See `.docs/architecture/mcp-tool-policy.md`:

**v1 (current):** READ-ONLY only — `docs`, `diagnose`, `status`, `list`, `list:includes`, `list:masters`, `memory:status`

**Future:** SELF_DEV_MODE and GO expansions planned but NOT active.

### Kill-Switch

Set `BRAIN_DISABLE_MCP=true` to disable all Brain MCP tool emission.

## Explicit Non-Goals

| Non-Goal | Reason |
|----------|--------|
| MCP server implementation | DO LATER — CLI works reliably, laravel/mcp pre-1.0, Go rewrite pending |
| RAG over ProjectDocs | BrainDocs already provides search; vector memory handles semantic retrieval |
| Moving `.docs/` between projects | ProjectDocs is project-specific; BrainDocs indexes locally |
| Runtime cookbook expansion | Compile-time preset ensures determinism; runtime pulls are gated |
| Cross-project tool sharing | Tool surface is per-project; MCP allowlist is project-scoped |

## CLI Commands Reference (31 Total)

### CORE-AGENT (9)

| Command | Purpose |
|---------|---------|
| `docs` | Documentation search and validation |
| `diagnose` | System diagnostics |
| `status` | Brain status (redacted output) |
| `list` | List MCP servers |
| `list:includes` | List compiled includes |
| `list:masters` | List agent masters |
| `memory:status` | Memory system status |
| `script` | Run project scripts |
| `mcp:migrate` | MCP database migration |

### CORE-OPS (6)

| Command | Purpose |
|---------|---------|
| `compile` | Compile Brain to client configs |
| `init` | Initialize Brain in project |
| `update` | Update Brain components |
| `add` | Add MCP server credentials |
| `detail` | Show MCP server details |
| `release:prepare` | Prepare release |

### SELF-DEV (6)

| Command | Purpose |
|---------|---------|
| `make:command` | Scaffold new command |
| `make:master` | Scaffold new agent |
| `make:skill` | Scaffold new skill |
| `make:script` | Scaffold new script |
| `make:include` | Scaffold new include |

### EXPERIMENTAL (5)

| Command | Purpose |
|---------|---------|
| `board` | AI board (experimental) |
| `lab` | AI lab (experimental) |
| `run` | AI run (experimental) |
| `meeting` | AI meeting (experimental) |
| `custom-run` | Custom AI run (experimental) |

### PRE-PUB (2)

| Command | Purpose |
|---------|---------|
| `release:prepare` | Prepare publication release |
| `memory:hygiene` | Memory cleanup (destructive) |

## Related

- `.docs/architecture/instruction-surfaces.md` — Surface map and model-tier mapping
- `.docs/architecture/mcp-tool-policy.md` — MCP allowlist contract
- `.docs/architecture/self-hosting-workspace.md` — Self-hosting mode contract
- `.docs/instructions/REGISTRY.md` — Include chain and rule registry
