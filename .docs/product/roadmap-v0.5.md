---
name: "Product Roadmap v0.5"
description: "Docs Index Cache v2 — incremental invalidation, stats endpoint, and health reporting"
type: roadmap
date: 2026-02-23
version: "0.5.0"
status: draft
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

| Feature | Description |
|---------|-------------|
| Incremental invalidation | Detect which docs changed via mtime/hash; rebuild only affected entries |
| Stats endpoint | `brain docs --stats` shows cache size, entry count, last rebuild, hit rate |
| Health report | `brain docs --cache-health` validates determinism (same query → same ordering) |
| Clear command | `brain docs --clear-cache` for manual invalidation |

### Non-Goals

- Federated search over network
- Real-time doc sync
- Permission-based access control
- Compression or encryption of cache

### Success Metric

| Metric | Target |
|--------|--------|
| Repeated global search (warm cache) | < 100ms median on medium repo (500+ docs) |
| Incremental rebuild (1 doc changed) | < 50ms |
| Determinism | Same query produces identical result ordering across runs |
| Cache hit rate (typical session) | > 95% |

### Effort & Risk

| Dimension | Rating | Rationale |
|-----------|--------|-----------|
| Effort | M | Building on M5 foundation; no new infra |
| Risk | S | Bounded scope; clear acceptance criteria |
| Dependencies | M5 | Already shipped |

### Key Risks

1. **mtime flakiness** — filesystem timestamps may not be reliable. Mitigation: hash comparison fallback.
2. **Large repo regression** — incremental may not help if hash calculation is expensive. Mitigation: parallel hashing, skip if unchanged via mtime first.

### Timeline (Draft)

| Week | Focus |
|------|-------|
| 1 | Incremental invalidation logic + hash comparison |
| 2 | Stats endpoint + health report |
| 3 | Performance validation + documentation |

### Cross-References

| Document | Relationship |
|----------|-------------|
| `.docs/product/m2-docs-global-search-spike.md` | Original design spike |
| `.docs/tools/brain-docs.md` | Current docs command docs |
| `.docs/architecture/brain-docs-architecture.md` | Docs tool architecture |
