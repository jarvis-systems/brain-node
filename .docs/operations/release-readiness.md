---
name: "Release Readiness"
description: "Pre-release and pre-merge quality checklist via brain readiness:check"
type: runbook
date: 2026-02-22
---

# Release Readiness Check

Single command that bundles all local pre-release/pre-merge quality gates into one JSON summary.

## When to Use

- Before tagging a release
- Before merging to main
- After major refactors
- As a CI pre-merge gate

## Usage

```bash
brain readiness:check              # JSON output (default)
brain readiness:check --human      # Human-readable table
brain readiness:check --skip-memory  # Skip memory hygiene (CI or no MCP)
```

## Checks

| Check | Command | PASS | WARN | FAIL |
|-------|---------|------|------|------|
| repo_health | git status --porcelain | clean worktree | untracked files | uncommitted tracked changes |
| phpstan_core | composer analyse (core/) | exit 0 | — | exit != 0 |
| phpstan_cli | composer analyse (cli/) | exit 0 | — | exit != 0 |
| phpunit_core | composer test (core/) | 0 failures | — | failures > 0 |
| phpunit_cli | composer test (cli/) | 0 failures | — | failures > 0 |
| docs_validation | brain docs --validate | 0 invalid, 0 warnings | warnings > 0 | invalid > 0 |
| composer_audit_core | composer audit (core/) | exit 0 | — | exit != 0 |
| composer_audit_cli | composer audit (cli/) | exit 0 | — | exit != 0 |
| memory_hygiene | brain memory:hygiene | threshold met | — | below threshold |

## Overall Status

- **PASS** — all checks passed (NEUTRAL/SKIP count as pass)
- **WARN** — at least one warning, no failures
- **FAIL** — at least one failure; exit code = 1

## Status Definitions

| Status | Meaning | Release-blocking? |
|--------|---------|-------------------|
| **PASS** | Check completed successfully, all criteria met | No |
| **WARN** | Non-critical issue detected (e.g. untracked files, doc warnings) | No — but must be acknowledged |
| **FAIL** | Critical quality gate violation; exit code = 1 | **Yes** — must be resolved before release |
| **NEUTRAL** | Check ran but no data available (e.g. empty vector store) | No |
| **SKIP** | Check was explicitly skipped via flag | No — see skip-memory policy below |

## Release Policy

`brain readiness:check` is the **standard pre-release command**. Every release tag and main-branch merge must be preceded by a passing run.

Rules:
- Overall FAIL blocks release — no exceptions.
- Overall WARN is allowed but the warnings must be reviewed and documented in the release notes.
- `--skip-memory` is permitted only when: (a) running in CI without MCP server access, or (b) memory_hygiene returns NEUTRAL/NO_DATA. In both cases the skip reason must be recorded in the release checklist.
- Local developer runs should always attempt the full check (without `--skip-memory`) to catch memory regressions early.

## Skip-Memory Flag

Use `--skip-memory` when the MCP vector-memory server is unavailable (CI environments, fresh installs). The memory hygiene check will show SKIP status instead of failing.

## Relationship to Other Tools

- **audit-enterprise.sh** — deeper, slower 19-check audit; readiness:check is the lightweight local version
- **brain-lint CI** — automated on push; readiness:check is the manual pre-push equivalent
- **brain docs --validate** — one of the 9 checks included in readiness:check
