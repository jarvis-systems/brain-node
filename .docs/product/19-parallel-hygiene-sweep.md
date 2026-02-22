---
name: "Parallel Hygiene Sweep Protocol"
description: "Repeatable 3-agent sweep to maintain docs, workspace, and memory invariants between batches"
type: product
date: 2026-02-22
version: "1.0.0"
status: active
---

# Parallel Hygiene Sweep Protocol

Keep velocity without sacrificing invariants. Run at the end of each batch or before a release demo.

## When to Run

- After every batch of 3+ commits
- Before running the Enterprise Demo Script (`18-enterprise-demo-script.md`)
- Before any GO PRE-PUB gate
- After quad-mode stabilization (parallel agents converge to master)

## Micro-Fix Batching Rule

When <=3 trivial fixes are identified during any batch (missing front matter, stale doc link, allowed artifact noise):

1. Delegate fix(es) to sub-agent(s) **in the same run** — do not defer to a separate batch.
2. Trivial = no behavioral change, no code edits, no CI gate impact. Examples: YAML front matter, doc counter, stale cross-reference.
3. Each sub-agent produces evidence: file list + `brain docs --validate` result.
4. If fix count >3 or any fix is non-trivial: defer to dedicated hygiene sweep.

This prevents micro-fix churn from accumulating across batches while keeping macro work unblocked.

## Sweep Agents

Three independent sub-agents run **concurrently**. No cross-dependencies.

### A. Docs Sweeper

**Gate:** `brain docs --validate` must return `invalid=0, warnings=0`.

Procedure:
1. Run `brain docs --validate`.
2. If any file is invalid: fix by adding missing YAML front matter and/or H1 header. No content rewrites.
3. If any file has warnings: fix the specific warning (usually missing H1).
4. Re-validate until gate is GREEN.

Scope: `.docs/` only. Never edits code or scripts.

### B. Workspace Sweeper

**Gate:** `git status --porcelain` must show only allowed untracked artifacts.

Procedure:
1. Run `git status --porcelain`.
2. Classify each item:

| Classification | Examples | Action |
|----------------|----------|--------|
| Allowed artifact | `.compile-stamp`, `.work/`, `.DS_Store` | KEEP — no action |
| Docs candidate | Untracked `.docs/*.md` without front matter | Flag for Docs Sweeper |
| Red flag | Untracked `.env`, secrets, unexpected binaries | INVESTIGATE — report to operator |

3. Output a classification table. **No automatic moves or deletions.**

**Default stance:** classify and report. NEVER propose `.gitignore` additions for workspace artifacts unless recurring high-frequency drift is proven across 3+ consecutive batches with operator confirmation. Signal value of visible untracked items outweighs convenience of silencing them.

Allowed artifacts policy: `.compile-stamp` (build stamp), `.work/` (scratch workspace). See `.docs/product/09-secrets.md` § Expected Local Workspace Artifacts.

### C. Vector Memory Hygiene Planner

**Gate:** Plan-only. No destructive actions without explicit GO PRE-PUB.

Procedure:
1. Gather stats: `mcp__vector-memory__get_memory_stats`.
2. Sample recent entries: `mcp__vector-memory__list_recent_memories` (limit=5).
3. Check tag health: `mcp__vector-memory__get_unique_tags`.
4. Propose options:

| Option | Action | Blast Radius | Rollback | Marker |
|--------|--------|-------------|----------|--------|
| Soft prune | `clear_old_memories` with conservative threshold | Old + low-access entries | NO | GO PRE-PUB |
| Tag cleanup | Search + delete by stale workflow tags | 30-60 ephemeral entries | NO | GO PRE-PUB per entry |
| Tag normalization | `tag_normalize_preview` then `tag_normalize_apply` | Tags only, no memory deletion | Partial | Safe (non-destructive) |
| Full reset | Clear all memories | ALL entries destroyed | NO | STOP — GO PRE-PUB CRITICAL |

5. Output plan with example commands (never executed).

STOP conditions:
- Memory store < 20 entries: no action needed.
- Any operation affects memories outside this project: STOP and flag.
- Database unhealthy: escalate to operator.

## Evidence Pack Format

Each sweep agent must produce:

```
## Agent: [A|B|C] — [docs-sweeper|workspace-sweeper|vector-memory-planner]
### Gate: [GREEN|RED]
### Files changed: [list or "none"]
### Summary: [1-2 sentences]
### Data: [validate JSON / classification table / stats snapshot]
```

## STOP Rules

| Condition | Effect |
|-----------|--------|
| `brain docs --validate` returns `invalid>0` | Blocks merge until fixed |
| `git status --porcelain` shows red-flag items | Blocks merge until classified |
| Vector memory destructive step proposed | Requires explicit GO PRE-PUB from operator |
| Any agent fails to complete | Report partial results; do not block other agents |

## WIP Branch Governance

When parallel work, quarantine, or operator WIP requires parking changes outside `master`, use dedicated `wip/*` branches.

### Naming Convention

```
wip/<scope>-<YYYYMMDD>-<topic>
```

| Segment | Values | Example |
|---------|--------|---------|
| `scope` | `root`, `core`, `cli`, `docs`, `ci` | `root` |
| `YYYYMMDD` | Creation date | `20260222` |
| `topic` | Short kebab-case descriptor | `claude-deprecation` |

Full example: `wip/root-20260222-claude-deprecation`.

Short form `wip/<scope>-<YYYYMMDD>` is acceptable when topic is obvious from commit message.

### Current Inventory

| Branch | Scope | Content | Owner |
|--------|-------|---------|-------|
| `wip/doc-architecture-20260222` | docs | brain-docs-architecture notes | Doc |
| `wip/quad-20260222-parallel-spec-suite` | root | Parallel isolation spec suite | Doc |

### Merge Rules

WIP branches are **NEVER merged blindly** into `master`. Integration path:

1. **Cherry-pick** specific commits with a Touch Whitelist declared in the merge batch.
2. Each cherry-pick produces an Evidence Pack (touch whitelist + gates).
3. After cherry-pick, delete the WIP branch (local + remote if pushed).
4. Direct `git merge wip/*` into `master` is **FORBIDDEN** — prevents unreviewed changes from slipping in.

### Expiry Policy

| Age | Action |
|-----|--------|
| ≤7 days | Active — no action |
| 8-14 days | Review: cherry-pick or mark `parking-long` with owner |
| >14 days | Delete unless explicitly marked `parking-long` |
| `parking-long` | Indefinite — owner responsible for cleanup |

### Operator Commands

```bash
# List all WIP branches
git branch --list 'wip/*'

# Inspect specific branch
git log --oneline master..wip/<branch-name>
git diff master...wip/<branch-name> --stat

# Delete local WIP branch
git branch -d wip/<branch-name>

# Delete remote WIP branch (if pushed)
git push origin --delete wip/<branch-name>
```

### CLAUDE.md Case

Root `CLAUDE.md` is a compiled artifact referenced by the Brain system. When operator edits CLAUDE.md directly (outside `brain compile`), the change MUST be quarantined to a WIP branch. Master's CLAUDE.md must always match the last `brain compile` output.

## Canonical References

| Document | Relationship |
|----------|-------------|
| `18-enterprise-demo-script.md` | Run sweep BEFORE demo |
| `10-pre-publication.md` | Sweep is a stabilization step before GO PRE-PUB |
| `17-worktree-isolation-contract.md` | Workspace Sweeper enforces worktree hygiene |
| `ENTERPRISE-DOD.md` § Operator Readiness | Sweep linked as operator checklist item |
