---
name: "Worktree Isolation Contract"
description: "Enterprise specification for git worktree-based agent isolation in parallel multi-agent operations"
type: "contract"
date: "2026-02-22"
version: "2.0"
status: "spec"
---

# Worktree Isolation Contract

Status: **SPEC** — approved architecture for agent isolation. Supersedes v1.0 (plan-only).

Research basis: `.docs/DocDiscovery/deep-research-report-isolation.md`, `.docs/DocDiscovery/deep-research-report-task-workflow.md`

Industry validation: Cursor (parallel agents in own worktrees), Windsurf Arena Mode (per-model worktrees), Codex CLI (OS-level sandbox + workspace scoping), GitHub Copilot coding agent (PR-based integration contract), Devin (parallel sessions in isolated environments).

## 1. Goals

1. **Zero file clobbering** — parallel agents never overwrite each other's uncommitted work.
2. **Clean git history** — each agent's work lands as a clean, reviewable branch with conventional commits.
3. **Reproducible runs** — any agent session can be replayed from its branch without contamination.
4. **Physical isolation** — filesystem-level separation replaces policy-only protection.
5. **Automated lifecycle** — worktree creation, dependency setup, and cleanup are orchestrator-managed (v2+).
6. **Seamless integration** — worktree isolation integrates with existing parallel task system (file manifests, scope registration, isolation checklist).

## 2. Non-Goals

- Full container sandboxing (Docker) — optional enhancement (v3), not required for v1/v2.
- Network isolation between agents — agents share the same network.
- OS-level sandbox (macOS Seatbelt) — complementary security layer, separate concern.
- Cross-repo worktrees — each repo (node, core, cli) manages worktrees independently per repo-topology invariant.

## 3. Model

### 3.1 One Agent, One Branch, One Worktree

Each agent session operates in its own git worktree checked out to a dedicated branch. No two agents share a worktree. The root repo working directory is reserved for the operator (Doc) and Brain orchestrator only.

Git enforces this by default: it refuses to create a worktree if the branch is already checked out elsewhere (without `--force`).

### 3.2 Branch Naming

```
ai/<agent-name>/<taskId>/<attempt>
```

Fields:
- `ai/` — namespace prefix separating agent branches from human branches
- `<agent-name>` — agent ID (e.g. `explore`, `web-research-master`, `prompt-master`)
- `<taskId>` — vector task ID or ticket reference (e.g. `task-42`, `security-posture`)
- `<attempt>` — attempt number for circuit breaker tracking (e.g. `a1`, `a2`, `a3`)

Examples:
- `ai/explore/security-posture/a1`
- `ai/web-research-master/task-42/a1`
- `ai/prompt-master/dd-cleanup/a2`

Rationale: (a) unique branch per attempt prevents checkout conflicts, (b) machine-parsable for automation, (c) supports circuit-breaker/attempt semantics, (d) `ai/` prefix enables bulk operations (`git branch --list 'ai/*'`).

### 3.3 Worktree Path Convention

Two supported layouts depending on deployment context:

**Layout A: Project-relative (recommended for single-project dev)**

```
.worktrees/<agent-name>/<taskId>/
```

**Layout B: External centralized (recommended for multi-project or heavy parallel)**

```
~/brain/worktrees/<repo-name>/<agent-name>/<taskId>/
```

Example filesystem layout (Layout A):

```
./                                    # Root repo (operator + Brain)
.worktrees/
  web-research-master/
    task-42/                          # Worktree for web-research-master
      .brain/ .claude/ core/ ...      # Full repo checkout
      vendor/                         # Own composer dependencies
  explore/
    security-posture/                 # Worktree for explore agent
      .brain/ .claude/ core/ ...
```

`.worktrees/` MUST be in `.gitignore`.

Layout B rationale: avoids disk space issues when worktrees contain large `vendor/`/`node_modules/`, enables shared caching across projects, keeps repo directory clean.

### 3.4 Shared Resources Policy

