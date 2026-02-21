---
name: "Security 3.0 Playbook"
description: "Pre-publication security playbook: credential rotation, history remediation, Option C new canon repo migration"
type: product
date: 2026-02-21
version: "2.0"
status: active
---

# Security 3.0 Playbook

## Executive Summary

Security 2.3→3.0 is blocked by one factor: git history contains leaked credentials in 6+ commits. HEAD is clean (scan-secrets=0, audit PASS:18).

This repo was previously public — history may have been cloned by third parties. BFG history rewrite cannot recall third-party copies. Credential rotation is mandatory regardless of strategy.

Product roadmap targets X-Brain rebrand on Go with a new repository. This creates a natural migration window for Option C: new canonical repo with clean history, old repo archived.

**Recommended path: Option C (New Canon Repo).** Rotate + archive old repo → clean export to new → full gates → Security 3.0 from day one.

Inventory: 8 credentials (5 must rotate, 2 must remove/disable, 1 CI-only = no action). Pattern governance via canonical `scan-secrets.sh`. 2-tier evidence model.

## Redaction Rule

**IRON RULE:** Actual secret values MUST NEVER appear in agent responses, chat logs, documentation, or any output visible to users or stored in conversation history.

### Reporting Findings

| Allowed | Forbidden |
|---------|-----------|
| Counts: "3 matches found in history" | Printing actual token/key values |
| Status: "FOUND / NOT FOUND" | Pasting credential strings into responses |
| Last-4 chars: `...b007` (only if Doc explicitly requests) | Showing grep output containing plaintext secrets |
| File + line: "`.env:5` contains C3 pattern match" | Embedding values in code blocks or tables |

### Handling `/tmp/secrets-to-remove.txt`

This file (used for Tier-2 exact-match verification) contains actual old credential values.

- NEVER commit to any repository
- NEVER print contents in agent responses or logs
- Create only during GO PRE-PUB execution, delete immediately after verification
- Access only via redacted commands: report match counts, not matched content

### Scanning Commands in Redacted Mode

When running commands that may output secret values (e.g., `git log -p | grep`), agents must:

1. Suppress or redirect raw output
2. Report only: match count, file paths, commit SHAs
3. If raw output accidentally appears in response — flag as security incident immediately

## Credential Discovery Gate

### Verified Inventory

**Category A — Must Rotate** (leaked in history OR repo was public):

| # | Provider | Env Variable | Leaked In | Scan Pattern |
|---|----------|-------------|-----------|--------------|
| C1 | GitHub | `GITHUB_MCP_TOKEN` | Not confirmed leaked (precautionary — repo was public) | `github_pat_[A-Za-z0-9_]{10,}` |
| C2 | Context7 | `CONTEXT7_API_KEY` | `settings.json:10` | `ctx7sk-[a-f0-9-]{8,}` |
| C3 | GROQ | `GROQ_API_KEY` | `.brain/.env` (risk: early history) | `gsk_[A-Za-z0-9]{10,}` |
| C4 | OpenRouter | `OPENROUTER_API_KEY` | `.brain/.env` (risk: early history) | `sk-or-v1-[A-Za-z0-9]{10,}` |
| C5 | Packagist | (local `upload.sh`) | `upload.sh:3` | No prefix pattern (`user:hex` format) |

Known affected commits: `2b54793`, `40afe0d`, `fee9a60`, `c976347`, `f3e4cb0`, `bf93744`.

**Category B — Must Remove/Disable** (unused, exist in `.brain/.env`):

| # | Details | Action |
|---|---------|--------|
| C7 | Additional unused secret in `.brain/.env` | Remove from env AND disable at provider (if console exists) |
| C8 | Additional unused secret in `.brain/.env` | Remove from env AND disable at provider (if console exists) |

Rule: unused secrets must be rotated/disabled OR removed from env before any canonical release.

**Category C — CI Secrets (no action):**

| # | Provider | Storage | Action |
|---|----------|---------|--------|
| C6 | Anthropic (`ANTHROPIC_API_KEY`) | GitHub Secrets only | None — never in repo files |

### Discovery Steps (before execution)

