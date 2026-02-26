---
name: "Prompt Change Contract"
description: "ADR-style process governing changes to prompts, scenarios, and benchmark scripts"
type: "contract"
date: "2026-02-21"
version: "1.0"
status: "active"
---

# Prompt Change Contract

## Scope

This contract applies to any change touching:

- `.brain/node/` — includes, agents, commands, skills (compiled prompt sources)
- `.docs/benchmarks/scenarios/` — benchmark scenario definitions
- `scripts/benchmark-*.sh` — benchmark runner and regression scripts

## PR Gate (Required Before Merge)

Every PR modifying files in scope MUST pass these gates (zero API cost):

1. **Dry-run all profiles**: full, ci, nightly-live, telemetry-ci, cmd-auto, free-live, golden-live
2. **Instruction budget**: `check-instruction-budget.sh --strict` (10% delta max)
3. **Unit tests**: `composer test`
4. **Static analysis**: `composer analyse`
5. **Compile discipline**: source changes require matching compiled output
6. **Docs validation**: `brain docs --validate`

All gates are enforced by CI (brain-lint.yml + pr-gate).

## Live Proof (Required After Merge)

Live proof is obtained automatically via the next nightly run after merge. It is NOT required before merge.

Two nightly live profiles run in parallel:

- **nightly-live** (8 scenarios, claude/sonnet) — behavioral verification, paid
- **free-live** (8 scenarios, opencode/minimax-m2.5-free) — structural stress test, $0 cost

Both profiles:
- Retry: enabled (1 retry per scenario for flakiness detection)
- Regression check: WARN mode against separate baselines
- Profile-agent binding enforced (free-live → opencode, prevents accidental paid usage)

No manual live run is needed — the nightly pipeline provides proof for both profiles.

**Golden verification** (golden-live, claude/opus) is manual-only and not part of post-merge proof. Use it before major releases per the Model Strategy Contract.

## Baselines Update Rules

Update `.docs/benchmarks/baselines/baselines.json` ONLY when:

1. **Adding or removing scenarios** from a profile (scenario count changes)
2. **Persistent measurement change** — values exceed 80% of budget ceiling for 3 consecutive nightly runs (stability window)

Do NOT update baselines for:

- Single-run spikes (variance, not regression)
- Flaky scenarios (fix the scenario or patterns instead)
- Preemptive headroom increases without observed data

## Rollback Policy

If nightly-live or free-live fails for 2 consecutive nights after a prompt change merge:

1. Identify the failing scenarios and their FLAKY/FAIL status
2. If FLAKY_FAIL: check if pattern broadening or retry increase resolves it
3. If consistent FAIL: revert the prompt change commit
4. Post-mortem: document why the change caused regression before re-attempting
