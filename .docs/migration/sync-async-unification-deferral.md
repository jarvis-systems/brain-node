---
name: "SYNC/ASYNC Unification — DEFERRED"
description: "Deferred decision to keep sync/async command pairs separate"
date: "2026-02-20"
status: deferred
decision: keep-separate
---

# SYNC/ASYNC Unification — DEFERRED

## Current State

4 command pairs with execution mode variants:

| Pair | Sync | Async | Shared Trait |
|------|------|-------|-------------|
| Do commands | DoSyncInclude (330 lines) | DoAsyncInclude (409 lines) | DoCommandCommonTrait (589 lines) |
| Task commands | TaskSyncInclude (584 lines) | TaskAsyncInclude (487 lines) | TaskCommandCommonTrait (876 lines) |

**Shared code**: ~65% via traits (entry point rules, zero-distractions, vector memory, circuit breaker, progress format, error handling).

**Unique code**: ~35-40% per variant (phase structure, execution model, approval gates, research strategy).

## Why DEFER

1. **Current design is sound.** Traits already extract all common patterns. 65% sharing is near-optimal for two fundamentally different execution models (direct tools vs agent delegation).

2. **Unification adds complexity without proportional benefit.** Merging would save ~100-150 lines but introduce conditional branching that obscures intent. A 700-line conditional file is harder to maintain than two 350-line clear files.

3. **Separation prevents mode confusion.** Sync and async have different phase counts (4 vs 6), different approval gate counts (1 vs 2), and different error recovery strategies. Mixing them risks the model confusing execution modes at runtime.

## Risks of Unification

| Risk | Severity | Description |
|------|----------|-------------|
| Mode confusion | HIGH | If mode dispatch fails or is ambiguous, Brain may execute wrong phase flow |
| Readability degradation | MEDIUM | Conditional logic throughout `handle()` reduces scanability |
| Testing complexity | MEDIUM | Must test all paths in both modes vs clear per-file coverage |
| Debugging difficulty | MEDIUM | Stack traces point to same class regardless of mode |
| Compilation output bloat | LOW | Compiled output would contain both mode branches unless gated |

## Risks of Keeping Separate

| Risk | Severity | Description |
|------|----------|-------------|
| Rule drift | LOW | Common rule updated in one trait method affects both — drift unlikely |
| Maintenance overhead | LOW | Two files per pair, but trait-based — real maintenance is in traits |
| Code duplication | LOW | Already at 65% sharing — remaining 35% is legitimately unique |

## Success Criteria (if unification proceeds later)

1. **Zero mode confusion**: Compiled output for `do:sync` contains ZERO async-specific phases, and vice versa
2. **Line reduction ≥ 15%**: Merged file must be ≥15% shorter than sum of separate files
3. **Test parity**: Same test coverage before and after, no regressions
4. **Readability**: Independent reviewer can identify execution path in <30 seconds
5. **Compile metrics**: verify-compile-metrics.sh still PASS

## Minimal Experiment (Not Refactor)

**Goal**: Validate whether trait extraction can be pushed further without merging classes.

**Scope**: DoCommandCommonTrait only (smaller surface, lower risk).

**Steps**:

1. Identify remaining duplicated code between DoSyncInclude and DoAsyncInclude that ISN'T in DoCommandCommonTrait
2. Extract any 3+ line duplicate blocks into new trait methods
3. Measure: line count before/after, verify compile metrics unchanged
4. Assess: if remaining unique code drops below 25%, unification may be worthwhile

**Expected outcome**: Either (a) remaining duplication is <10 lines (confirms separation is correct) or (b) 50+ lines extractable (signals unification opportunity).

**Time budget**: 2 hours max. If extraction yields <5% improvement, STOP and confirm deferral is correct.

## Decision

**DEFER indefinitely.** Current architecture is well-structured with 65% trait sharing. The 35% unique code represents genuinely different execution semantics. Unification is a premature optimization with more risk than reward.

**Revisit trigger**: If a new execution mode is added (e.g., `batch`, `stream`) and requires duplicating the same 35% unique code a third time, then unification becomes justified.
