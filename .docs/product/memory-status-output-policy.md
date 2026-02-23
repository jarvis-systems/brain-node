---
name: "CLI Output Mode Policy"
description: "Deprecation path for consistent --json/--human flag symmetry across all CLI commands"
type: policy
date: 2026-02-23
version: "0.3.0"
status: draft
---

# CLI Output Mode Policy

## Problem

CLI commands use two competing conventions for output mode selection,
making behavior unpredictable for scripts and humans alike.

**Convention A** — human default, `--json` opt-in:
`memory:status`, `compile`

**Convention B** — JSON default, `--human` opt-in:
`readiness:check`, `release:prepare`, `diagnose`

**Convention C** — hybrid / JSON-only:
`memory:hygiene` (progress + unconditional JSON summary), `docs` (JSON-only),
`status` (JSON-only)

Users cannot predict which default a command uses without reading source code.

## Current Behavior Matrix (v0.3.0)

| Command            | `--json` | `--human` | Default   | Notes                                    |
|--------------------|----------|-----------|-----------|------------------------------------------|
| `memory:status`    | yes      | **no**    | human     | Dashboard; `--json` to opt-in            |
| `memory:hygiene`   | yes      | **no**    | hybrid    | `--json` suppresses progress; JSON summary always emitted |
| `readiness:check`  | yes*     | yes       | JSON      | `--json` is a no-op (already default)    |
| `release:prepare`  | yes*     | yes       | JSON      | `--json` is a no-op (already default)    |
| `compile`          | yes      | **no**    | human     | `--json` to opt-in                       |
| `diagnose`         | **no**   | yes       | JSON      | Missing `--json` flag                    |
| `docs`             | no       | no        | JSON-only | No mode flags at all                     |
| `status`           | no       | no        | JSON-only | No mode flags at all                     |

*Flag declared but redundant since JSON is already default.

**Symmetry gaps** (commands missing one flag of the pair):

- `memory:status` — missing `--human` (human is default, flag would be explicit no-op)
- `compile` — missing `--human` (same)
- `diagnose` — missing `--json` (JSON is default, flag would be explicit no-op)
- `memory:hygiene` — missing `--human` (would require implementing human summary)

## Recommendation: Split Policy

**JSON-default** for machine-oriented / pipeline commands:
`readiness:check`, `release:prepare`, `diagnose`, `docs`, `status`, `memory:hygiene`

**Human-default** for interactive dashboard commands:
`memory:status`, `compile`

### Why split, not unified

1. **Least surprise.** `readiness:check` output feeds `release:prepare` programmatically.
   Changing it to human-default would break existing pipelines. Conversely, `compile`
   is a human-facing build command — defaulting to JSON would degrade the experience.

2. **Semantic clarity.** Commands that produce structured reports (checks, diagnostics,
   release packs) are naturally JSON. Commands that run workflows with visual progress
   (compile, memory status) are naturally human.

3. **Minimal churn.** Only 1 command needs a default change: `memory:hygiene` should
   become JSON-default (it already outputs JSON summary unconditionally). No other
   defaults change.

### What changes for v0.4.0

Only `memory:hygiene` changes default behavior:

| Command          | v0.3.x default | v0.4.0 default | Change needed |
|------------------|----------------|----------------|---------------|
| `memory:status`  | human          | human          | none          |
| `memory:hygiene` | hybrid         | **JSON**       | add `--human` with progress view |
| `readiness:check`| JSON           | JSON           | none          |
| `release:prepare`| JSON           | JSON           | none          |
| `compile`        | human          | human          | none          |
| `diagnose`       | JSON           | JSON           | none          |

## Deprecation Plan

### v0.3.x — Flag symmetry (non-breaking)

Add missing flags as explicit no-ops to all dual-mode commands:

- `diagnose`: add `{--json}` (no-op, JSON is already default)
- `memory:status`: add `{--human}` (no-op, human is already default)
- `compile`: add `{--human}` (no-op, human is already default)

This lets users write `brain memory:status --human` today, which will continue
to work after any future default change. Scripts can lock in `--json` explicitly.

### v0.3.x — Deprecation warning for memory:hygiene (optional)

When `memory:hygiene` is called without explicit `--json` or `--human`:
emit a stderr warning that v0.4.0 will require an explicit flag.
Only emit when output is a TTY (not in pipelines).

### v0.4.0 — memory:hygiene becomes JSON-default

- Add `--human` flag with a human-readable summary view
- Default output becomes clean JSON (no progress messages)
- `--json` becomes explicit but redundant (same as readiness:check today)
- Remove deprecation warning

### v0.4.0 — Cleanup (optional)

- Remove no-op `--json` flags from JSON-default commands if desired
- Or keep them for explicitness (recommended — zero cost, aids discoverability)

## Implementation Checklist (v0.4.0)

- [ ] Add `--human` flag to `memory:hygiene` with human progress + summary view
- [ ] Make JSON the default output for `memory:hygiene` (suppress progress without flag)
- [ ] Verify all 8 dual-mode commands have both `--json` and `--human` flags
- [ ] Update `getHelp()` examples to show both flags for all commands
- [ ] Run `composer test` + `composer analyse` — all green
- [ ] Run `brain docs --validate` — 0 errors
- [ ] Update this doc status from `draft` to `active`

## Commands excluded from policy

Single-mode commands with no output format choice:

- `list`, `detail`, `add`, `init`, `update` — human-only (scaffolding/interactive)
- `make:*` — human-only (generators)
- `docs` — JSON-only (machine search tool, human mode not planned)
- `status` — JSON-only (debug introspection)
- `script` — passthrough (proxy to external process)
