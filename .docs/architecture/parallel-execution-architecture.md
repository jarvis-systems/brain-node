---
name: "Parallel Execution Architecture"
description: "End-to-end architecture for parallel multi-agent task execution with worktree isolation, merge integration, and validation"
type: "architecture"
date: "2026-02-22"
version: "1.0"
status: "spec"
---

# Parallel Execution Architecture

End-to-end architecture connecting task decomposition, worktree isolation, agent execution, merge integration, and validation into a unified parallel execution pipeline.

## 1. Architecture Overview

```
User Request
    │
    ▼
┌─────────────┐
│    Brain     │  Orchestrator: decomposes, delegates, validates
│ (Orchestrator)│
└─────┬───────┘
      │
      ▼
┌─────────────┐
│   Decompose  │  task:decompose → subtasks with parallel flags
│   Pipeline   │
└─────┬───────┘
      │
      ▼
┌─────────────────────────────────────────────┐
│           Isolation Layer (v1/v2)            │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │Worktree A│  │Worktree B│  │Worktree C│  │
│  │ Agent 1  │  │ Agent 2  │  │ Agent 3  │  │
│  │ Branch A │  │ Branch B │  │ Branch C │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│       │              │              │        │
│       └──────┬───────┘──────────────┘        │
│              │                               │
│        Shared Memory (SQLite WAL)            │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────┐
│  Integration Pipeline │  Serial merge + tests + validation
│  (Merge Protocol)     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Validation Layer   │  4 parallel validation agents
└──────────┬──────────┘
           │
           ▼
        master
```

## 2. Component Description

### 2.1 Brain (Orchestrator)

The Brain is a strategic orchestrator that NEVER executes tasks directly (except trivial meta-operations). It:

- Receives user requests
- Decomposes complex tasks via `task:decompose`
- Determines execution mode (sequential vs parallel)
- Creates worktrees for parallel execution (v2)
- Delegates agents to worktrees via `Task(--workdir=<path>)`
- Coordinates merge integration after completion
- Triggers validation pipeline
- Reports results to user

### 2.2 Decompose Pipeline

The decomposition layer (`TaskDecomposeInclude`) analyzes tasks for parallelizability:

**Input:** Single task with scope, file list, dependencies.

**Process:**
1. Scope analysis: distinct concerns → candidate subtasks
2. Parallel research: 2 concurrent agents (ExploreMaster + VectorMemory)
3. Dependency analysis via SequentialThinking
4. 5-condition isolation checklist per subtask pair
5. File manifest verification

**Output:** Subtasks with:
- `order`: execution sequence number
- `parallel: true/false`: concurrent execution flag
- `FILES: [...]`: file scope declaration
- `estimate`: hours estimate (leaf <= 4h)

**Decomposition Rules:**
- Scope-based (distinct file scopes), NOT time-based
- Each subtask has distinct concern and file scope
- No standalone "write tests" subtasks (handled by executors)
- Conservative default: `parallel: false` unless ALL 5 conditions proven

### 2.3 Isolation Layer

Two isolation modes coexist as defense-in-depth:

**Policy-Based Isolation (v0, always active):**
- File scope registration in task comments (`PARALLEL SCOPE: [files]`)
- Global file blacklist (dependency manifests, .env, config, routes, migrations)
- Scoped git checkpoint (`git add {specific_files}`)
- Status-based conflict detection (only `in_progress` siblings threaten)

**Physical Isolation (v1+, worktree-based):**
- One worktree per parallel agent
- Unique branch per agent/task/attempt
- Filesystem-level file separation
- Per-worktree dependencies and compiled output
- Shared memory via absolute path (SQLite WAL)

Physical isolation ADDS to policy isolation. Both remain active simultaneously. Policy isolation serves as documentation and audit trail when physical isolation is present.

### 2.4 Agent Execution

Each agent operates within its worktree with:

**Boundaries:**
- Read/Write ONLY within assigned worktree path
- File scope limited to task content declaration
- No cross-worktree access
- No destructive git commands

**Communication:**
- Vector memory (shared SQLite): read-heavy access, write for insights
- Task comments: scope registration, status signals, failure records
- Task system: status updates via MCP

**Execution Modes:**
- `task:async` — Brain delegates to agents via Task() tool
- `task:sync` — Brain executes directly (NOT in parallel context)
- `do:async` — Multi-step orchestration with parallel batches

### 2.5 Integration Pipeline

After parallel agents complete, the integration pipeline merges their work:

**Serial Merge Flow:**
1. Determine merge order (dependency → risk → task ID)
2. For each branch in order:
   a. Squash merge to master
   b. Resolve conflicts (rerere → domain drivers → operator escalation)
   c. Run scoped tests
   d. Create conventional commit
3. Run full integration tests after all merges
4. Cleanup worktrees and branches

**Governed by:** `19-parallel-merge-protocol.md`

