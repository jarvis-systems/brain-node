---
name: "State of the System — 2026-02-22"
description: "Point-in-time snapshot of repo baselines, CI gates, security posture, and memory hygiene"
type: "snapshot"
date: "2026-02-22"
status: "active"
---

# State of the System — 2026-02-22

## Repo Baselines

### brain-core (v0.2.0)

| Metric | Value |
|--------|-------|
| PHPStan level | 4 (L1→L3 via `9cbcb15`/`35dbd2a`/`ef8b315`; L3→L4: 6 errors, inline ignores + neon ignore) |
| Tests | 273 tests, 645 assertions |
| Composer audit | Clean (0 advisories) |

### brain-cli (v0.2.0)

| Metric | Value |
|--------|-------|
| PHPStan level | 2 |
| Tests | 640 tests, 1390 assertions |
| Composer audit | Clean (0 advisories) |
| CI gates | Lock sync guard, private repo guard, PHPStan, PHPUnit, security audit |

### brain-node

| Metric | Value |
|--------|-------|
| CI pipeline | 22 steps, all green (run `22284578303`) |
| PHPStan level guard | Enforced — core >= L4, cli >= L2 |
| Enterprise audit | Passing (P0 gate) |
| Compile discipline | Enforced |

## Security Posture

- Composer audit clean across all three packages.
- Composer lock drift guard in brain-cli CI (`composer validate` + `git diff --exit-code`).
- Private repo availability guard (`composer show jarvis-brain/core`).
- Secret scanning active in brain-node pipeline.
- PHPStan level guard prevents silent analysis downgrades.

## Memory Hygiene

- Memory hygiene command available via CI and local.
- NO_DATA mode handled gracefully (commit `b53419b`).
- Rank safety gate exists for memory operations.
- Current smoke baseline (local): 12/15, critical probes 7/7.

## Recent Key Commits

| Repo | Hash | Description |
|------|------|-------------|
| brain-core | `ef8b315` | PHPStan level 2 to 3 uplift |
| brain-core | `ae2689a` | Explicit env access split |
| brain-cli | `512e41d` | Lock/JSON sync fix (PR #3) |
| brain-cli | `7708a28` | Composer drift prevention guards (PR #4) |
| brain-node | `3f51980` | PHPStan level guard CI enforcement |
| brain-node | `7ac4dd9` | Audit check 17c tag existence fix |

## Tags

| Repo | Latest Tag |
|------|-----------|
| brain-core | v0.2.0 |
| brain-cli | v0.2.0, v0.0.2, v0.0.1 |

## Next Milestone Candidates

### 1. Retrieval tuning — raise smoke baseline to >= 14/15

Non-critical probes at 12/15 indicate semantic search radius gaps. Tuning query phrasing and tag weights should close 2-3 misses without code changes. High ROI: improves every future memory-dependent operation at zero runtime cost.

### 2. Core PHPStan L4 exploration

L3 uplift was PHPDoc-only (30 fixes). L4 introduces strict return type and property type checks — likely requires code changes, not just annotations. Worth a spike to count errors and assess effort. Medium ROI: catches real type bugs, but may require non-trivial refactoring.

### 3. Seeded CI memory namespace

A deterministic, pre-populated vector store for CI runs would make memory-dependent benchmark scenarios fully reproducible and eliminate flakiness from empty-store edge cases. Medium ROI: enables reliable execution scenarios in CI, but requires namespace isolation infrastructure.