1. Read `09-secrets.md` § "Credential Inventory" — cross-reference with table above.
2. Read `10-pre-publication.md` § "Credential Rotation" — confirm C1-C5 match.
3. Doc inspects `.brain/.env` locally — confirms C7+C8 exist, confirms no C9+.
4. Tier-1 pre-flight grep on old repo — establishes baseline secret count in history.
5. C3/C4 history verification — confirm whether GROQ/OpenRouter were ever committed.

**Gate:** Doc confirms inventory complete. Any additions → restart discovery.

## Pattern Governance

### Canonical Sources

Patterns for secret detection live in two canonical locations (must stay in sync):

- `scripts/scan-secrets.sh:57` — `SECRET_PATTERNS=` variable (HEAD scan: git ls-files + dist/)
- `scripts/audit-enterprise.sh:569` — `SECRET_PATTERN=` variable (Check 14, HEAD scan)

Current regex (identical in both):
`github_pat_[A-Za-z0-9_]{10,}|ctx7sk-[a-f0-9-]{8,}|gsk_[A-Za-z0-9]{10,}|sk-or-v1-[A-Za-z0-9]{10,}`

**Known gaps:** Packagist `user:hex` format, Bearer tokens, Anthropic `sk-ant-` — documented in `scan-secrets.sh` header but absent from regex. Tier-2 compensates.

All secret scanning commands in this playbook reference canonical patterns from `scan-secrets.sh`, not inline regex.

### 2-Tier Evidence Model

| Tier | Method | Coverage | When |
|------|--------|----------|------|
| Tier-1 (prefix) | `grep -cE` canonical patterns against `git log --all -p` | Known prefixes. Misses Packagist, Bearer. | Pre-flight + quick post-cleanup |
| Tier-2 (exact) | `grep -cF -f /tmp/secrets-to-remove.txt` (old exact values) against `git log --all -p` | 100% — exact values, zero false negatives. | Final verify on old repo. Not needed for Option C new repo. |

### History Scan (Low-Noise, Redacted)

Raw Tier-1 (`git log --all -p | grep -cE`) produces inflated counts (~1M+) because documentation files (`.docs/`, `*.md`, compiled `.claude/` output) legitimately reference the same regex patterns. This makes evidence non-enterprise.

`scripts/scan-secrets-history.sh` solves this by:

1. Extracting canonical patterns from `scan-secrets.sh` (single source of truth).
2. Using `git log -G` with pathspec exclusions (`.docs/`, `*.md`, scan scripts, compiled output).
3. Outputting only: match counts, affected commit hashes, affected file paths — **never content**.
4. Exit code: `0` = clean history, `2` = matches found.

Usage:
```
bash scripts/scan-secrets-history.sh          # Human-readable (redacted)
bash scripts/scan-secrets-history.sh --json   # Machine-readable
```

This replaces raw `git log -p | grep -cE` for evidence purposes. Tier-2 (exact old values) remains unchanged.

## Decision Matrix

| Criteria | A: BFG Rewrite | B: Fresh Repo Reset | C: New Canon Repo |
|----------|---------------|--------------------|--------------------|
| Preserves git history | YES (values masked) | NO (squashed) | NO (new repo, old archived) |
| Leaked history accessible to third parties | YES — clones retain original | YES — old clones retain | YES — but old repo archived, new repo clean |
| Credential rotation required | YES (always) | YES (always) | YES (always) |
| Post-cleanup confidence | MEDIUM (depends on secrets-to-remove.txt) | MEDIUM (reflog risk) | **MAXIMUM** (no history) |
| Risk to collaborators | MEDIUM (force-fetch) | HIGH (re-clone) | LOW (natural migration) |
| Risk to tags/releases | LOW (BFG preserves names) | HIGH (all lost) | NONE (new tags) |
| Alignment with X-Brain roadmap | Poor — invests in sunset repo | Poor | **Excellent** |
| Time/complexity | ~30 min | ~10 min | ~20 min |

### Decision Rule

```
IF repo was previously public AND product is migrating to new repo:
  → Option C [RECOMMENDED]

IF must keep same repo URL (published with active consumers):
  → Option A (BFG)

IF repo was always private AND history has zero value:
  → Option B (simplest)
```

**This project: Option C.** Repo was public. Product migrates to X-Brain. BFG cannot recall third-party clones. Rotation neutralizes leaked values. New repo starts clean.

## Recommended Path: Option C

