---
name: "Worktree Isolation Contract"
description: "Plan-only governance contract for git worktree-based agent isolation in parallel (quad-mode) operations"
type: "contract"
date: "2026-02-21"
version: "1.0"
status: "plan"
---

# Worktree Isolation Contract

Status: **PLAN-ONLY** — not implemented. This document defines the target architecture for agent isolation. Implementation is tracked in FIX-QUEUE P2-009.

## 1. Goals

1. **Zero file clobbering** — parallel agents never overwrite each other's uncommitted work.
2. **Clean git history** — each agent's work lands as a clean, reviewable branch with no drift artifacts.
3. **Reproducible runs** — any agent session can be replayed from its branch without contamination from other sessions.

## 2. Non-Goals

- Full container sandboxing (Docker) — optional enhancement, not required for v1.
- Network isolation between agents — agents share the same network.
- Automated orchestration of worktrees — v1 is operator-managed, Brain-assisted.

## 3. Model

### 3.1 One Agent, One Branch, One Worktree

Each agent session operates in its own git worktree checked out to a dedicated branch. No two agents share a worktree. The root repo working directory is reserved for the operator (Doc) only.

### 3.2 Branch Naming

```
agent/<agent-name>/<ticket-or-scope>
```

Examples:
- `agent/model1/security-posture`
- `agent/model2/dd-cleanup`
- `agent/doc/scorecard-batch13`

### 3.3 Worktree Path Convention

```
.worktrees/<agent-name>/<ticket-or-scope>/
```

Example filesystem layout:
```
./                                    # Root repo (operator only)
.worktrees/
  model1/
    security-posture/                 # git worktree for model1's task
      .brain/ .claude/ core/ ...      # Full repo checkout
  model2/
    dd-cleanup/                       # git worktree for model2's task
      .brain/ .claude/ core/ ...
```

`.worktrees/` MUST be in `.gitignore`.

### 3.4 Shared Caches Policy

| Resource | Shared? | Rationale |
|----------|---------|-----------|
| `vendor/` (composer) | NO — each worktree has own | Prevents autoloader conflicts |
| `node_modules/` | NO — each worktree has own | Prevents version conflicts |
| `.brain/` config | NO — each worktree has own | Prevents compile race conditions |
| `memory/` (SQLite) | YES — shared via absolute path | Single vector memory for all agents |
| `dist/` (build output) | NO — each worktree has own | Prevents artifact clobbering |

## 4. Hard Rules (Iron)

### 4.1 Agent Never Works in Root Repo

Agent sessions MUST be started with `--workdir` pointing to their worktree. Any agent writing to the root repo is a protocol violation.

### 4.2 All Writes Inside Own Worktree

An agent may only create, edit, or delete files within its assigned worktree path. Cross-worktree writes are forbidden.

### 4.3 Artifacts Are Local

All build artifacts (`vendor/`, `node_modules/`, `dist/`, `.claude/` compiled output) live inside the agent's worktree. No shared artifact directories.

### 4.4 Compile Lock Still Applies

`brain compile` single-writer lock (flock) is per-worktree. Each worktree has its own `brain.lock`. This is automatically correct because `brain compile` locks relative to the working directory.

### 4.5 No Force Push

Agents NEVER force-push. Branch conflicts are resolved by the operator via merge or rebase in root repo.

## 5. Operator Command Cookbook

These commands are executed by the operator (Doc), not by agents automatically.

### Create Worktree

```bash
# Create branch + worktree for agent task
git worktree add .worktrees/model1/security-posture -b agent/model1/security-posture

# Install dependencies in worktree
cd .worktrees/model1/security-posture && composer install
```

### Remove Worktree

```bash
# After merge, clean up
git worktree remove .worktrees/model1/security-posture
git branch -d agent/model1/security-posture
```

### Status Check

```bash
# List all active worktrees
git worktree list

# Check for stale worktrees
git worktree prune --dry-run
```

### Cleanup All

```bash
# Remove all finished worktrees
git worktree prune
rm -rf .worktrees/*/  # Only after git worktree prune confirms safe
```

## 6. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Disk usage (full checkout per worktree) | ~100MB per worktree | Prune after merge; worktrees share git objects |
| Stale worktrees (forgotten after task) | Branch/disk clutter | Weekly `git worktree prune --dry-run` check |
| Branch cleanup lag | Old branches accumulate | `git branch --merged master` cleanup after each batch |
| Accidental force push from worktree | History corruption | Iron rule 4.5; `receive.denyNonFastForwards` on remote |
| Memory SQLite contention | Write locks under parallel access | WAL mode (already enabled); retry on SQLITE_BUSY |

## 7. Brain Integration Notes

### 7.1 Worktree Creation

Brain (or operator) creates the worktree BEFORE delegating to an agent. The agent receives `--workdir` pointing to its worktree as part of the Task delegation context.

### 7.2 Sub-Agent Workdir Propagation

When Brain delegates via `Task()`, the worktree path is passed as context. The sub-agent inherits the workdir and all tool calls (Bash, Read, Edit, Write) operate within it.

### 7.3 Race Condition Prevention

- Compile lock: per-worktree `brain.lock` (flock, automatic).
- Memory: SQLite WAL mode handles concurrent reads; writes are serialized by SQLite.
- Git operations: each worktree has independent HEAD, index, and working tree — no git-level races.

### 7.4 Merge Flow

```
agent/model1/task-a ──PR──→ master ←──PR── agent/model2/task-b
```

Merges happen in root repo (operator). Agents never merge to master directly.

## 8. Relationship to Existing Contracts

| Contract | Relationship |
|----------|-------------|
| Compile Safety Contract (`04-security-model.md`) | Worktree isolation makes single-writer lock per-worktree; compile races eliminated by filesystem separation |
| Quad-Mode Drift Policy (`ENTERPRISE-DOD.md`) | Worktree isolation PREVENTS drift at source; drift policy remains as detection fallback |
| Model 2 Operating Contract (`15-model2-operating-contract.md`) | Worktree is the execution environment for Model 2 agents |

## 9. Implementation Phases

| Phase | Scope | Prerequisite |
|-------|-------|-------------|
| v0 (current) | No isolation; quad-mode drift policy as safety net | — |
| v1 | Operator-managed worktrees; `.worktrees/` in `.gitignore`; manual `composer install` per worktree | This contract approved |
| v2 | Brain-managed worktrees; auto-create on Task delegation; auto-cleanup on task complete | v1 stable for 2+ weeks |
| v3 (optional) | Container-per-agent; network namespace isolation; resource limits | v2 stable; Docker available |

## 10. Cross-References

- Compile Safety: `.docs/product/04-security-model.md` § "Compile Safety Contract"
- Quad-Mode Drift: `.docs/audits/enterprise-codebase/ENTERPRISE-DOD.md` § "Quad-Mode Drift Policy"
- Model 2 Contract: `.docs/product/15-model2-operating-contract.md`
- Backlog: `.docs/audits/enterprise-codebase/FIX-QUEUE.md` P2-009
