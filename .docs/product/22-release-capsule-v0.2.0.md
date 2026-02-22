---
name: "Release Capsule v0.2.0"
description: "Frozen release-state reference for v0.2.0 — tag-time invariant, operator commands, known dev deltas"
type: product
date: 2026-02-22
version: "v0.2.0"
status: active
---

# Release Capsule v0.2.0

## 1. What This Document Means

This capsule captures the **tag-time invariant** for v0.2.0 — the exact state at the moment all three repos were tagged and gates verified. It is a frozen reference point.

Post-tag commits (documentation, CI tweaks) move HEAD past the tag. This is normal development flow, not a release regression. The audit's version-drift check will report WARN:1 for untagged HEAD — this is expected and does not invalidate the release.

**Rule:** Do not chase micro-deltas caused by post-tag doc commits. The release state is defined by what the tag points to, not by HEAD.

## 2. Reproduce Release State

Checkout the tag to reproduce exact release conditions:

```bash
# Root
git checkout v0.2.0
git describe --tags --exact-match           # v0.2.0
jq -r '.version' composer.json             # v0.2.0
bash scripts/audit-enterprise.sh            # PASS:19, WARN:0, FAIL:0
brain docs --validate                       # invalid:0, warnings:0

# Core
cd core
git checkout v0.2.0
git describe --tags --exact-match           # v0.2.0
composer test                               # 264 tests, 620 assertions, 0 failures
composer analyse                            # 0 errors

# CLI
cd ../cli
git checkout v0.2.0
git describe --tags --exact-match           # v0.2.0
jq -r '.require["jarvis-brain/core"]' composer.json  # ^v0.2.0

# Return to master
cd .. && git checkout master
cd core && git checkout master
cd ../cli && git checkout master
```

## 3. Known Dev-Mode Deltas

These are NOT release regressions:

| Delta | Cause | Impact |
|-------|-------|--------|
| Audit WARN:1 (version-drift) on HEAD | Doc/CI commits after tag | None — tag state is WARN:0 |
| Docs count increments (87, 88, ...) | New docs added post-tag | Expected growth |
| `.compile-stamp` untracked | Brain compile artifact | Gitignored by convention |
| `.work/` untracked | Memory hygiene artifacts | Gitignored by convention |

## 4. Canonical References

| Document | What It Covers |
|----------|---------------|
| `10-pre-publication.md` | GO PRE-PUB runbook, version alignment procedure |
| `21-release-readiness-pack.md` | Full gate evidence, audit detail, repo-scoped counters |
| `17-worktree-isolation-contract.md` | Worktree safety, isolation phases |
| `architecture/repo-topology.md` | Three-repo topology, version source of truth |

## 5. Enterprise Snapshot

### Commit References

| Repo | Tag-time commit (v0.2.0) | Post-tag HEAD | Delta |
|------|-------------------------|---------------|-------|
| root | `b976e2d` | `1efd08c` | +12 (docs + CI only) |
| core | `1e81181` | `1e81181` | 0 |
| cli | `613c698` | `af1c188` | +1 (CI fix) |

### Tag-Time Release State

| Gate | Result | Scope |
|------|--------|-------|
| Tests | 264 tests, 620 assertions, 0 failures | core |
| PHPStan | 0 errors (170 files core + cli) | core + cli |
| Audit | PASS:19, WARN:0, FAIL:0 | root (scans all 3 repos) |
| Docs | valid:87, invalid:0, warnings:0 | root |
| Compile | 4 targets clean | root |
| Secrets | 0 in tracked files | root |

**Tag-time release state (v0.2.0): PASS:19 WARN:0 FAIL:0.**
**Post-tag doc drift allowed: YES (docs-only).**
