---
name: "Release Capsule v0.5.0"
description: "Frozen release-state reference for v0.5.0 — tag-time invariant, operator commands, key deltas"
type: product
date: 2026-02-24
version: "v0.5.0"
status: frozen
---

# Release Capsule v0.5.0

Frozen snapshot of v0.5.0 tag-time truth. Post-tag commits (docs, CI tweaks) move HEAD past the tag — this is normal dev flow, not release regression. The release state is defined by what the tag points to.

## 1. Tag Identity

| Field | Value |
|-------|-------|
| Tag | `v0.5.0` |
| Repos | brain-node, brain-core, brain-cli |
| Tag-time | 2026-02-23T21:41:11Z |
| CI Status | Infra issue (private repo auth) — not a product defect |

## 2. Reproduce Release State

```bash
git checkout v0.5.0
git describe --tags --exact-match           # v0.5.0
jq -r '.version' composer.json             # v0.5.0
bash scripts/audit-enterprise.sh            # PASS:20, WARN:0, FAIL:0
brain docs --validate                       # valid:102, invalid:0, warnings:0
```

## 3. Gates at Tag-Time

| Gate | Result |
|------|--------|
| audit-enterprise.sh | PASS:20 / WARN:0 / FAIL:0 |
| brain docs --validate | valid=102, invalid=0, warnings=0 |
| Core PHPUnit | 284 tests, 653 assertions |
| Core PHPStan | 0 errors (L4) |
| CLI PHPUnit | 721 tests, 1630 assertions |
| CLI PHPStan | 0 errors (L2) |
| verify-compile-metrics.sh | PASS (std=316, exh=598, delta=282) |
| verify-client-formats.sh | PASS |

## 4. What Changed in v0.5.0

- **ENV Precedence Fix**: Restored dotenv immutability — process env now wins over `.brain/.env` (critical for STRICT_MODE / COGNITIVE_LEVEL tier switching)
- **Model-ID Strict Gate**: OpenCode agents require full `provider/model` IDs; bare aliases rejected at compile-time
- **Skills v1**: 5 skills added — `client-format-triage`, `docs-truth-sync`, `evidence-pack-builder`, `health-check`, `repo-boundary-preflight`
- **Compile Metrics Guard**: Phase 5 added to `verify-compile-metrics.sh` — ENV override verification
- **Client Format Guards**: `verify-client-formats.sh` expanded with model ID canonical checks
- **Docs Index Cache v2**: Top-K early-stop + JSON output trimming for <100ms target
- **JSON schema_version**: Contract stability for CLI JSON outputs
- **Unit Tests**: CLI test suite expanded (721 tests, +25 from v0.4.0)

## 5. Known Limitations at Tag-Time

- Root CI private repo auth issue (infra, not product)
- Release capsule v0.3/v0.4 skipped — historical gap
- Lock sync warning during release:prepare (cosmetic, resolved post-tag)

## 6. Canonical References

- [10-pre-publication.md](10-pre-publication.md) — publication checklist
- [24-final-gate-snapshot.md](24-final-gate-snapshot.md) — gate reference
- [25-enterprise-proof-pack.md](25-enterprise-proof-pack.md) — evidence bundle
- `.agents/skills/*/SKILL.md` — skill definitions
- `.work/releases/v0.5.0/` — release evidence pack
