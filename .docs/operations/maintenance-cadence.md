---
name: "Maintenance Cadence Runbook"
description: "Lightweight routine for keeping Brain enterprise-grade without slowing product work"
type: runbook
date: 2026-02-23
version: "1.0.0"
status: active
---

# Maintenance Cadence Runbook

## Principle

Enterprise-grade systems require minimal but consistent maintenance. This runbook defines a lightweight cadence that catches drift early without burdening product velocity. Total time investment: ~15 minutes weekly, ~45 minutes monthly.

## Cadence Summary

| Frequency | Duration | Commands |
|-----------|----------|----------|
| Weekly | 10–15 min | readiness + memory + docs spot-check |
| Monthly | 30–45 min | hygiene + optional consolidation |
| Pre-release | 15–20 min | prepare + compile + verify |

## Weekly Routine (10–15 min)

### 1. Readiness Check

```bash
brain readiness:check
```

Verifies: CI gates, version alignment, compile discipline, docs validation. Review any WARN items.

### 2. Memory Status

```bash
brain memory:status
```

Quick health snapshot: entry counts, category distribution, last hygiene timestamp. Flag if hygiene not run in 14+ days.

### 3. Docs Freshness Spot-Check

```bash
brain docs <topic> --global --freshness=30
```

Pick a topic relevant to recent work. Confirms docs index is current and external docs (if any) are not stale.

**What to look for:**
- Results return as expected
- No `freshness.bucket: stale` on critical docs
- External docs re-download prompt (if >30 days old)

## Monthly Routine (30–45 min)

### 1. Memory Hygiene

```bash
brain memory:hygiene --human
```

Or default JSON with artifact review:

```bash
brain memory:hygiene
cat .work/memory-hygiene/smoke-results.json | jq '.summary'
```

**Review artifacts:**
- `ledger.json` — count trends, category balance
- `smoke-results.json` — probe pass rate, any persistent FAILs
- `rank-safety.json` — semantic cluster health

### 2. Optional Topic Consolidation

Only if one of these triggers:
- Smoke test pass rate < baseline (check `.work/memory-hygiene/smoke-results.json`)
- Active memories > threshold (check ledger `total_memories`)
- Topic cluster exceeds 30 entries (manual review)

```bash
brain memory:hygiene --consolidate --yes
```

Consolidation is destructive. Review probe failures first to understand what's being pruned.

## Pre-Release Routine (15–20 min)

### 1. Release Prepare

```bash
brain release:prepare vX.Y.Z --evidence --json
```

Generates evidence pack: version alignment, tag checks, readiness gate, release capsule.

**Review output:**
- All repos version-aligned
- Tags exist and match
- Readiness gate passed
- No FAIL in evidence pack

### 2. Compile Diff

```bash
brain compile --diff --json
```

Confirms compiled artifacts match source. Exit code 0 = clean, 2 = needs recompile.

### 3. Format Verification

```bash
bash scripts/verify-client-formats.sh
```

Catches format drift across all client targets.

### 4. Lock Sync Check

```bash
# Check composer.lock is in sync
composer validate --strict
git diff --exit-code composer.lock
```

Handle any `lock_sync: warn` from release prepare before proceeding.

## CI Health Check (5 min)

### 1. Confirm Latest Runs Green

Navigate to GitHub Actions. Verify:
- `brain-lint` — PASS on latest master
- `brain-benchmark` (if scheduled) — PASS or known SKIPs
- `brain-release` (if tagged) — PASS

### 2. Secrets/Auth Note

Confirm PAT scope includes:
- `repo` (for private repos)
- `workflow` (for CI triggers)

No secrets in output. Rotate if exposure suspected.

## Quick Reference

| Task | Command | Frequency |
|------|---------|-----------|
| Readiness | `brain readiness:check` | Weekly |
| Memory status | `brain memory:status` | Weekly |
| Docs freshness | `brain docs <topic> --global --freshness=30` | Weekly |
| Memory hygiene | `brain memory:hygiene --human` | Monthly |
| Consolidation | `brain memory:hygiene --consolidate --yes` | On trigger |
| Release prep | `brain release:prepare vX.Y.Z --evidence --json` | Pre-release |
| Compile diff | `brain compile --diff --json` | Pre-release |
| Format verify | `bash scripts/verify-client-formats.sh` | Pre-release |

## Cross-References

| Document | Relationship |
|----------|-------------|
| `.docs/product/03-runbooks.md` | Main runbooks index |
| `.docs/operations/memory-hygiene-runbook.md` | Detailed hygiene procedures |
| `.docs/audits/enterprise-codebase/ENTERPRISE-DOD.md` | Enterprise quality gates |
| `.docs/product/10-pre-publication.md` | Full release checklist |