### 2.6 Validation Layer

Post-integration validation uses 4 parallel agents:

1. **Completion Check** — does the work address the original task?
2. **Code Quality** — static analysis, style, architecture compliance
3. **Testing** — test coverage, test quality, test execution
4. **Security & Performance** — vulnerability scan, performance regression

Optional 5th agent: **Research Escalation** — triggered by stuck patterns.

**Governed by:** `TaskValidateInclude`, `TaskTestValidateInclude`

## 3. Execution Flow: Sequential vs Parallel

### Sequential Execution (parallel: false)

```
Subtask 1 (order:1) → complete → Subtask 2 (order:2) → complete → ...
```

All subtasks share the SAME worktree (root repo). Standard single-agent flow.

### Parallel Execution (parallel: true)

```
                    ┌─ Subtask 2 (parallel:true, order:2) ──┐
Subtask 1 (seq) ──→│                                        │──→ Integration → Subtask 5 (seq)
                    └─ Subtask 3 (parallel:true, order:3) ──┘
                    └─ Subtask 4 (parallel:true, order:4) ──┘
```

Parallel subtasks get own worktrees. Followed by integration task.

### Mixed Execution (typical real-world)

```
Phase 1: Subtask 1 (sequential, foundation work)
Phase 2: Subtasks 2,3,4 (parallel, independent features)
Phase 3: Integration task (merge parallel results)
Phase 4: Subtask 5 (sequential, depends on integrated result)
Phase 5: Validation
```

### First-Batch-Only Discipline

Brain handles only the FIRST batch per execution cycle:
- First sequential task, OR
- First group of adjacent parallel tasks

Remaining batches require separate execution invocations. This prevents context exhaustion and maintains orchestration quality.

## 4. Shared State Management

### 4.1 Vector Memory (SQLite)

| Property | Value |
|----------|-------|
| Location | Absolute path (e.g., `~/brain/state/<repo>/memory/`) |
| Access mode | WAL (Write-Ahead Logging) |
| Readers | All agents (concurrent, non-blocking) |
| Writers | Brain or dedicated memory-writer (serialized) |
| Busy handling | Retry with exponential backoff |

### 4.2 Vector Tasks (SQLite)

| Property | Value |
|----------|-------|
| Location | Same directory as memory |
| Access mode | WAL |
| Concurrent safety | Status propagation is atomic (child→parent) |
| Task comments | Used for scope registration (zero extra MCP calls) |

### 4.3 MCP Servers

| Server | Isolation model | Rationale |
|--------|----------------|-----------|
| vector-memory | Shared (single instance) | Must access shared SQLite |
| vector-task | Shared (single instance) | Must access shared SQLite |
| sequential-thinking | Per-worktree | Stateless, no shared resources |
| context7 | Shared (stateless) | External API, no local state |
| github | Shared (stateless) | External API, no local state |

### 4.4 Configuration Files

| File | Parallel safety | Handling |
|------|----------------|---------|
| `.brain/.env` | Per-worktree copy | Each worktree has own environment |
| `composer.json` | BLACKLISTED | Never modified by parallel agents |
| `composer.lock` | BLACKLISTED | Regenerated by integration pipeline |
| `.mcp.json` | Per-worktree | Generated by `brain compile` |
| `phpstan.neon` | READONLY | Shared analysis config |

## 5. Safety Layers (Defense in Depth)

```
Layer 1: Task Decomposition
  └─ 5-condition isolation checklist
  └─ File manifest per task
  └─ Conservative default (parallel: false)

Layer 2: Worktree Isolation (v1+)
  └─ Filesystem-level separation
  └─ Unique branch per agent
  └─ Per-worktree dependencies

Layer 3: Policy Enforcement (always active)
  └─ File scope registration
  └─ Global file blacklist
  └─ No destructive git commands
  └─ Scoped git operations

Layer 4: Integration Safeguards
  └─ Serial merge order
  └─ Per-branch testing
  └─ Conflict detection (rerere)
  └─ Rollback via git revert

Layer 5: Validation Pipeline
  └─ 4 parallel validation agents
  └─ Full test suite
  └─ Static analysis
  └─ Compile verification
```

## 6. Current State vs Target State

### v0 (Current) — Policy-Only

```
Brain → task:decompose → subtasks (parallel flag)
     → task:async → agents in SAME worktree
     → agents register scopes in task comments
     → scoped git add (task files only)
     → Brain validates
```

**Strengths:** Works, tested, iron rules enforce safety.
**Weaknesses:** No physical isolation. Policy violations = file conflicts.

### v1 (Target: Operator-Managed) — Physical Isolation

```
Brain → task:decompose → subtasks (parallel flag)
Operator → create worktrees (git worktree add)
Operator → provision (composer install, memory symlink)
Brain → task:async → agents in OWN worktrees
     → agents work in filesystem isolation
Operator → merge (squash merge per protocol)
Operator → cleanup (git worktree remove)
Brain → validates
```

