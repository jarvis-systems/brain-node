---
name: "Release Prepare"
description: "Release pack generator with dry-run and apply mode: version detection, evidence collection, version bumps, and structured pack output"
type: runbook
date: 2026-02-23
version: "1.3.0"
status: active
---

# Release Prepare

Command that automates pre-release evidence collection and optionally applies version bumps. Default is dry-run (read-only). With `--apply`, bumps version fields in `composer.json` files across all 3 repos.

## When to Use

- Before starting a manual release process (dry-run)
- To verify version alignment across all 3 repos (node, core, cli)
- To collect readiness + compile-diff evidence into a single pack
- To apply version bumps safely with a reversible plan (`--apply`)

## What It Does

1. Reads `composer.json` version from all 3 repos (node, core, cli)
2. Detects latest git tag per repo
3. Validates target version is valid semver and not a downgrade
4. Optionally collects evidence (readiness check + compile diff + lock sync)
5. Generates a structured pack under `.work/releases/{version}/`
6. With `--apply`: bumps version fields, checks lock sync post-bump, generates apply-plan.json

## What It Does NOT Do

- Does not create git commits or tags (prints commands in apply-plan.json)
- Does not push to any remote (prints push commands only)
- Does not run `brain compile` (only `compile --diff` for evidence)
- Does not bypass readiness gate — `--apply` refuses if readiness is FAIL

## Usage

```bash
# Dry-run modes (read-only)
brain release:prepare v0.3.0              # JSON output, no evidence
brain release:prepare v0.3.0 --evidence   # JSON output with readiness + compile-diff
brain release:prepare v0.3.0 --human      # Human-readable table
brain release:prepare                     # Auto-suggests next minor version

# Apply mode (writes to composer.json files)
brain release:prepare v0.3.0 --apply          # Bumps versions, collects evidence
brain release:prepare v0.3.0 --apply --human  # Human output with applied changes
```

## Safety Model

| Concern | Guarantee |
|---------|-----------|
| Default behavior | Dry-run (read-only) — no files modified |
| Apply gate | `--apply` requires explicit flag |
| Readiness gate | `--apply` refuses if `readiness:check` returns FAIL |
| Reversibility | Changes are only to `composer.json` files — `git checkout` reverts |
| No network | Never pushes to remote — only prints push commands |
| No tags | Never creates tags — only prints tag commands |

## Pack Directory Structure

### Dry-run mode

```
.work/releases/v0.3.0/
├── manifest.json       # Envelope: version, target, current, status, timestamp
├── versions.json       # Detected versions from 3 repos
├── readiness.json      # readiness:check output (null without --evidence)
├── compile-diff.json   # compile --diff output (null without --evidence)
└── next-steps.md       # Shell commands for manual release execution
```

### Apply mode (adds apply-plan.json)

```
.work/releases/v0.3.0/
├── manifest.json
├── versions.json
├── readiness.json
├── compile-diff.json
├── apply-plan.json     # Changes made + git commands to run
└── next-steps.md       # Post-apply instructions (verify, commit, tag, push)
```

## apply-plan.json Schema

```json
{
  "version": "1.3.0",
  "target": "v0.3.0",
  "current": "v0.2.2",
  "changes": [
    {"file": "composer.json", "field": "version", "before": "v0.2.2", "after": "v0.3.0"},
    {"file": "core/composer.json", "field": "version", "before": "v0.2.2", "after": "v0.3.0"},
    {"file": "cli/composer.json", "field": "version", "before": "v0.2.2", "after": "v0.3.0"},
    {"file": "cli/composer.json", "field": "require.jarvis-brain/core", "before": "^v0.2.2", "after": "^v0.3.0"}
  ],
  "git_commands": [
    "git add composer.json core/composer.json cli/composer.json",
    "git commit -m \"chore(release): bump version to v0.3.0\"",
    "git tag -a v0.3.0 -m \"v0.3.0\"",
    "git push origin master && git push origin v0.3.0"
  ],
  "timestamp": "2026-02-23T12:00:00Z"
}
```

## Version Fields Updated by --apply

| Repo | File | Field | Example |
|------|------|-------|---------|
| node | `composer.json` | `version` | `v0.2.2` → `v0.3.0` |
| core | `core/composer.json` | `version` | `v0.2.2` → `v0.3.0` |
| cli | `cli/composer.json` | `version` | `v0.2.2` → `v0.3.0` |
| cli | `cli/composer.json` | `require.jarvis-brain/core` | `^v0.2.2` → `^v0.3.0` |

## JSON Output Schema