| Resource | Shared? | Mechanism | Rationale |
|----------|---------|-----------|-----------|
| `vendor/` | NO | Each worktree installs own | Autoloader conflicts, post-install hooks |
| `node_modules/` | NO | Each worktree installs own | Version/symlink conflicts |
| `.brain/` config | NO | Each worktree has own | Compile race condition prevention |
| `memory/` (SQLite) | YES | Absolute path or symlink | Single vector memory for all agents |
| `dist/` build output | NO | Each worktree has own | Artifact clobbering prevention |
| `.claude/` compiled | NO | Each worktree compiles own | Per-worktree instruction state |
| Composer cache | YES | `COMPOSER_CACHE_DIR` | Shared download cache, separate installs |
| pnpm store | YES | Content-addressable store + hard links | Disk-efficient shared dependencies |
| npm cache | YES | `npm config set cache` | Shared HTTP/package cache |

### 3.5 Memory Isolation Architecture

SQLite vector memory (`memory/`) is the ONLY shared mutable resource between worktrees.

**Access model:**
- **Location:** Single absolute path outside any worktree (e.g. `~/brain/state/<repo>/memory/`)
- **Binding:** Each worktree references memory via environment variable or symlink
- **WAL mode:** MANDATORY for concurrent read access from multiple worktrees
- **Write serialization:** Brain (or dedicated memory-writer MCP instance) serializes writes. Agents perform read-heavy access
- **Checkpoint policy:** Periodic WAL checkpoint to prevent WAL file growth degradation
- **Busy handling:** All SQLite clients MUST handle `SQLITE_BUSY` with retry + backoff

**Why absolute path:** All worktree processes must reference the SAME inode for SQLite locking to function correctly. Relative paths or copies would create N independent memories, breaking knowledge persistence.

### 3.6 MCP Server Isolation

Two deployment models for MCP servers in worktree context:

**Model A: Per-worktree MCP instances (recommended for v2+)**
- Each agent worktree starts its own MCP server instances
- MCP servers are rooted in the worktree path
- Maximum isolation: agent cannot accidentally access another worktree
- Cost: N instances × M MCP servers = N×M processes

**Model B: Shared MCP with workspace scoping (acceptable for v1)**
- Single MCP server instance shared by all agents
- Each request includes workspace root parameter
- Server enforces "no escape" from workspace root
- Cost: lower process count, higher trust requirement

Exception: `vector-memory` and `vector-task` MCP servers are ALWAYS shared (they access the shared memory SQLite).

### 3.7 Per-Worktree Configuration

Git supports per-worktree configuration via `extensions.worktreeConfig`:

```bash
# Enable per-worktree config (once, in main repo)
git config extensions.worktreeConfig true

# Set worktree-specific hooks path
git config --worktree core.hooksPath .worktree-hooks/
```

Use cases:
- Different `core.hooksPath` per worktree (agent-specific hooks)
- Environment setup via `post-checkout` hook (copy `.env`, set variables)
- Policy checks on blacklisted files via commit hooks

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

Agents NEVER force-push. Branch conflicts are resolved by the operator or integration pipeline via merge in root repo.

### 4.6 No Destructive Git in Worktrees

FORBIDDEN in any worktree context: `git checkout -- <file>`, `git restore`, `git stash`, `git reset`, `git clean`. These commands could destroy other agents' uncommitted work in shared-resource scenarios. Already enforced by existing parallel execution rules (`no-destructive-git`).

### 4.7 Integration Via Branch Only

Agents NEVER merge to master directly. All agent work reaches master through the merge protocol (see `19-parallel-merge-protocol.md`). The merge flow:

```
ai/agent-a/task-1/a1 ──merge──→ master ←──merge── ai/agent-b/task-2/a1
```

Merges happen in root repo by operator or integration pipeline.

### 4.8 Memory Folder Sacred

`memory/` directory (SQLite databases) is NEVER included in worktree-specific `git add` operations. Memory is shared infrastructure, not per-task artifact.

