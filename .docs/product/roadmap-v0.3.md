---
name: "Product Roadmap v0.3"
description: "User-facing milestones for v0.3 — pivoting from infrastructure to product value"
type: roadmap
date: 2026-02-22
version: "0.3.0"
status: draft
---

# Product Roadmap v0.3

v0.2 delivered enterprise-grade infrastructure: quality gates, memory hygiene, multi-target compilation, 82 benchmarks, readiness checks. v0.3 pivots to **user-facing value** — making that infrastructure accessible, discoverable, and actionable for daily workflows.

## M1. Memory Dashboard (`brain memory:status`)

**Problem:** Memory health data (ledger, smoke tests, rank safety) exists but is buried in JSON artifacts under `.work/`. Users cannot quickly assess whether their agent's knowledge is healthy, stale, or degraded without parsing raw files.

**Success metric:** A single command shows memory health summary in under 2 seconds, with actionable recommendations (e.g. "3 probes failing — run hygiene").

**Scope:**
- In: Human-readable summary of ledger stats, smoke pass rate, rank safety verdict, last run timestamp, trend (improved/degraded/stable vs. previous run).
- Out: Interactive TUI, automated remediation, memory editing.

**Key risks:** MCP server availability; output usefulness depends on hygiene being run regularly.

**Infra dependency:** `memory:hygiene` artifacts (v0.2), vector-memory MCP server.

---

## M2. Docs Global Search with Trust Indicators

**Problem:** `brain docs` searches project docs effectively, but users managing multiple Brain projects (or consuming third-party includes) cannot search across boundaries. Downloaded external docs lack trust/freshness signals — users cannot tell if a doc is authoritative or outdated.

**Success metric:** Cross-project search returns results from 2+ doc roots with trust badges (local/downloaded/external, freshness age). User can find any doc in under 3 seconds regardless of origin.

**Scope:**
- In: `--global` multi-root search with trust/freshness column, staleness warning for downloaded docs older than 30 days, re-download prompt.
- Out: Federated search over network, automatic doc syncing, permission-based access control.

**Key risks:** TNTSearch index rebuild time across large doc sets; trust heuristics may produce false confidence.

**Infra dependency:** `brain docs --download` security pipeline (v0.2), staleness detection (git-first), link validation.

---

## M3. Release Flow Automation (`brain release:prepare`)

**Problem:** Releasing v0.2 required 10+ manual steps: version bumps in 3 repos, tag alignment, credential rotation check, readiness gate, bundle build, evidence pack generation. This is error-prone and takes 30+ minutes.

**Success metric:** Single command performs pre-release validation, version bump, cross-repo tag alignment, and evidence pack generation. Manual release time drops from 30+ minutes to under 5 (excluding CI wait).

**Scope:**
- In: Version bump across 3 composer.json files, `readiness:check` as prerequisite gate, tag creation with alignment verification, release capsule generation from template.
- Out: Pushing to remote (explicit user action), changelog generation, credential rotation (security boundary), Homebrew formula updates.

**Key risks:** Three-repo topology makes atomic version alignment fragile; partial failure mid-release leaves repos in inconsistent state.

**Infra dependency:** `readiness:check` (v0.2), release readiness pack template, repo topology knowledge.

---

## M4. Compilation Diff Preview (`brain compile --diff`)

**Problem:** After editing `.brain/node/` sources, users run `brain compile` blindly — they see success/failure but not what actually changed in the compiled output. Reviewing changes requires manual `git diff .claude/` after compile, which is noisy and lacks semantic grouping.

**Success metric:** `--diff` flag shows a grouped summary of compilation changes (added/removed/modified sections per agent/command/skill) before writing files. User can review and abort if unexpected.

**Scope:**
- In: Dry-run mode that computes diff without writing, grouped by component type (agents, commands, skills, includes), summary stats (lines added/removed per component).
- Out: Interactive approval per component, rollback capability, visual diff viewer.

**Key risks:** Diff computation doubles compile time; large Brain configs may produce overwhelming output.

**Infra dependency:** Compiler pipeline (v0.2), single-writer lock.

---

## Milestone Priority

| # | Milestone | Effort | User Impact | Risk |
|---|-----------|--------|-------------|------|
| M1 | Memory Dashboard | ~8h | Medium | Low |
| M2 | Docs Global Search | ~16h | Medium | Medium |
| M3 | Release Flow | ~24h | High | High |
| M4 | Compilation Diff | ~12h | High | Low |

## Recommended Start: M4 (Compilation Diff Preview)

**Why M4 first:**

1. **Highest impact-to-risk ratio.** Every Brain user compiles daily — this improves the core loop. M3 (release flow) has higher total impact but also higher risk and is used infrequently.
2. **Low risk, contained scope.** The compiler already produces output; adding a diff-before-write step is a pure addition with no existing behavior change. Failure mode is graceful (fall back to normal compile).
3. **Unlocks M3.** Release flow automation needs confidence that compile produces expected output. Diff preview gives that confidence, making M3 safer to build afterward.
4. **Natural sequence after M4:** M4 → M1 → M3 → M2. Each milestone builds user trust incrementally: see what changed (M4) → see memory health (M1) → automate releases (M3) → search everywhere (M2).
