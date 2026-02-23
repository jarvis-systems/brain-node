---
name: "Final Gate Snapshot"
description: "Authoritative current-state gate results — single table of truth for all enterprise quality signals"
type: product
date: 2026-02-22
version: "1.0.0"
status: active
---

# Final Gate Snapshot

## Gates

| Gate | Command | Result |
|------|---------|--------|
| Docs Validation | `brain docs --validate` | valid:98, invalid:0, warnings:0 |
| Enterprise Audit | `bash scripts/audit-enterprise.sh` | PASS:19, WARN:0, FAIL:0 |
| Core Tests | `composer test` | 273 tests, 645 assertions, 0 failures |
| PHPStan (core) | `composer analyse` (core/) | 0 errors (170 files) |
| PHPStan (CLI) | `composer analyse` (cli/) | 0 errors (131 files) |
| Secret Scan | `bash scripts/scan-secrets.sh` | 0 secrets in tracked files |
| Tags | `git tag -l v0.2.0` in root/core/cli | v0.2.0 exists in all 3 repos |

GO PRE-PUB exact-match check (`git describe --tags --exact-match`) is a release-time gate defined in `10-pre-publication.md` § Version Alignment. Not rerun here — HEAD is past tag in dev (expected).

## Semantics

- **Hard gates (blocking):** `invalid=0`, `warnings=0`, `FAIL=0`, `0 failures` in tests. Any violation = merge blocked.
- **Informational (non-blocking):** `valid` doc count depends on the tracked `.docs/` set — adding or moving docs changes it. HEAD position past tag is normal in dev.
- **Frozen data:** Tag-time gate values live in `22-release-capsule-v0.2.0.md` and are never edited post-tag.

## Output Contract

This document is subject to the **Plan-Only vs Evidence-Only** dual-mode contract:

- **PLAN-ONLY:** Template/checklist. Banner required: `PLAN-ONLY: No repo state was read.`
- **EVIDENCE-ONLY:** Every row must have live command output. Missing output → `UNVERIFIED` + STOP.
- **Mode rule:** "evidence/verify/current/snapshot" → Evidence. "checklist/runbook/plan" → Plan. Ambiguous → Evidence.

Canonical command set and full contract: `10-pre-publication.md` §7 Output Contract.

## References

| Document | Purpose |
|----------|---------|
| `21-release-readiness-pack.md` | Full evidence pack with per-repo gate detail |
| `22-release-capsule-v0.2.0.md` | Frozen tag-time snapshot (v0.2.0) |
| `23-enterprise-ferrari-snapshot.md` | Extended current-state with debts and changelog |
| `10-pre-publication.md` | GO PRE-PUB checklist and version alignment |