### Overview

```
OLD REPO (jarvis-brain-node)          NEW REPO (X-Brain)
  C1: Rotate/disable ALL creds          C2: git archive HEAD → clean export
  C1b: Verify old creds dead            C3: Fresh .env from template
  C1c: Archive/lock old repo            C4: Full gates in new repo
  C1d: Add ARCHIVE notice               C5: Fresh clone verification
                                         C6: SCORECARD → 3.0
```

### Old Repo Responsibilities

1. Credential rotation — C1-C5 rotated, old values return 401/403.
2. C7/C8 removal — unused secrets removed from `.brain/.env` or disabled at provider.
3. Archive — GitHub repo settings → Archive repository.
4. Notice — `ARCHIVED.md` with redirect to new repo (see template below).
5. HEAD scan — `scan-secrets.sh` = 0 (confirms HEAD was already clean).

No BFG. No force push. No history rewrite. Rotated credentials = dead values.

### New Repo Responsibilities

1. Clean export — `git archive HEAD` from old repo.
2. Fresh `.brain/.env` — from `.env.example`, new credentials ONLY, no C7/C8.
3. Full gates — test, analyse, scan-secrets, audit, brain docs --validate.
4. SCORECARD — Security 3.0 from day one.

## Execution Steps: Option C

### Step C0: Pre-flight snapshot (read-only, old repo)

```
git status --porcelain
bash scripts/scan-secrets.sh                    # Gate: exit 0
bash scripts/audit-enterprise.sh                # Gate: PASS:18
composer test                                   # Gate: 233+ pass
# Tier-1 baseline:
git log --all -p | grep -cE "$(grep -oP "SECRET_PATTERNS='\K[^']+" scripts/scan-secrets.sh)"
# → Expected: >0 (documents the problem)
```

### Step C1: Rotate/disable ALL credentials [REQUIRES GO PRE-PUB]

**C1a: Save old values** for optional Tier-2 verify:
```
cp -L .brain/.env /tmp/brain-env-old-$(date +%Y%m%d)
```
Note: `cp -L` follows `.brain` symlink (see Self-Hosting Note below).

**C1b: Rotate Category A (C1-C5)** at provider consoles.

**C1c: Remove/disable Category B (C7, C8):** Delete from `.brain/.env`. If provider console exists — disable/revoke there too.

**C1d: Verify:** Each old C1-C5 credential → 401/403. C7/C8 disabled or removed.

### Step C2: Create clean export [REQUIRES GO PRE-PUB]

```
git archive HEAD --format=tar | tar -x -C /tmp/x-brain-clean/
```

Gate checks:
- No `.git/` in export
- No `.brain/.env` in export (gitignored → excluded by `git archive`)
- No `.mcp.json` in export (gitignored)

### Step C3: Initialize new repo with fresh env

```
cd /tmp/x-brain-clean/
git init && git add -A && git commit -m "X-Brain v0.2.0 — clean canonical import"
cp .env.example .brain/.env    # Fill with NEW C1-C5 values only
brain compile                  # Generates .mcp.json
```

Gate: `.brain/.env` contains only active credentials. No C7/C8. No old values.

### Step C4: Full gates in new repo

```
composer test              # 233+ pass, 0 failures
composer analyse           # 0 errors
bash scripts/scan-secrets.sh   # Exit 0
bash scripts/audit-enterprise.sh   # PASS:18, FAIL:0
brain docs --validate      # 0 invalid
```

### Step C5: Fresh clone verification

```
git remote add origin <new-repo-url>
git push -u origin master
git clone <new-repo-url> /tmp/x-brain-verify && cd /tmp/x-brain-verify
grep -rE "$(grep -oP "SECRET_PATTERNS='\K[^']+" scripts/scan-secrets.sh)" . || echo "CLEAN"
# Gate: 0 matches
```

### Step C6: Docs update (doc-only commit in new repo)

- SCORECARD: Security Core 2→3, CLI 2→3, Weighted 2.3→3.0.
- FIX-QUEUE: Close "git history cleanup" P2 item.
- Cleanup: `rm /tmp/secrets-to-remove.txt /tmp/brain-env-old-*`

### Old Repo: Archive steps

