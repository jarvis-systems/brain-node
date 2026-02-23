---
name: "CLI Output Mode Policy"
description: "Split policy for consistent --json/--human flag symmetry across all CLI commands"
type: policy
date: 2026-02-23
version: "0.4.0"
status: active
---

# CLI Output Mode Policy

## Problem (v0.3.x)

CLI commands used two competing conventions for output mode selection,
making behavior unpredictable for scripts and humans alike.

**Convention A** — human default, `--json` opt-in:
`memory:status`, `compile`

**Convention B** — JSON default, `--human` opt-in:
`readiness:check`, `release:prepare`, `diagnose`

**Convention C** — hybrid / JSON-only:
`memory:hygiene` (progress + unconditional JSON summary), `docs` (JSON-only),
`status` (JSON-only)

## Resolution: Split Policy (v0.4.0)

**JSON-default** for machine-oriented / pipeline commands:
`readiness:check`, `release:prepare`, `diagnose`, `memory:hygiene`, `docs`, `status`

**Human-default** for interactive dashboard commands:
`memory:status`, `compile`

### Why split, not unified

1. **Least surprise.** `readiness:check` output feeds `release:prepare` programmatically.
   Changing it to human-default would break pipelines. Conversely, `compile`
   is a human-facing build command — defaulting to JSON would degrade the experience.

2. **Semantic clarity.** Commands that produce structured reports (checks, diagnostics,
   release packs) are naturally JSON. Commands that run workflows with visual progress
   (compile, memory status) are naturally human.

3. **Minimal churn.** Only 1 command changed default: `memory:hygiene` moved from
   hybrid (progress + JSON summary) to clean JSON-default with `--human` opt-in.

## Current Behavior Matrix (v0.4.0)

| Command            | `--json` | `--human` | Default | Notes                                    |
|--------------------|----------|-----------|---------|------------------------------------------|
| `memory:status`    | yes      | yes       | human   | Dashboard; `--json` to opt-in            |
| `memory:hygiene`   | yes*     | yes       | JSON    | `--human` for progress view; `--json` is compat no-op |
| `readiness:check`  | yes*     | yes       | JSON    | `--json` is a compat no-op               |
| `release:prepare`  | yes*     | yes       | JSON    | `--json` is a compat no-op               |
| `compile`          | yes      | yes       | human   | `--json` to opt-in; `--human` is no-op   |
| `diagnose`         | yes      | yes       | JSON    | `--json` is a compat no-op               |
| `docs`             | no       | no        | JSON    | JSON-only (machine search tool)          |
| `status`           | no       | no        | JSON    | JSON-only (debug introspection)          |

*Flag accepted for compatibility / explicitness but redundant (JSON is already default).

All dual-mode commands now have both `--json` and `--human` flags for full symmetry.

## Change Log

### v0.3.x — Flag symmetry (non-breaking prep)

Added missing no-op flags to establish symmetry before default change:

- `diagnose`: added `{--json}` (no-op, JSON already default)
- `memory:status`: added `{--human}` (no-op, human already default)
- `compile`: added `{--human}` (no-op, human already default)

### v0.4.0 — memory:hygiene becomes JSON-default (breaking)

- Added `--human` flag with human-readable progress output
- Flipped guards from `! option('json')` to `option('human')`
- Default (no flags) now outputs clean JSON summary only
- `--json` kept as explicit compat alias (same as default)
- Golden tests lock both modes and regression-test the guard pattern

## Commands excluded from policy

Single-mode commands with no output format choice:

- `list`, `detail`, `add`, `init`, `update` — human-only (scaffolding/interactive)
- `make:*` — human-only (generators)
- `docs` — JSON-only (machine search tool, human mode not planned)
- `status` — JSON-only (debug introspection)
- `script` — passthrough (proxy to external process)