**Strengths:** Physical isolation. Clean git history. Reproducible.
**Weaknesses:** Manual operator steps. Dependency install time.

### v2 (Target: Brain-Managed) — Full Automation

```
Brain → task:decompose → subtasks (parallel flag)
     → auto-create worktrees
     → auto-provision (cached deps)
     → task:async → agents in OWN worktrees
     → auto-create integration task
     → auto-merge (serial, policy-ordered)
     → auto-validate (4 parallel agents)
     → auto-cleanup worktrees
```

**Strengths:** Zero manual intervention. Full automation.
**Weaknesses:** Higher complexity. Requires stable v1.

### v3 (Optional: Container Isolation) — Maximum Security

```
Brain → auto-create worktrees
     → wrap each worktree in container
     → agents execute in sandboxed environment
     → resource limits (CPU/RAM) per agent
     → merge on host
```

**Strengths:** Process isolation. Resource limits. Network control.
**Weaknesses:** Docker bind mount performance on macOS. Overhead.

## 7. Estimated Implementation Effort

| Component | Phase | Estimate | Priority |
|-----------|-------|----------|----------|
| Worktree Manager (create/remove/prune/repair) | v1 | 16-28h | Critical |
| Branch naming + GC policy | v1 | 4-8h | Critical |
| Dependency caching (Composer/pnpm) | v1 | 8-20h | High |
| Memory binding (absolute path + WAL) | v1 | 8-16h | Critical |
| Merge protocol implementation | v1 | 18-40h | High |
| Integration task auto-creation | v2 | 8-16h | High |
| Brain-managed worktree lifecycle | v2 | 16-24h | High |
| Per-worktree MCP instances | v2 | 8-16h | Medium |
| Worktree hooks (blacklist enforcement) | v2 | 4-8h | Medium |
| Container integration (Docker) | v3 | 20-48h | Low |
| **Total v1** | v1 | **54-112h** | — |
| **Total v1+v2** | v2 | **90-176h** | — |
| **Total v1+v2+v3** | v3 | **110-224h** | — |

## 8. Code Components (v2 Implementation Plan)

New includes to create:

| Component | Type | Purpose |
|-----------|------|---------|
| `WorktreeManagementInclude` | Include | Git worktree CRUD, branch naming, cleanup |
| `ParallelMergeInclude` | Include | Serial merge, conflict resolution, rollback |
| `WorktreeProvisionInclude` | Include | Dependency installation, memory binding, hooks |

New brain scripts to create:

| Script | Purpose |
|--------|---------|
| `worktree:setup` | Create worktree + provision (deps, memory, compile) |
| `worktree:merge` | Merge worktree branch to master per protocol |
| `worktree:cleanup` | Remove worktree + delete branch + prune |
| `worktree:status` | List all worktrees with branch/task mapping |

Existing includes to modify:

| Include | Changes |
|---------|---------|
| `TaskAsyncInclude` | Add worktree creation/cleanup phases (v2) |
| `TaskDecomposeInclude` | Add worktree path generation for parallel subtasks |
| `CompileSafetyInclude` | Expand worktree-quarantine for multi-worktree context |
| `DoAsyncInclude` | Worktree-aware parallel batch execution |
| `SharedCommandTrait` | New worktree safety rules |
| `TaskCommandCommonTrait` | Worktree-aware isolation rules |

## 9. Go Migration Considerations

This architecture is designed as the canonical specification for X-Brain (Go rewrite):

| PHP concept | Go equivalent |
|-------------|---------------|
| Includes (compile-time merge) | Internal packages with interface composition |
| Vector memory MCP | Native SQLite driver with WAL |
| Task delegation via Task() | goroutine + channel orchestration |
| Brain scripts (Laravel Console) | cobra CLI commands |
| Per-worktree flock() | `os.CreateTemp` + `syscall.Flock` |
| `errgroup` for parallel agents | `golang.org/x/sync/errgroup` |
| Context propagation | `context.Context` with deadlines |

The Go version should implement worktree management natively (via `go-git` or exec `git`) rather than through MCP, eliminating the MCP-server-per-worktree overhead entirely.

## 10. Cross-References

- Worktree Isolation Contract: `.docs/product/17-worktree-isolation-contract.md`
- Parallel Merge Protocol: `.docs/product/19-parallel-merge-protocol.md`
- Worktree Lifecycle: `.docs/product/20-worktree-lifecycle-management.md`
- Repo Topology: `.docs/architecture/repo-topology.md`
- Task Workflow Research: `.docs/DocDiscovery/deep-research-report-task-workflow.md`
- Isolation Research: `.docs/DocDiscovery/deep-research-report-isolation.md`
- Security Model: `.docs/product/04-security-model.md`
