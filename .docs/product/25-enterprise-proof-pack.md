---
name: "Enterprise Proof Pack"
description: "Technical pitch — reproducible evidence of enterprise quality in 2 minutes, offline, tamper-evident"
type: product
date: 2026-02-23
version: "1.0.0"
status: active
---

# Enterprise Proof Pack

Run one command. Get cryptographic proof of code quality. Share the evidence bundle safely.

## What This Proves

| Property | Evidence | Gate |
|----------|----------|------|
| **Determinism** | Compile produces identical output | `check-compile-clean.sh` |
| **Type Safety** | PHPStan L4 (core) + L2 (CLI), 0 errors | `composer analyse` |
| **Test Coverage** | 284 tests, 656 assertions | `composer test` |
| **Secret Hygiene** | No secrets in tracked files | `scan-secrets.sh` |
| **Audit Discipline** | 20-category checklist: strict_types, no debug, no unsafe exec | `audit-enterprise.sh` |
| **Instruction Integrity** | 101 docs validated, YAML front matter | `brain docs --validate` |
| **Version Consistency** | All 3 repos aligned to v0.4.0 | Audit Check 17 |

## How to Reproduce

```bash
bash scripts/run-enterprise-gates.sh
```

**Expected output:**
```
TOTAL: 7/7 PASS
RESULT: PASS (all gates green)
Evidence bundle: dist/evidence/enterprise-gates-YYYYMMDD-HHMMSS/
Manifest: dist/evidence/.../manifest.json
```

**Exit code:** 0 = all gates pass, 1 = any gate fails

**Runtime:** ~60 seconds on commodity hardware. No AI model required.

## Evidence Bundle Contents

| File | Content |
|------|---------|
| `gates-summary.txt` | PASS/FAIL table for all 7 gates |
| `versions.txt` | Root/core/cli version snapshot |
| `audit-output.txt` | Full 20-category enterprise audit |
| `compile-metrics.txt` | Line counts (std=316, exh=598) |
| `manifest.json` | SHA256 hashes for tamper-evident verification |
| `manifest.txt` | Human-readable file inventory |

**Verify integrity:**
```bash
cd dist/evidence/enterprise-gates-XXXXXX/
shasum -a 256 -c <(jq -r '.files[] | "\(.sha256)  \(.path)"' manifest.json)
```

## Security Posture

| Property | Guarantee |
|----------|-----------|
| **No secrets output** | Gates print only counts, status, file names — never env values or credentials |
| **Offline** | Zero network calls during execution |
| **Tamper-evident** | Manifest hashes let recipients verify bundle integrity |
| **Local only** | No data leaves the machine |

**Redaction rule:** Any file that could contain secrets (`.env`, `settings.json`, credentials) is excluded from evidence by design.

## Non-Goals / Limitations

- **Not a penetration test** — static analysis only, no runtime attack simulation
- **Not a legal audit** — compliance (SOC2, GDPR) requires separate certification
- **Not a performance benchmark** — gate timing is informational only
- **Does not scan git history** — history secrets tracked separately via `scan-secrets-history.sh`
- **Requires clean worktree** — uncommitted changes cause compile-clean gate to fail
- **Single-repo scope** — run separately for root, core, CLI if needed

## Links to Canon

| Document | Path |
|----------|------|
| Demo Script | `.docs/product/18-enterprise-demo-script.md` |
| Security Model | `.docs/product/04-security-model.md` |
| Security 3.0 Playbook | `.docs/product/16-security-3.0-playbook.md` |
| Enterprise DoD | `.docs/audits/enterprise-codebase/ENTERPRISE-DOD.md` |
| Scorecard (30.0/30) | `.docs/audits/enterprise-codebase/SCORECARD.md` |
| Pre-Publication Checklist | `.docs/product/10-pre-publication.md` |
