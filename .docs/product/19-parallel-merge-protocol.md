---
name: "Parallel Merge Protocol"
description: "Enterprise specification for merging parallel agent worktree branches back to master with conflict resolution and integration validation"
type: "contract"
date: "2026-02-22"
version: "1.0"
status: "spec"
---

# Parallel Merge Protocol

Defines HOW parallel agent branches are integrated back to master after worktree-isolated execution. Companion to `17-worktree-isolation-contract.md` (defines the isolation model) and `20-worktree-lifecycle-management.md` (defines worktree CRUD).

Research basis: `.docs/DocDiscovery/deep-research-report-isolation.md` section "Merge strategies for AI-generated code".

## 1. Goals

1. **Deterministic integration** — merge order is policy-driven, not random.
2. **Clean history** — each merged task produces one conventional commit on master.
3. **Conflict detection** — conflicts caught before they reach master.
4. **Rollback safety** — any merged task can be reverted without affecting others.
5. **No destructive git** — compliant with existing iron rule: no force-push, no reset, no clean.

## 2. Merge Modes

### Mode A: Squash Merge (recommended, default)

One task = one conventional commit on master. Agent's internal commit history is discarded.

```
ai/agent-a/task-42/a1  (N commits) ──squash──→ master (1 commit)
```

**When to use:** Standard task execution, clean linear history desired.

**Command:** `git merge --squash ai/<agent>/<taskId>/<attempt>`

**Advantages:**
- Cleanest possible history
- Each task is a single atomic revert unit
- Conventional commit message written by integration step

**Disadvantages:**
- Loses intermediate commit context (acceptable: vector memory stores decision rationale)

### Mode B: Patch-Based (for selective integration)

Agent changes exported as patches, applied serially with policy gate per patch.

```
ai/agent-a/task-42/a1  ──format-patch──→ patches ──am──→ master
```

**When to use:** Need to selectively include/exclude specific hunks, or when agent made multiple logically separate changes.

**Command:** `git format-patch master..ai/<agent>/<taskId>/<attempt> -o /tmp/patches/`

**Advantages:**
- Per-hunk policy gate (can reject individual changes)
- No merge commit noise
- Supports linear history enforcement

**Disadvantages:**
- More complex pipeline
- Requires strict conventional commits from agent

### Mode Selection Rule

Default: **Mode A (squash)** for all standard task execution.

Use Mode B only when:
- Integration pipeline needs per-hunk review
- Agent produced multiple independent logical changes in one branch
- Compliance/audit requires patch-level traceability

## 3. Serial Application Order

When N parallel agents complete, their branches are merged one-by-one in a deterministic order. Never use `octopus` merge (fails on any conflict, inappropriate for AI-generated code).

### Order Policy (priority cascade)

1. **Dependency order** — if task B depends on task A's output, merge A first. Read from `order` field + `parallel` flag in vector task system.

2. **Low risk first** — among independent tasks, merge the one with:
   - Fewer files changed
   - No blacklisted file modifications
   - Lower estimated complexity

3. **High risk last** — tasks touching auth, payments, config, or shared infrastructure merge last (maximum test coverage before they land).

4. **Deterministic tiebreaker** — if equal risk, order by task ID (ascending).

### Application Procedure

```
FOR each branch in sorted order:
  1. git merge --squash <branch>
  2. IF conflict:
     a. Check rerere database for resolution
     b. IF rerere resolves → verify resolution, accept
     c. ELSE → escalate to operator
  3. Run scoped tests (files changed in this branch)
  4. IF tests fail → git reset HEAD (abort this squash), mark task as integration-failed
  5. IF tests pass → create conventional commit
  6. Proceed to next branch
```

## 4. Integration Task Pattern

### When to Create

| Condition | Integration task? | Strictness |
|-----------|-------------------|------------|
| Single agent (N=1) | NO — inline merge | Standard validation |
| N >= 2 parallel agents, no conflicts | YES — always | Standard |
| Any agent touched blacklisted file | YES — mandatory | High (full test suite) |
| Conflicts detected at merge | YES — mandatory | Critical (operator review) |

### Integration Task Scope

The integration task performs:

1. **Serial merge** — apply branches in policy order (section 3)
2. **Conflict resolution** — rerere + domain-specific merge drivers
3. **Lockfile regeneration** — reject lockfile changes from agents, regenerate centrally
4. **Scoped tests** — per-branch test run after each merge step
5. **Integration tests** — full test suite after all branches merged
6. **Cross-file invariant check** — verify imports, namespaces, config references across merged changes
7. **Conventional commit** — one squash commit per successfully merged branch

### Integration Task Auto-Creation (v2)

After parallel batch execution completes:

