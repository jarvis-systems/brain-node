---
name: "Release Readiness Pack v2"
description: "Enterprise release readiness evidence for v0.2.0 — version-aligned, all gates green"
type: evidence
date: 2026-02-22
version: "2.0.0"
status: active
---

# Release Readiness Pack v2

Produced: 2026-02-22. Target version: `v0.2.0`.

## Repo Topology

| Repo | Path | Remote | Role |
|------|------|--------|------|
| root (brain-node) | `/` | `jarvis-systems/brain-node` | Orchestration, docs, compiled output |
| core (brain-core) | `/core` | `jarvis-systems/brain-core` | PHP library: compilation, archetypes, tools |
| cli (brain-cli) | `/cli` | `jarvis-systems/brain-cli` | CLI tool: brain compile, brain make:*, brain docs |

See also: `.docs/architecture/repo-topology.md` § Canonical Version Sources.

## Version Alignment Proof

All three repos tagged `v0.2.0` on HEAD with exact-match.

| Repo | composer.json | git describe --exact-match | git tag pushed |
|------|--------------|---------------------------|----------------|
| root | v0.2.0 | v0.2.0 | origin/v0.2.0 |
| core | v0.2.0 | v0.2.0 | origin/v0.2.0 |
| cli | v0.2.0 | v0.2.0 | origin/v0.2.0 |

**Verification commands:**

```bash
# Root
cd /path/to/jarvis-brain-node
git describe --tags --exact-match   # Expected: v0.2.0
jq -r '.version' composer.json     # Expected: v0.2.0

# Core
cd core
git describe --tags --exact-match   # Expected: v0.2.0
jq -r '.version' composer.json     # Expected: v0.2.0

# CLI
cd ../cli
git describe --tags --exact-match   # Expected: v0.2.0
jq -r '.version' composer.json     # Expected: v0.2.0
jq -r '.require["jarvis-brain/core"]' composer.json  # Expected: ^v0.2.0
```

**Version-drift status: CLOSED.** Audit check 17 (Version consistency) now returns PASS with zero warnings.

## Gates Snapshot

| Gate | Repo | Command | Result |
|------|------|---------|--------|
| PHPUnit | core | `cd core && composer test` | 264 tests, 620 assertions, 0 failures |
| PHPStan (core) | core | `cd core && composer analyse` | 0 errors (170 files) |
| PHPStan (cli) | cli | audit check #12 | 0 errors |
| Enterprise Audit | root | `bash scripts/audit-enterprise.sh` | PASS:19, WARN:0, FAIL:0 |
| Docs Validation | root | `brain docs --validate` | valid:87, invalid:0, warnings:0 |
| Secret Scan | root | `bash scripts/scan-secrets.sh` | 0 secrets in tracked files |
| Compile | root | `brain compile` | 4 targets (claude, codex, gemini, opencode) |
| Clean Worktree | all | `git status` (tracked) | Clean in all 3 repos |

### Source of Truth

```bash
cd core && composer test            # PHPUnit (core)
composer analyse                    # PHPStan (root proxies to core)
bash scripts/audit-enterprise.sh    # Enterprise audit (root, scans all 3 repos)
brain docs --validate               # Docs validation (root .docs/)
bash scripts/scan-secrets.sh        # Secret scan (root tracked files)
brain compile                       # Compilation (root, 4 targets)
```

## Known Dev-Only Semantics

Root `composer.json` uses path repository with `"*"` constraint for `jarvis-brain/core`:

```json
"repositories": [{ "type": "path", "url": "./core", "options": { "symlink": true } }],
"require": { "jarvis-brain/core": "*" }
```

This is **dev semantics** — enables symlink-based development without version pinning. For a registry-based release, this constraint would change to `"^v0.2.0"` and `composer.lock` would be regenerated from Packagist. This is documented as the next GO PRE-PUB step but is not required for the current tagged release.

See: `.docs/product/10-pre-publication.md` § "Version Alignment".

## Audit Detail

19 categories, all PASS:

| # | Category | Status |
|---|----------|--------|
| 1 | PHP syntax check | PASS |
| 2 | PHPUnit tests | PASS |
| 3 | Silent catch blocks | PASS |
| 4 | Debug artifacts | PASS |
| 5 | eval() usage | PASS |
| 6 | exec/shell_exec/system usage | PASS |
| 7 | Core phpstan | PASS |
| 8 | Core tests | PASS |
| 9 | CLI tests | PASS |
| 10 | CLI composer dependencies | PASS |
| 11 | CLI autoload | PASS |
| 12 | CLI phpstan | PASS |
| 13 | Missing declare(strict_types=1) | PASS |
| 14 | Secret patterns in tracked files | PASS |
| 15 | Hardcoded user paths | PASS |
| 16 | Degradation observability in catch blocks | PASS |
| 17 | Version consistency | PASS |
| 18 | MCP schema bypass enforcement | PASS |
| 19 | Compile clean-worktree gate | PASS |

## Summary

Enterprise release gates: **all green**. Version-drift: **CLOSED**. Three repos aligned to `v0.2.0` with exact-match tags on HEAD, pushed to remote. Zero WIP branches. Tests (core): 264/620. Docs (root): 87 valid. PHPStan (core+cli): 0 errors. Audit (root): PASS:19 WARN:0 FAIL:0.
