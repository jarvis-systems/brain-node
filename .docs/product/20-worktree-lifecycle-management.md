---
name: "Worktree Lifecycle Management"
description: "Enterprise specification for git worktree creation, dependency management, hooks, artifact collection, cleanup, and recovery"
type: "contract"
date: "2026-02-22"
version: "1.0"
status: "spec"
---

# Worktree Lifecycle Management

Defines HOW worktrees are created, maintained, and cleaned up throughout the parallel agent execution lifecycle. Companion to `17-worktree-isolation-contract.md` (defines the isolation model) and `19-parallel-merge-protocol.md` (defines merge integration).

Research basis: `.docs/DocDiscovery/deep-research-report-isolation.md` sections "Automated worktree orchestration" and "Shared resources".

## 1. Lifecycle Phases

```
CREATE → PROVISION → EXECUTE → COLLECT → MERGE → CLEANUP
```

| Phase | Actor (v1) | Actor (v2) | Description |
|-------|-----------|-----------|-------------|
| CREATE | Operator | Brain | `git worktree add` with branch naming convention |
| PROVISION | Operator | Brain script | Install dependencies, configure hooks, bind memory |
| EXECUTE | Agent | Agent | Task execution within worktree boundaries |
| COLLECT | Operator | Brain | Extract artifacts (logs, test reports) to centralized storage |
| MERGE | Operator | Integration pipeline | Merge branch to master per merge protocol |
| CLEANUP | Operator | Brain | `git worktree remove`, branch cleanup |

## 2. CREATE Phase

### Standard Creation

```bash
# Create branch + worktree
git worktree add <worktree-path> -b <branch-name> <base-ref>
```

Parameters:
- `<worktree-path>`: Per convention from doc 17 (e.g., `.worktrees/web-research-master/task-42/`)
- `<branch-name>`: Per naming convention (e.g., `ai/web-research-master/task-42/a1`)
- `<base-ref>`: Usually `master` or `HEAD`

### Creation Checklist

1. Verify base-ref is up to date (`git fetch origin` if remote-tracking)
2. Verify branch name does not already exist (`git branch --list 'ai/<agent>/<taskId>/*'`)
3. Verify worktree path does not exist on disk
4. Create worktree: `git worktree add -b <branch> <path> <base-ref>`
5. Verify creation: `git worktree list` includes new entry

### Creation Failure Recovery

| Failure | Cause | Recovery |
|---------|-------|----------|
| "branch already checked out" | Previous attempt not cleaned up | Remove old worktree first, then retry |
| "branch already exists" | Branch from previous attempt | Delete branch (`git branch -D`) or use next attempt number |
| Path already exists | Orphaned directory from crashed session | `rm -rf <path>` then retry |
| Permission denied | Disk/OS issue | Check disk space, permissions |

### Detached HEAD Mode (optional)

For throwaway experiments or patch-only integration:

```bash
git worktree add --detach <path> <base-ref>
```

Use case: when you want to generate patches without creating a named branch. Not recommended for standard workflow.

## 3. PROVISION Phase

### Dependency Installation

Each worktree needs its own dependencies. Use shared download caches for speed.

**PHP (Composer):**

```bash
cd <worktree-path>

# Use centralized cache (fast download)
COMPOSER_CACHE_DIR=~/brain/cache/composer composer install --no-interaction --prefer-dist
```

**Node.js (pnpm recommended):**

```bash
cd <worktree-path>

# pnpm uses content-addressable store + hard links (minimal disk usage)
# IMPORTANT: store must be on same filesystem for hard links to work
pnpm install --frozen-lockfile
```

**Node.js (npm fallback):**

```bash
cd <worktree-path>
npm ci --cache ~/brain/cache/npm
```

### Installation Time Budget

| Stack | Cold install (no cache) | Warm install (cached) |
|-------|------------------------|----------------------|
| PHP (Composer) | 30-60s | 5-10s |
| Node (pnpm) | 20-40s | 3-5s |
| Node (npm) | 40-90s | 10-20s |
| Both | 60-120s | 10-20s |

### Memory Binding

Bind shared SQLite memory to worktree:

**Option A: Symlink (simple)**

