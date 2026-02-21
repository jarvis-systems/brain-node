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
- All dependencies installed (`composer install` in core/ and cli/)

## Demo Steps

### 1. Worktree

```bash
git status --porcelain
```

Expected: empty output. Proves: no uncommitted changes, clean state.

### 2. Documentation

```bash
brain docs --validate
```

Expected: `valid:72, invalid:0, warnings:0`. Proves: all 72 docs have YAML front matter, no broken references.

### 3. Tests

```bash
composer test
```

Expected: `244 tests, 578 assertions, 0 failures`. Proves: full test coverage, deterministic compilation, merger invariants, node integrity, MCP schema validation.

### 4. Static Analysis

```bash
composer analyse
```

Expected: `0 errors` for both core (169 files) and CLI (125 files). Proves: type safety across entire codebase at PHPStan level 0.

### 5. Enterprise Audit (19 checks)

```bash
bash scripts/audit-enterprise.sh
```

Expected: `PASS:19, WARN:0, FAIL:0`. Proves: strict_types, no debug artifacts, no secret patterns, no unsafe exec, version consistency, compile clean-worktree, MCP schema enforcement.

### 6. Secret Scan (tracked files)

```bash
bash scripts/scan-secrets.sh
```

Expected: `No secrets found in tracked files`. Proves: zero credential leakage in current codebase.

### 7. History Secret Scan

```bash
bash scripts/scan-secrets-history.sh --quiet
```

Expected: `TOTAL_MATCHES=10, exit 2`. This is **not a failure** — it is a tracked, mitigated debt (P2-008). All matched credentials are provider-side revoked. Private repo exception applies per `10-pre-publication.md`. For publication, exit 0 is required (BFG/Option C cleanup).

### 8. Benchmark Suite (dry-run)

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
| Docs validate | 72 documents with consistent metadata |
| 244 tests green | Core logic, compilation determinism, node contracts |
| PHPStan 0 errors | Type safety across 294 files (core + CLI) |
| 19/19 audit PASS | Enterprise checklist: strict_types, no secrets, no debug, clean compile |
| Secret scan clean | Zero credentials in tracked files |
| History scan mitigated | Known debt tracked, credentials revoked, upgrade path documented |
| 82 benchmark scenarios | Full governance coverage: knowledge, commands, multi-turn, adversarial schemas |

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