### 4.9 Worktree Cleanup Mandatory

Completed worktrees MUST be cleaned up within the same session or batch. Orphaned worktrees consume disk and branch namespace.

## 5. Integration with Parallel Task System

### 5.1 Task Decomposition Awareness

When `task:decompose` creates subtasks with `parallel: true`:
- Brain records the target worktree path in each subtask's metadata
- File scope (`FILES: [...]`) in task content determines which files the agent will touch
- The 5-condition parallel isolation checklist is evaluated BEFORE worktree creation

### 5.2 Task Execution Flow (v2)

```
1. task:decompose → subtasks with parallel: true, order, file scopes
2. Brain creates worktree per parallel subtask (git worktree add)
3. Brain installs dependencies in each worktree
4. task:async delegates agent to worktree via Task(--workdir=<path>)
5. Agent executes within worktree boundaries
6. Agent registers PARALLEL SCOPE in task comment
7. On completion: merge protocol executes (see doc 19)
8. On success: worktree cleanup (git worktree remove)
```

### 5.3 Scope Registration Compatibility

Existing scope registration mechanism (`PARALLEL SCOPE: [files]` in task comments) remains active. In worktree mode, scope registration serves as documentation/audit trail rather than primary isolation mechanism (physical isolation handles file conflicts).

### 5.4 Global Blacklist Enforcement

Files on the global blacklist (dependency manifests, `.env`, config, routes, migrations, CI/CD configs) remain FORBIDDEN for parallel agent modification even with worktree isolation. Rationale: these files require serial application and integration testing (see merge protocol).

### 5.5 Circuit Breaker Compatibility

Existing circuit breaker (MAX 3 attempts per task → tag `stuck`) maps to worktree lifecycle:
- Attempt 1: `ai/<agent>/<taskId>/a1` → new worktree
- Attempt 2: `ai/<agent>/<taskId>/a2` → new worktree (previous removed)
- Attempt 3: `ai/<agent>/<taskId>/a3` → new worktree (previous removed)
- After 3: tag `stuck`, all worktrees for this task cleaned up

## 6. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Disk usage (N worktrees × vendor/node_modules) | ~200-500MB per worktree | Shared download caches (Composer/pnpm); cleanup after merge; Layout B for heavy projects |
| Stale worktrees (forgotten after task) | Branch/disk clutter | Mandatory cleanup rule (4.9); periodic `git worktree prune`; GC policy |
| SQLite contention under parallel writes | `SQLITE_BUSY` errors | WAL mode + write serialization + retry with backoff |
| Branch cleanup lag | Old branches accumulate | `git branch --list 'ai/*' --merged master` cleanup after each batch |
| Force push from worktree | History corruption | Iron rule 4.5; `receive.denyNonFastForwards` on remote |
| Dependency drift between worktrees | Different versions installed | Lockfile pinning; regenerate from same lockfile per worktree |
| Hooks interference between worktrees | Unexpected behavior | Per-worktree `core.hooksPath` via `extensions.worktreeConfig` |
| Merge conflicts at integration | Failed merge pipeline | Serial application order (dependency-based); rerere; rollback via revert |

## 7. Relationship to Existing Contracts

| Contract | Relationship |
|----------|-------------|
| Compile Safety (`04-security-model.md`) | Worktree isolation makes single-writer lock per-worktree; compile races eliminated by filesystem separation |
| Parallel Merge Protocol (`19-parallel-merge-protocol.md`) | Defines HOW worktree branches are integrated back to master |
| Worktree Lifecycle (`20-worktree-lifecycle-management.md`) | Defines HOW worktrees are created, maintained, and cleaned up |
| Parallel Execution Architecture (`architecture/parallel-execution-architecture.md`) | E2E architecture connecting decomposition → isolation → execution → integration |
| Quad-Mode Drift Policy (`ENTERPRISE-DOD.md`) | Worktree isolation PREVENTS drift at source; drift policy remains as detection fallback for v0 |
| Model 2 Operating Contract (`15-model2-operating-contract.md`) | Worktree is the execution environment for Model 2 agents |
| Repo Topology (`architecture/repo-topology.md`) | Worktree isolation applies per-repo; each repo manages its own worktrees independently |
| Task Async (`TaskAsyncInclude`) | Parallel execution awareness integrates with worktree-based isolation |
| Task Decompose (`TaskDecomposeInclude`) | Parallel flag and file scope determine worktree creation |