```bash
ln -s ~/brain/state/<repo>/memory <worktree-path>/memory
```

**Option B: Environment variable (portable)**

```bash
export VECTOR_MEMORY_PATH=~/brain/state/<repo>/memory/memory.sqlite
export VECTOR_TASK_PATH=~/brain/state/<repo>/memory/tasks.sqlite
```

### Compilation

Each worktree needs its own compiled output:

```bash
cd <worktree-path>
brain compile
```

This generates `.claude/CLAUDE.md` and agent instructions specific to the worktree's codebase state.

### Per-Worktree Hooks (optional)

```bash
# Enable per-worktree config (once, in main repo)
git config extensions.worktreeConfig true

# In the worktree:
cd <worktree-path>
git config --worktree core.hooksPath .worktree-hooks/

# Create worktree-specific hooks
mkdir -p .worktree-hooks
cat > .worktree-hooks/pre-commit << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Block commits to blacklisted files in parallel context
BLACKLIST="composer.json composer.lock package.json pnpm-lock.yaml .env"
for file in $BLACKLIST; do
  if git diff --cached --name-only | grep -q "^${file}$"; then
    echo "BLOCKED: $file is on the global blacklist for parallel agents"
    exit 1
  fi
done
EOF
chmod +x .worktree-hooks/pre-commit
```

## 4. EXECUTE Phase

Execution is handled by the agent within the worktree. This phase is governed by `TaskAsyncInclude` and `TaskSyncInclude` — not this document.

Key constraints during execution:
- Agent operates ONLY within `<worktree-path>`
- Agent respects file scope from task content
- Agent does NOT modify files outside task scope
- Agent uses memory via shared absolute path
- Agent registers `PARALLEL SCOPE: [files]` in task comment

## 5. COLLECT Phase

Before cleanup, extract valuable artifacts from the worktree:

### Artifacts to Collect

| Artifact | Destination | Purpose |
|----------|-------------|---------|
| Test reports (JUnit XML) | `~/brain/artifacts/<taskId>/` | Integration validation |
| Coverage reports | `~/brain/artifacts/<taskId>/` | Quality gate evidence |
| Compile output diffs | `~/brain/artifacts/<taskId>/` | Audit trail |
| Agent logs (if any) | `~/brain/artifacts/<taskId>/` | Debugging |
| Git diff summary | `~/brain/artifacts/<taskId>/` | Merge preparation |

### Artifact Collection Script

```bash
TASK_ID="task-42"
WORKTREE_PATH=".worktrees/web-research-master/$TASK_ID"
ARTIFACT_DIR="$HOME/brain/artifacts/$TASK_ID"

mkdir -p "$ARTIFACT_DIR"

# Git diff summary
git -C "$WORKTREE_PATH" diff master --stat > "$ARTIFACT_DIR/diff-stat.txt"
git -C "$WORKTREE_PATH" diff master > "$ARTIFACT_DIR/full-diff.patch"

# Test results (if exist)
cp "$WORKTREE_PATH"/build/reports/*.xml "$ARTIFACT_DIR/" 2>/dev/null || true

# File list touched
git -C "$WORKTREE_PATH" diff master --name-only > "$ARTIFACT_DIR/files-changed.txt"
```

## 6. MERGE Phase

Handled by the Parallel Merge Protocol (`19-parallel-merge-protocol.md`). This phase bridges COLLECT and CLEANUP.

## 7. CLEANUP Phase

### Standard Cleanup (after successful merge)

```bash
WORKTREE_PATH=".worktrees/web-research-master/task-42"
BRANCH_NAME="ai/web-research-master/task-42/a1"

# 1. Remove worktree (Git validates clean state)
git worktree remove "$WORKTREE_PATH"

# 2. Delete the branch (already merged)
git branch -d "$BRANCH_NAME"

# 3. Prune stale admin records
git worktree prune
```

### Cleanup After Failed Integration

```bash
# Worktree may have uncommitted changes — force removal
git worktree remove --force "$WORKTREE_PATH"

# Branch NOT merged — delete with force
git branch -D "$BRANCH_NAME"

# Prune
git worktree prune
```