| Key | Type | Description |
|-----|------|-------------|
| `version` | string | Runner version (1.3.0) |
| `status` | string | See Status Values below |
| `target_version` | string | Requested target version |
| `current_version` | string | Current version from node/composer.json |
| `timestamp` | string | ISO 8601 UTC timestamp |
| `duration_ms` | int | Total execution time |
| `readiness_overall` | string\|null | PASS/WARN/FAIL or null without evidence |
| `compile_diff_status` | string\|null | `no_diff`/`has_diff` or null |
| `evidence_collected` | bool | Whether evidence was collected |
| `evidence` | object | Structured evidence metadata (see Evidence Meta below) |
| `validation` | object | `{valid: bool, reason: string\|null}` |
| `applied` | bool | Whether version bumps were applied (apply mode only) |
| `apply_plan` | array\|null | Changes made (apply mode only) |
| `pack_dir` | string | Relative path to pack directory |
| `versions` | object | Per-repo `{path, version, tag}` |

## Evidence Meta

Each evidence source (readiness, compile_diff, lock_sync) has a structured status describing whether evidence was collected.

| Status | Meaning | Reason |
|--------|---------|--------|
| `present` | Evidence successfully collected | `null` |
| `ok` | Lock sync check passed (all repos in sync) | `null` |
| `warn` | Lock file drift detected in one or more repos | Drift description |
| `missing` | Evidence requested but command returned no parseable output | Command name included |
| `skipped` | Evidence not requested (no `--evidence` or `--apply` flag) | Static hint to use flag |
| `skip` | Per-repo: no `composer.lock` file found | Static message |

Evidence meta is included in both the JSON output (`evidence` key) and `manifest.json` inside the pack. Human output (`--human`) renders colored badges: green for present/ok, yellow for warn, red for missing, gray for skipped/skip.

Schema:

```json
{
  "evidence": {
    "readiness": {"status": "present", "reason": null},
    "compile_diff": {"status": "missing", "reason": "Command 'compile --diff' returned no parseable JSON output"},
    "lock_sync": {
      "status": "ok",
      "reason": null,
      "repos": {
        "node": {"status": "skip", "reason": "No composer.lock"},
        "core": {"status": "ok", "reason": null},
        "cli": {"status": "ok", "reason": null}
      }
    }
  }
}
```

## Lock Sync Preflight

Added in v1.3.0. Runs `composer validate --no-check-publish --no-interaction` per repo to detect lock file content-hash drift. This prevents the exact scenario that caused the v0.4.0 retag incident: `applyVersionBumps()` updates `cli/composer.json` constraint but does not update `cli/composer.lock`, causing CI failure.

| Behavior | Detail |
|----------|--------|
| When it runs | `--evidence` or `--apply` mode. In apply mode, runs AFTER version bumps to catch post-bump drift |
| What it checks | `composer validate` exit code per repo with `composer.lock` |
| Repos without `composer.lock` | Reported as `skip` (not an error) |
| Result location | `evidence.lock_sync` in JSON output and `manifest.json` |
| Blocking | Non-blocking in v1 (WARN only). Does not prevent release |

Per-repo drift reasons:

| Pattern in output | Mapped reason |
|-------------------|---------------|
| `lock file is not up to date` | Lock file content-hash mismatch (run composer update) |
| `out of date` | Lock file is out of date with composer.json |
| Other non-zero exit | First non-empty line from command output |

## Status Values

| Status | Meaning | Exit code |
|--------|---------|-----------|
| `evidence_only` | Dry-run, no evidence collected | 0 |
| `ready` | Dry-run, evidence passed | 0 |
| `applied` | Apply mode, versions bumped | 0 |
| `blocked` | Readiness FAIL, apply refused | 2 |
| `validation_failed` | Invalid semver or downgrade | 2 |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (dry-run or apply completed) |
| 1 | Internal error (e.g. working directory not found) |
| 2 | Validation failed (bad version, downgrade, or readiness FAIL in apply mode) |

## Version Detection

| Repo | Source | Path |
|------|--------|------|
| node | `composer.json` | Root `composer.json` |
| core | `core/composer.json` | Core package |
| cli | `cli/composer.json` | CLI package |

Tags are detected via `git describe --tags --abbrev=0` per repo directory. Missing files or tags result in `null` values (graceful degradation).

## Auto-Suggest

When no version argument is provided, the command reads root `composer.json` and suggests the next minor bump:

- `v0.2.2` → `v0.3.0`
- `v1.0.0` → `v1.1.0`

## Relationship to Other Tools

- **readiness:check** — gate for `--apply` mode; also an evidence source
- **compile --diff** — evidence source for compile drift detection
- **release-readiness.md** — documents the readiness gate
