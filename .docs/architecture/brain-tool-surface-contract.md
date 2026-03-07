---
name: "Brain Tool Surface Contract"
description: "Canonical contract for Brain tool surface, ProjectDocs abstraction, Cookbook packaging, and mode-based capability exposure"
type: architecture
date: 2026-02-24
version: "1.0.1"
status: active
---

# Brain Tool Surface Contract

Canonical contract for Brain's tool surface — what agents see and can use.

**Status:** PLANNING CONTRACT — MCP server is NOT implemented yet (future wrapper).

## Definitions

| Term | Definition |
|------|------------|
| **BrainDocs** | MCP tool (`mcp__brain-tools__docs_search`) for indexing/searching `.docs/`. Read-only. See `.docs/architecture/brain-docs-architecture.md`. |
| **ProjectDocs** | Project-owned documentation in `.docs/` (product, architecture, operations). Indexed by BrainDocs. |
| **Cookbook** | Procedural knowledge packs (skills, recipes) embedded in compiled instructions or via MCP tools. |
| **Tool Surface** | Capabilities exposed to agents via CLI commands, MCP tools, or compiled includes. |

## Source-of-Truth Hierarchy

| Layer | Location | VCS | Purpose |
|-------|----------|-----|---------|
| CANON docs | `.docs/` | Tracked | Project documentation |
| CANON policies | `.brain-config/` (self-hosting) / `.brain/config/` (consumer) | Tracked | Override policies |
| CANON instructions | `.brain/node/*.php` | Tracked | Brain source |
| BUILD outputs | `.claude/`, `.opencode/` | Gitignored | Compiled configs |
| RUNTIME data | `.brain/memory/` | Gitignored | SQLite storage |

**Invariant:** Never write to BUILD/RUNTIME manually. Use CLI commands.

## BrainDocs vs ProjectDocs

BrainDocs is the CLI indexer. ProjectDocs is the content it indexes.

```
mcp__brain-tools__docs_search({"query":"..."})  # Search .docs/
brain docs --validate                # Validate front matter (Direct CLI)
brain docs --download=<url>          # Persist external docs (Direct CLI)
brain docs --undocumented            # Find code without docs (Direct CLI)
```

**Details:** See `.docs/architecture/brain-docs-architecture.md` for design rationale, security model, and search scoring.

## Cookbook Packaging

| Source | Access | Mode Dependency |
|--------|--------|-----------------|
| Vector Memory | `mcp__vector-memory__cookbook()` | `STRICT_MODE` + `COGNITIVE_LEVEL` |
| Vector Task | `mcp__vector-task__cookbook()` | `STRICT_MODE` + `COGNITIVE_LEVEL` |
| Skills | `.brain/node/Skills/*.php` | Compiled includes |

**Governance:** `Cookbook-governance` iron rule — no speculative pulls. Use compile-time preset. See `.docs/instructions/REGISTRY.md` for include chain.

## Programmatic Tool Invocation

For PHP code that needs to execute Brain tools (future MCP server, internal services):

- **Use:** `BrainCore\Contracts\BrainToolInvoker` interface
- **Backend:** `BrainCore\Services\BrainCliInvoker` (CLI execution via Process)
- **Future:** MCP wrapper backend (not yet implemented)

**Methods:** `docsSearch()`, `diagnose()`, `status()`, `listIncludes()`, `listMasters()`, `readinessCheck()`

**Contract:** All methods return structured arrays. Secret patterns are automatically redacted. Invalid JSON throws typed exception.

## Tool Exposure Matrix

### Mode Definitions

| Mode | Trigger | Scope |
|------|---------|-------|
| DEFAULT | Normal operation | Read-only, safe commands |
| SELF_DEV_MODE | `SELF_DEV_MODE=true` or autodetected | + Scaffolding tools |
| GO | Explicit "GO" signal | + Write/destructive tools |
| GO_PRE_PUB | Explicit "GO PRE-PUB" signal | + Release/publication tools |

### Capability Matrix

| Category | DEFAULT | SELF_DEV | GO | GO_PRE_PUB |
|----------|:-------:|:--------:|:--:|:----------:|
| READ-ONLY (`docs`, `diagnose`, `status`, `list*`) | ✅ | ✅ | ✅ | ✅ |
| SCAFFOLD (`make:*`, `init`) | ❌ | ✅ | ✅ | ✅ |
| WRITE (`compile`, `update`, `add`, `detail`) | ❌ | ❌ | ✅ | ✅ |
| DESTRUCTIVE (`memory:hygiene`) | ❌ | ❌ | ✅ | ✅ |
| RELEASE (`release:prepare`) | ❌ | ❌ | ❌ | ✅ |
| EXPERIMENTAL (`board`, `lab`, `run`, `meeting`) | ❌ | ❌ | ⚠️ | ⚠️ |

Legend: ✅ allowed, ❌ blocked, ⚠️ experimental

### MCP Allowlist

MCP v1 exposes READ-ONLY only. See `.docs/architecture/mcp-tool-policy.md` for canonical allowlist and kill-switch (`BRAIN_DISABLE_MCP=true`).

**Policy resolver:** `BrainCore\Services\McpToolPolicy\FilePolicyResolver` — runtime resolution from JSON allowlist, not emitted into compiled outputs.

## CLI Commands Summary

| Category | Count | Key Commands |
|----------|------:|--------------|
| CORE-AGENT | 9 | `docs`, `diagnose`, `status`, `list*`, `memory:status` |
| CORE-OPS | 6 | `compile`, `init`, `update`, `add`, `detail`, `release:prepare` |
| SELF-DEV | 5 | `make:command`, `make:master`, `make:skill`, `make:script`, `make:include` |
| EXPERIMENTAL | 5 | `board`, `lab`, `run`, `meeting`, `custom-run` |
| PRE-PUB | 2 | `release:prepare`, `memory:hygiene` |

**Authoritative list:** Run `brain mcp:list` or see `.docs/architecture/mcp-tool-policy.md` § Allowed Commands.

## Explicit Non-Goals

| Non-Goal | Reason |
|----------|--------|
| MCP server implementation | DO LATER — CLI reliable, laravel/mcp pre-1.0 |
| RAG over ProjectDocs | BrainDocs + vector memory cover search |
| Moving `.docs/` between projects | ProjectDocs is project-specific |
| Runtime cookbook expansion | Compile-time preset ensures determinism |

## Related

- `.docs/architecture/instruction-surfaces.md` — Surface map, model-tier mapping
- `.docs/architecture/mcp-tool-policy.md` — MCP allowlist contract
- `.docs/architecture/self-hosting-workspace.md` — Self-hosting mode
- `.docs/architecture/brain-docs-architecture.md` — BrainDocs design
- `.docs/instructions/REGISTRY.md` — Include chain, rule registry