### Batch Cleanup (all finished worktrees)

```bash
# List all worktrees
git worktree list

# Prune orphaned admin records
git worktree prune --dry-run  # Preview first
git worktree prune             # Execute

# Delete all merged ai/* branches
git branch --list 'ai/*' --merged master | xargs -r git branch -d

# Delete all unmerged ai/* branches older than 7 days (safety net)
# Manual review recommended before this step
git branch --list 'ai/*' --no-merged master
```

### Disk Cleanup

```bash
# After batch cleanup, free disk
git gc --auto

# For aggressive cleanup (only during maintenance windows)
git gc --aggressive --prune=now
```

## 8. Recovery Procedures

### Orphaned Worktree (directory deleted manually)

```bash
# Git still has admin records for the deleted directory
git worktree prune  # Removes stale admin records

# If branch still exists and has uncommitted work:
# Recreate worktree at new path
git worktree add <new-path> <existing-branch>
```

### Moved Worktree (directory relocated externally)

```bash
# Repair Git's internal worktree links
git worktree repair <old-path> <new-path>

# Or: repair all worktrees
git worktree repair
```

### Locked Worktree (preventing accidental prune)

```bash
# Lock a worktree during critical integration phase
git worktree lock <path> --reason "Integration in progress"

# Unlock after integration completes
git worktree unlock <path>
```

Use case: prevent `git worktree prune` from removing a worktree during active merge/integration.

### Crashed Agent Session

If an agent crashes mid-execution:

1. Check worktree state: `git -C <worktree-path> status`
2. If valuable changes exist: commit or stash them
3. If no value: force remove worktree
4. Task system detects stale `in_progress` and triggers circuit breaker

## 9. Disk Management

### Space Budget Per Worktree

| Component | Size estimate | Notes |
|-----------|--------------|-------|
| Git working copy | 5-50 MB | Shared .git objects, only files differ |
| `vendor/` (PHP) | 50-200 MB | With cached downloads: seconds to install |
| `node_modules/` (pnpm) | 10-50 MB | Hard links from global store, minimal real disk |
| `node_modules/` (npm) | 100-400 MB | Full copy, no dedup |
| `.claude/` compiled | 1-5 MB | Small compiled output |
| Build artifacts | 5-50 MB | Tests, coverage, etc. |
| **Total per worktree** | **70-750 MB** | Depends on stack and package manager |

### Scaling for 3-8 Concurrent Agents

| Scenario | pnpm | npm |
|----------|------|-----|
| 3 agents | ~300 MB total | ~1.5 GB total |
| 5 agents | ~500 MB total | ~2.5 GB total |
| 8 agents | ~800 MB total | ~4 GB total |

Recommendation: use pnpm for Node.js projects to minimize disk overhead in multi-worktree scenarios.

### Monitoring

```bash
# Total worktree disk usage
du -sh .worktrees/*/

# Git object store size (shared across all worktrees)
git count-objects -vH | grep size-pack
```

## 10. Automation Commands Summary (v1 Operator Cookbook)

### Quick Reference

```bash
# === CREATE ===
git worktree add .worktrees/<agent>/<task> -b ai/<agent>/<task>/a1 master

# === PROVISION ===
cd .worktrees/<agent>/<task>
COMPOSER_CACHE_DIR=~/brain/cache/composer composer install --no-interaction
ln -s ~/brain/state/<repo>/memory memory
brain compile

# === STATUS ===
git worktree list
git worktree list --porcelain  # Machine-readable

# === CLEANUP ===
git worktree remove .worktrees/<agent>/<task>
git branch -d ai/<agent>/<task>/a1
git worktree prune

# === RECOVERY ===
git worktree repair
git worktree prune
```

## 11. Cross-References

- Worktree Isolation Contract: `.docs/product/17-worktree-isolation-contract.md`
- Parallel Merge Protocol: `.docs/product/19-parallel-merge-protocol.md`
- Parallel Architecture: `.docs/architecture/parallel-execution-architecture.md`
- Repo Topology: `.docs/architecture/repo-topology.md`
- Deep Research: `.docs/DocDiscovery/deep-research-report-isolation.md`