## 8. Implementation Phases

### v0 (current) — Policy-Based Isolation

No physical isolation. Parallel agents work in the same worktree. Protection via:
- File scope registration in task comments
- Global blacklist enforcement
- Scoped git checkpoint (`git add {specific_files}`)
- Drift policy as safety net

### v1 — Operator-Managed Worktrees

**Prerequisites:** This contract approved, operator cookbook tested.

**Scope:**
- `.worktrees/` directory in `.gitignore`
- Operator creates/removes worktrees manually via cookbook commands
- Manual `composer install` / `pnpm install` per worktree
- Brain propagates `--workdir` to agents via Task() context
- Memory SQLite accessed via absolute path (shared)
- MCP servers: shared with workspace scoping (Model B)

**Acceptance criteria:**
1. `.worktrees/` in `.gitignore`
2. Operator cookbook tested (create, install deps, remove)
3. Brain `Task()` propagates `--workdir`
4. Zero drift incidents in 2-week trial

### v2 — Brain-Managed Worktrees

**Prerequisites:** v1 stable for 2+ weeks.

**Scope:**
- Brain auto-creates worktree on parallel Task delegation
- Brain auto-installs dependencies (cached)
- Brain auto-cleanup on task completion
- Per-worktree MCP instances (Model A)
- Integration task auto-creation after parallel batch
- `git worktree list --porcelain` as worktree registry

**New components:**
- `WorktreeManagementInclude.php` — worktree CRUD operations
- `ParallelMergeInclude.php` — merge protocol execution
- Brain script: `worktree:setup`, `worktree:merge`, `worktree:cleanup`

### v3 (optional) — Container-Per-Agent

**Prerequisites:** v2 stable; Docker available.

**Scope:**
- Container wraps each worktree for process/network isolation
- virtiofs for macOS file sharing performance
- Resource limits (CPU/memory) per agent
- Code editing on host (worktree), tests/linters in container

**Consideration:** macOS Docker bind mounts have performance overhead. Recommended: run tests in container, edit code on host worktree.

## 9. Repo Boundary Awareness

Worktree isolation applies **per repo**, not per monorepo. The project contains three independent git repositories (root, core/, cli/) — each with its own `.git/`. Worktree commands (`git worktree add`) operate within a single repo. An agent working in a core/ worktree cannot commit to root, and vice versa. See `.docs/architecture/repo-topology.md` for full topology and agent guardrails.

For cross-repo tasks: create separate worktrees in each affected repo, coordinate via task system.

## 10. Cross-References

- Merge Protocol: `.docs/product/19-parallel-merge-protocol.md`
- Worktree Lifecycle: `.docs/product/20-worktree-lifecycle-management.md`
- Parallel Architecture: `.docs/architecture/parallel-execution-architecture.md`
- Compile Safety: `.docs/product/04-security-model.md` section "Compile Safety Contract"
- Quad-Mode Drift: `.docs/audits/enterprise-codebase/ENTERPRISE-DOD.md` section "Quad-Mode Drift Policy"
- Model 2 Contract: `.docs/product/15-model2-operating-contract.md`
- Repo Topology: `.docs/architecture/repo-topology.md`
- Deep Research: `.docs/DocDiscovery/deep-research-report-isolation.md`
- Task Workflow Research: `.docs/DocDiscovery/deep-research-report-task-workflow.md`
- Backlog: `.docs/audits/enterprise-codebase/FIX-QUEUE.md` P2-009