1. `bash scripts/scan-secrets.sh` → exit 0 (HEAD clean).
2. Add `ARCHIVED.md` (see template below).
3. GitHub repo settings → Archive repository.

## Execution Steps: Option A (BFG — Reference Only)

For cases where Option C is not viable (must keep same repo URL):

1. Save old values to `/tmp/secrets-to-remove.txt`.
2. `bfg --replace-text /tmp/secrets-to-remove.txt` [REQUIRES GO PRE-PUB]
3. `git reflog expire --expire=now --all`
4. `git gc --prune=now --aggressive`
5. Tier-1 + Tier-2 verification (both must = 0).
6. `git push --force` [DESTRUCTIVE — point of no return]
7. Full gate verification.

## Evidence Gates

### Old Repo

| Gate | Command | Pass Condition |
|------|---------|---------------|
| HEAD clean | `bash scripts/scan-secrets.sh` | Exit 0 |
| Audit green | `bash scripts/audit-enterprise.sh` | PASS:18, FAIL:0 |
| Old creds dead | Manual: each old value → 401/403 | All fail auth |
| Tier-1 baseline | `git log --all -p \| grep -cE <patterns>` | >0 (confirms problem) |

### New Repo (Option C)

| Gate | Command | Pass Condition |
|------|---------|---------------|
| No .git in export | `ls -la /tmp/x-brain-clean/.git` | Not found |
| No .env in export | `ls -la /tmp/x-brain-clean/.brain/.env` | Not found |
| Tests pass | `composer test` | 233+, 0 failures |
| PHPStan clean | `composer analyse` | 0 errors |
| Secrets scan | `bash scripts/scan-secrets.sh` | Exit 0 |
| Audit green | `bash scripts/audit-enterprise.sh` | PASS:18, FAIL:0 |
| Docs valid | `brain docs --validate` | 0 invalid |
| Clone clean | `grep -rE <patterns>` on fresh clone | 0 matches |

## Risk Model

| # | Risk | Impact | Mitigation |
|---|------|--------|------------|
| R1 | Old creds used before rotation | HIGH | Rotate ALL before new repo announcement |
| R2 | `.brain/.env` included in git archive | MEDIUM | Gate C2 checks explicitly; `.gitignore` excludes it |
| R3 | New creds fail | MEDIUM | Keep old env backup; revert if needed |
| R4 | Old repo not archived | MEDIUM | Archive immediately after rotation |
| R5 | C7/C8 left active | LOW | Step C1c: disable at provider OR remove from env |
| R6 | Third-party clone has active creds | HIGH | Rotation is the ONLY mitigation (no tech control over clones) |

## Stop Conditions

| # | Condition | Action |
|---|-----------|--------|
| S1 | Cannot rotate a credential | STOP — do NOT proceed to C2 |
| S2 | `.brain/.env` found in export | STOP — fix `.gitignore`, re-export |
| S3 | `composer test` fails in new repo | STOP — investigate export completeness |
| S4 | Undocumented secrets found | STOP — update inventory, restart from C1 |
| S5 | Old cred returns 200 after rotation | STOP — re-check at provider |

## Blast Radius

| Target | Impact | Recovery |
|--------|--------|----------|
| Old repo history | Untouched. Dead credentials. | No action — values are rotated. |
| Old repo status | Archived. Read-only. | Unarchive in GitHub settings. |
| New repo | Clean history. Fresh creds. | Re-export from old HEAD if needed. |
| Packagist / MCP servers | New tokens | Regenerate at providers. |
| CI (GitHub Actions) | Reconfigure for new repo URL | ANTHROPIC_API_KEY: copy to new repo GH Secrets. |
| Third-party old clones | Contain dead credentials | Rotation neutralizes risk. |

## Self-Hosting Workspace Note

In this repo, `.brain` is a symlink pointing to project root (`.brain → .`). This is self-hosting dev mode: Brain tooling develops itself using its own Node structure.

Implications for this playbook:
- `.brain/.env` resolves to `./.env` via symlink. Backup: `cp -L .brain/.env <dest>` (follow symlink).
- `.env.example` at root = `.brain/.env.example`. Single file, single source of truth.
- `brain compile` works normally — symlink is transparent to PHP.
- In other projects, `.brain/` is a real directory (not symlink). No special handling needed.

## Archive Notice Template

