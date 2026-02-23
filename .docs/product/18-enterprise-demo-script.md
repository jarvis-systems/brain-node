---
name: "Enterprise Demo Script"
description: "Operator-ready 2-3 minute demo proving Enterprise Ferrari quality level using existing CI gates"
type: product
date: 2026-02-21
version: "1.0.0"
status: active
---

# Enterprise Demo Script

Prove enterprise quality in 2-3 minutes. Copy-paste commands, observe green gates.

## Preconditions

- Quad-mode stabilization window active (no parallel agents running)
- Worktree clean: `git status --porcelain` returns empty
- Repo boundary confirmed: `git rev-parse --show-toplevel` returns root repo path. If demo touches core/ or cli/, verify sub-repo boundary: `cd core && git rev-parse --show-toplevel && cd ..`. Three independent repos share the disk — see `.docs/architecture/repo-topology.md`. For copy-paste preflight snippet and commit decision tree, see § "Repo Boundary Preflight" in the same doc.
- All dependencies installed (`composer install` in core/ and cli/)

## Demo Steps

### 1. Worktree

```bash
git status --porcelain
```

Expected: empty output. Proves: no uncommitted changes, clean state.

### 2. Version Signals (DEV snapshot)

```bash
git describe --tags --always
git -C core describe --tags --always
git -C cli describe --tags --always
```

Expected: three version strings, e.g. `v0.2.0-51-gabcdef0`. The `-N-gXXXXXXX` suffix is normal in dev — it means N commits since the last tag. Proves: all three repos are accessible and have version history.

### 3. Documentation

```bash
brain docs --validate
```

Expected: `valid:98, invalid:0, warnings:0`. Proves: all 98 docs have YAML front matter, no broken references.

### 4. Tests

```bash
composer test
```

Expected: `273 tests, 645 assertions, 0 failures`. Proves: full test coverage, deterministic compilation, merger invariants, node integrity, MCP schema validation.

### 5. Static Analysis

```bash
composer analyse
```

Expected: `0 errors` for both core (170 files) and CLI (125 files). Proves: type safety across entire codebase at PHPStan level 2.

### 6. Enterprise Audit (19 checks)

```bash
bash scripts/audit-enterprise.sh
```

Expected: `PASS:19, WARN:0, FAIL:0`. All three repos are version-aligned to `v0.2.0` with exact-match tags — version-drift is CLOSED. Proves: strict_types, no debug artifacts, no secret patterns, no unsafe exec, version consistency, compile clean-worktree, MCP schema enforcement.

### 7. Secret Scan (tracked files)

```bash
bash scripts/scan-secrets.sh
```

Expected: `No secrets found in tracked files`. Proves: zero credential leakage in current codebase.

### 8. History Secret Scan

```bash
bash scripts/scan-secrets-history.sh --quiet
```

Expected: `TOTAL_MATCHES=10, exit 2`. This is **not a failure** — it is a tracked, mitigated debt (P2-008). All matched credentials are provider-side revoked. Private repo exception applies per `10-pre-publication.md`. For publication, exit 0 is required (BFG/Option C cleanup).

### 9. Benchmark Suite (dry-run)

```bash
bash scripts/benchmark-llm-suite.sh --dry-run --profile full
bash scripts/benchmark-llm-suite.sh --dry-run --profile telemetry-ci
bash scripts/benchmark-llm-suite.sh --dry-run --profile cmd-auto
```

Expected: `42/42`, `12/12`, `28/28` — all 82 unique scenarios pass schema validation. Proves: scenario integrity, no broken JSON, all profiles operational.

## How to Narrate

| Gate | What it proves |
|------|---------------|
| Clean worktree | No drift, no forgotten changes |
| Version signals | All three repos accessible, version history intact |
| Docs validate | 98 documents with consistent metadata |
| 273 tests green | Core logic, compilation determinism, node contracts |
| PHPStan 0 errors | Type safety across 295 files (core + CLI) |
| 19/19 audit PASS | Enterprise checklist: strict_types, no secrets, no debug, clean compile. WARN:0 — version-drift CLOSED |
| Secret scan clean | Zero credentials in tracked files |
| History scan mitigated | Known debt tracked, credentials revoked, upgrade path documented |
| 82 benchmark scenarios | Full governance coverage: knowledge, commands, multi-turn, adversarial schemas |

**Note:** This demo proves quality gates in **dev mode**. Release mode requires exact-match tags + `composer.json` alignment across all three repos (BLOCKING) — see `.docs/product/10-pre-publication.md` § "Version Alignment".

## Known Debts

| ID | Debt | Status | Impact |
|----|------|--------|--------|
| P2-008 | Git history contains 10 secret pattern matches in 6 commits | MITIGATED — credentials revoked, baseline tracked | Zero operational risk; cleanup via Option C before publication |
| P2-009 | Worktree isolation contract written, not yet CI-enforced | PLANNED | Contract in `17-worktree-isolation-contract.md`; manual compliance |
| P2-003 | `error_log` in ConvertCommand | ACCEPTABLE | Env-gated, not a leak vector |

## Canonical References

| Document | Path |
|----------|------|
| Scorecard (30.0/30) | `.docs/audits/enterprise-codebase/SCORECARD.md` |
| Fix Queue | `.docs/audits/enterprise-codebase/FIX-QUEUE.md` |
| Pre-Publication Checklist | `.docs/product/10-pre-publication.md` |
| Worktree Isolation Contract | `.docs/product/17-worktree-isolation-contract.md` |
| Security 3.0 Playbook | `.docs/product/16-security-3.0-playbook.md` |
| Enterprise DoD | `.docs/audits/enterprise-codebase/ENTERPRISE-DOD.md` |