```
IF count(completed parallel siblings) >= 2:
  Create integration task:
    title: "Integrate parallel batch: [task-ids]"
    parent: parent task of parallel siblings
    tags: [integration, parallel-merge]
    content: "Merge branches: [branch-list]. Order: [policy-order]."
    parallel: false
    order: max(sibling orders) + 1
```

## 5. Lockfile Governance

Lockfiles (`composer.lock`, `package-lock.json`, `pnpm-lock.yaml`) require special handling in parallel context.

### Policy: Agents Do Not Modify Lockfiles

Agents MUST NOT commit lockfile changes. If an agent needs a new dependency:
1. Agent records the dependency requirement in task comment (`DEPENDENCY: require vendor/package:^1.0`)
2. Integration pipeline handles `composer require` / `pnpm add` centrally
3. Lockfile is regenerated once, after all agent branches merged

### Rationale

- Lockfiles have non-deterministic internal ordering (hash/sort varies between runs)
- Merging N agents' lockfile changes produces garbage
- Centralized regeneration from single lockfile source eliminates conflicts

### Exception

If a task's sole purpose is dependency management (e.g., "upgrade package X"), it runs as a sequential (non-parallel) task with exclusive lockfile access.

## 6. Conflict Resolution

### Level 1: git rerere (Automatic)

Enable `rerere` on the integration worktree:

```bash
git config rerere.enabled true
```

`rerere` records conflict resolutions and replays them on identical conflicts. Effective for repetitive patterns (e.g., agent adds import to the same location repeatedly).

**Risk:** Stale rerere resolution applied to changed context. Mitigation: always run tests after rerere-resolved merge.

### Level 2: Custom Merge Drivers (Domain-Specific)

For files with known merge semantics, configure `.gitattributes` + custom drivers:

```
# .gitattributes
composer.lock merge=regenerate-lock
package-lock.json merge=regenerate-lock
```

Use cases:
- Lockfiles: always regenerate (never 3-way merge)
- Route files: append-only merge strategy
- Config arrays: union merge

### Level 3: Operator Escalation

If automated resolution fails:
1. Integration task pauses with status `needs-review`
2. Operator resolves conflict manually
3. Resolution recorded in rerere database for future automation
4. Integration resumes

## 7. Rollback Strategy

Compliant with existing iron rule: no destructive git commands.

### Method: git revert

If a merged branch breaks tests or introduces regression:

```bash
# Identify the squash commit to revert
git log --oneline --grep="task-42"

# Revert (non-destructive, preserves history)
git revert <commit-sha>
```

### Cascading Rollback

If reverting branch A breaks branch B's merge (dependency):
1. Revert B first (later merge order)
2. Then revert A
3. Re-attempt both tasks with fixes

### Rollback Decision Matrix

| Failure type | Action |
|-------------|--------|
| Scoped tests fail for branch X | Skip branch X, continue with remaining |
| Integration tests fail after all merges | Binary search: revert last merged, re-test |
| Post-merge regression discovered later | `git revert` the specific squash commit |

## 8. Quality Gates

### Per-Branch Gate (after each squash merge)

- Syntax check (`php -l` for changed files)
- Scoped tests (tests related to changed files)
- Static analysis (`phpstan` on changed files if supported)

### Full Integration Gate (after all branches merged)

- Full test suite (`composer test`)
- Full static analysis (`composer analyse`)
- Compile verification (`brain compile` + `check-compile-clean.sh`)
- Documentation validation (`brain docs --validate`)

### Gate Failure Policy

| Gate | Failure action |
|------|---------------|
| Per-branch scoped tests | Skip this branch, mark task `integration-failed`, continue |
| Full test suite | Identify failing branch (binary search), revert, re-validate |
| Static analysis | Fix inline if trivial, otherwise mark `needs-review` |
| Compile verification | Investigate non-determinism, never proceed with dirty compile |

## 9. Relationship to Existing Parallel Safety

This protocol ADDS physical isolation on top of existing policy-based safety:

| Existing mechanism | Status with worktrees |
|---|---|
| File scope registration (`PARALLEL SCOPE: [...]`) | Remains as documentation/audit trail |
| Global file blacklist | Remains as merge-time enforcement |
| 5-condition isolation checklist | Remains as decomposition-time validation |
| Scoped git checkpoint | Replaced by per-worktree full `git add` |
| `no-destructive-git` rule | Remains unchanged |
| Circuit breaker (3 attempts) | Maps to worktree-per-attempt lifecycle |

## 10. Cross-References

- Worktree Isolation Contract: `.docs/product/17-worktree-isolation-contract.md`
- Worktree Lifecycle: `.docs/product/20-worktree-lifecycle-management.md`
- Parallel Architecture: `.docs/architecture/parallel-execution-architecture.md`
- Deep Research: `.docs/DocDiscovery/deep-research-report-isolation.md`
- Task Workflow Research: `.docs/DocDiscovery/deep-research-report-task-workflow.md`