Template for `ARCHIVED.md` in old repo root (copy during Step C1d):

```markdown
# This Repository is Archived

This repository (`jarvis-brain-node`) has been archived and is no longer maintained.

Active development continues in the new canonical repository:
**[X-Brain](https://github.com/<org>/<new-repo>)**

## What happened

- All credentials that existed in git history have been rotated (old values are dead).
- The codebase was exported cleanly to the new repository with no history carried.
- This repo remains as a read-only archive for reference.

## For contributors

Please direct all issues, PRs, and discussions to the new repository.
```

## .env.example Verification

Canonical template: `.env.example` (= `.brain/.env.example` via symlink).

Verified state:
- Contains Brain config variables (LANGUAGE, SELF_DEV_MODE, modes, etc.)
- Contains MCP credentials (GITHUB_MCP_TOKEN, CONTEXT7_API_KEY) as commented-out empty placeholders.
- Does NOT contain C7/C8 (unused secrets) — correct.
- Does NOT contain actual values — correct.

No changes needed. Template is ready for Step C3.

## Doc Inputs (Resolved)

| # | Question | Answer | Source |
|---|----------|--------|--------|
| Q1 | X-Brain repo is new canon? | **YES** | Doc-stated |
| Q2 | C7/C8 provider consoles? | Execution-time decision | Doc handles during Step C1c |

## Remaining Unknowns (Non-blocking)

| # | Question | When to resolve |
|---|----------|-----------------|
| Q3 | Transfer GitHub Issues/PRs to new repo? | Before archive step |
| Q4 | New repo name/URL? | Before Step C5 |
| Q5 | `ARCHIVED.md` or just GitHub archive? | Before archive step |

## Scorecard Impact

| Category | Before | After | Delta |
|----------|--------|-------|-------|
| Security (Core) | 2 | 3 | +1 (clean history in new repo) |
| Security (CLI) | 2 | 3 | +1 (same repo, same clean history) |
| Security (weighted) | 2.3 | 3.0 | +0.7 |
| **Overall** | **28.3** | **30.0** | **+1.7 (100%)** |

## Incident Log

### 2026-02-21: Secret Values Exposure in Agent Response

**Incident:** During re-hydration session, agent printed actual credential values (C2–C5) in chat response. Values appeared in conversation history.

**Response:**
1. Redaction Rule established (see § Redaction Rule above) — prevents recurrence.
2. C2 (Context7), C3 (GROQ), C4 (OpenRouter) — keys removed from `.brain/.env` (not needed, old keys).
3. C5 (Packagist) — token replaced in `upload.sh` with non-compromised value.
4. Old credentials revoked/disabled at provider consoles — **VERIFIED** (Doc confirmation, 2026-02-21).
5. `brain compile` SUCCESS, all gates GREEN post-rotation.

**Status:** CLOSED. Old values are dead. Redaction rule in effect.

## Current State: History Dirty (Mitigated)

As of 2026-02-21, git history contains leaked credential patterns:

- **Matches:** 10 (via `scan-secrets-history.sh`, excluding docs/scripts noise)
- **Commits:** 6 (`89f7e88`, `40afe0d`, `2b54793`, `375e8bd`, `002a157`, `ad73b3d`)
- **Files:** 5 (`.env`, `.env.example`, `.mcp.json`, `node/Mcp/Context7Mcp.php`, `settings.json`)

**Operational risk: NEUTRALIZED.** All leaked credentials have been rotated or revoked at provider consoles (incident CLOSED). Old values return 401/403. HEAD is clean (`scan-secrets.sh` = 0, `audit-enterprise.sh` PASS:18).

**History cleanup: DEFERRED.** No BFG/force-push — private repo, dead credentials. Cleanup happens naturally via Option C (new canon repo) when X-Brain migration proceeds. Tracked as FIX-QUEUE P2-008.

## References

- Credential inventory: `.docs/product/09-secrets.md` § "Credential Inventory"
- Pre-publication checklist: `.docs/product/10-pre-publication.md`
- Scan patterns: `scripts/scan-secrets.sh:57`
- Audit Check 14: `scripts/audit-enterprise.sh:569`
- Scorecard: `.docs/audits/enterprise-codebase/SCORECARD.md`
- Known affected commits: `09-secrets.md` § "Git History Cleanup"
