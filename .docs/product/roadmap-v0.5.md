---
name: "Product Roadmap v0.5"
description: "Docs Index Cache v2 — incremental invalidation, stats endpoint, and health reporting"
type: roadmap
date: 2026-02-23
version: "0.5.0"
status: completed
---

# Product Roadmap v0.5

M5 delivered the initial docs index cache. v0.5 hardens it with invalidation rules, observability, and deterministic performance guarantees.

## Milestone: Docs Index Cache v2

### Problem

Global docs search (`--global`) now uses a cache, but:
- Cache invalidation is all-or-nothing (full rebuild on any change)
- No visibility into cache health or hit/miss rates
- Performance varies with repo size; no documented SLA

### Scope

| Feature | Description | Status |
|---------|-------------|--------|
| Incremental invalidation | Detect which docs changed via mtime/hash; rebuild only affected entries | ✅ Done |
| Stats endpoint | `brain docs --cache-stats` shows cache size, entry count, last rebuild, hit rate, timing breakdown | ✅ Done |
| Health report | `brain docs --cache-health` validates determinism (same query → same ordering) | ✅ Done |
| Clear command | `brain docs --clear-cache` for manual invalidation | ✅ Done |
| Top-K early-stop | Enrich only returned results, not all matches | ✅ Done |
| JSON output v2 | New shape: `{total_matches, files: [...]}` | ✅ Done |

### Non-Goals

- Federated search over network
- Real-time doc sync
- Permission-based access control
- Compression or encryption of cache
- Daemon mode for sub-100ms total CLI time

### Success Metric

| Metric | Target | Actual |
|--------|--------|--------|
| Command logic (warm cache) | < 100ms | ~17ms scan, ~0ms enrich ✅ |
| Incremental rebuild (1 doc changed) | < 50ms | ~20ms ✅ |
| Determinism | Same query → identical ordering | ✅ Verified by tests |
| Cache hit rate (typical session) | > 95% | 100% after warmup ✅ |

**Performance Reality:**

| Metric | Value | Notes |
|--------|-------|-------|
| Laravel/PHP bootstrap | ~128ms | Unavoidable per-process overhead |
| Command logic (warm) | ~17ms | Well under 100ms target |
| Total CLI time | ~150ms | Dominated by bootstrap |

**Future Work:** Sub-100ms total CLI time requires daemon mode (persistent process). The command logic itself is already optimized.

### Effort & Risk

| Dimension | Rating | Rationale |
|-----------|--------|-----------|
| Effort | M | Building on M5 foundation; no new infra |
| Risk | S | Bounded scope; clear acceptance criteria |
| Dependencies | M5 | Already shipped |

### Key Risks

1. **mtime flakiness** — filesystem timestamps may not be reliable. Mitigation: hash comparison fallback. ✅ Implemented
2. **Large repo regression** — incremental may not help if hash calculation is expensive. Mitigation: parallel hashing, skip if unchanged via mtime first. ✅ Implemented

### Timeline

| Week | Focus | Status |
|------|-------|--------|
| 1 | Incremental invalidation logic + hash comparison | ✅ Done |
| 2 | Stats endpoint + health report | ✅ Done |
| 3 | Performance validation + documentation | ✅ Done |

### Completion Evidence

- Commit: `1ca7e44` (CLI) — top-K early-stop + JSON output v2
- Commit: `88f1b13` (CLI) — timing breakdown + freshness caching
- Commit: `627e969` (CLI) — v2 index cache with stats + health
- Tests: 714 passing, 1605 assertions
- PHPStan: L2 clean

### Cross-References

| Document | Relationship |
|----------|--------------|
| `.docs/product/m2-docs-global-search-spike.md` | Original design spike |
| `.docs/tools/brain-docs.md` | Current docs command docs |
| `.docs/architecture/brain-docs-architecture.md` | Docs tool architecture |
