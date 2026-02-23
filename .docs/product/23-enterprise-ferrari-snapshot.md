---
name: "Enterprise Ferrari Snapshot"
description: "Current-state enterprise quality snapshot — single source of truth for all gate outputs and repo status"
type: product
date: 2026-02-22
version: "1.0.0"
status: active
---

# Enterprise Ferrari Snapshot

**Date:** 2026-02-22
**Base tag:** v0.2.0 (all 3 repos tagged and pushed)
**HEAD position:** post-tag dev (root: v0.2.0-22-g*, core: v0.2.0-5-g*, cli: v0.2.0-4-g*)

## Repo Topology

Three independent git repos co-located on disk. Not a monorepo. See `.docs/architecture/repo-topology.md`.

| Repo | Remote | Tag | HEAD status |
|------|--------|-----|-------------|
| root (brain-node) | jarvis-systems/brain-node | v0.2.0 | pushed, synced |
| core (brain-core) | jarvis-systems/brain-core | v0.2.0 | pushed, synced |
| cli (brain-cli) | jarvis-systems/brain-cli | v0.2.0 | 4 behind remote, WIP branch exists |

## Quality Gates

| # | Gate | Command | Result |
|---|------|---------|--------|
| 1 | Docs Validation | `brain docs --validate` | valid:98, invalid:0, warnings:0 |
| 2 | PHPUnit (core) | `composer test` | 273 tests, 645 assertions, 0 failures |
| 3 | PHPStan (core) | `composer analyse` (core) | 0 errors (170 files) |
| 4 | PHPStan (CLI) | `composer analyse` (cli) | 0 errors (131 files) |
| 5 | Enterprise Audit | `bash scripts/audit-enterprise.sh` | PASS:19, WARN:0, FAIL:0 |
| 6 | Secret Scan | `bash scripts/scan-secrets.sh` | 0 secrets in tracked files |
| 7 | History Scan | `bash scripts/scan-secrets-history.sh` | TOTAL_MATCHES=10, exit 2 (mitigated, P2-008) |

**Verdict: ALL GREEN** (history scan mitigated per private-repo exception).

**Doc count semantics:** The hard invariant is `invalid=0, warnings=0`. The `valid` count reflects the tracked `.docs/` set at commit time — moving drafts to `.work/` reduces it, adding new docs increases it. This is expected, not a regression.

## What Changed Since v0.2.0 Tag

Post-tag work focused on enterprise hardening without feature changes: audit Check 17c normalized to tag-existence semantics (eliminating false WARN on post-tag HEAD advance), `json_encode` calls in ConvertCommand received `JSON_THROW_ON_ERROR` flags, Core env access was split into filtered runtime path (`Core::env`/`allEnv`) and unfiltered compile-time path (`resolveCompileEnv`/`hasCompileEnv`) with expanded allowlist and deprecation wrappers, and repo-topology documentation received an env semantics section. Test count grew from 264 to 273 (+9 env split tests). Doc count grew from 87 to 90. All changes are backward-compatible with zero compiled-output diff.

## Known Debts

| ID | Debt | Status | Severity |
|----|------|--------|----------|
| P2-008 | Git history: 10 secret pattern matches in 6 commits | MITIGATED — credentials revoked | P2 |
| P2-009 | Worktree isolation contract: not CI-enforced | PLANNED | P2 |
| P2-003 | `error_log` in ConvertCommand | ACCEPTABLE — env-gated | P3 |
| — | CLI has 21 `dd()` calls (debug artifacts) | OPEN — vector tasks #47-#50 | P3 |
| — | ~~Root: 4 unpushed commits~~ | CLOSED — pushed 16e3501 | — |

## Canonical References

| Document | Path |
|----------|------|
| Scorecard (30.0/30) | `.docs/audits/enterprise-codebase/SCORECARD.md` |
| Fix Queue | `.docs/audits/enterprise-codebase/FIX-QUEUE.md` |
| Enterprise DoD | `.docs/audits/enterprise-codebase/ENTERPRISE-DOD.md` |
| Pre-Publication | `.docs/product/10-pre-publication.md` |
| Security 3.0 Playbook | `.docs/product/16-security-3.0-playbook.md` |
| Release Capsule v0.2.0 | `.docs/product/22-release-capsule-v0.2.0.md` |
| Repo Topology | `.docs/architecture/repo-topology.md` |
| Demo Script | `.docs/product/18-enterprise-demo-script.md` |
| Readiness Pack | `.docs/product/21-release-readiness-pack.md` |

## Truth-Sync Policy

This snapshot is CURRENT-STATE. Numeric values update when gates change. Frozen tag-time data lives in `22-release-capsule-v0.2.0.md` (never edited post-tag).
