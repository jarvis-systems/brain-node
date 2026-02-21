---
name: "Secrets Policy"
description: "Threat model, enforcement mechanisms, and credential management for Brain ecosystem"
type: product
date: 2026-02-21
version: "1.0.0"
status: active
---

# Secrets Policy

## Threat Model

### Attack Surfaces

| Surface | Risk | Mitigation |
|---------|------|------------|
| Git-tracked files | Accidental commit of API keys, tokens | `.gitignore` enforcement, `scan-secrets.sh` CI gate, audit Check 14 |
| Git history | Previously committed secrets persist in reflog | BFG Repo-Cleaner or `git filter-repo` (see Roadmap) |
| `.mcp.json` (compiled) | `brain compile` resolves `getenv()` at PHP runtime, writing plaintext secrets | `.gitignore` excludes `.mcp.json`; release bundle excludes it |
| Release bundles (`dist/`) | Bundle script may copy secret-containing files | `.mcp.json` excluded from `build-release-bundle.sh` |
| CI/CD logs | Environment variables echoed to stdout | GitHub Actions masks `${{ secrets.* }}` automatically |
| `.brain/.env` | Local env file with plaintext credentials | Gitignored via `.git/info/exclude`; `.env.example` template provided |

### Primary Failure Modes

1. **Accidental commit** -- developer adds a file containing a token without checking `.gitignore`
2. **Release bundle leakage** -- build script copies `.mcp.json` (with resolved secrets) into tarball
3. **Compile-time env resolution** -- `getenv()` in MCP classes materializes secrets into `.mcp.json`
4. **History retention** -- rotated secrets still accessible via `git log` / `git show`

### Invariants

- No secrets in git-tracked files (enforced by `scan-secrets.sh` + audit Check 14)
- No secrets in dist bundles (enforced by `build-release-bundle.sh` exclusion)
- No secrets in CI logs or reports
- No secret values in agent responses, chat logs, or documentation output (report as counts/FOUND/NOT FOUND only)

## Do / Don't

| Do | Don't |
|----|-------|
| Store credentials in `.env` (gitignored) | Hardcode API keys in PHP source |
| Use `getenv('KEY_NAME')` in MCP classes | Commit `.mcp.json` to git |
| Reference `${{ secrets.* }}` in CI workflows | Echo secrets to stdout in scripts |
| Run `scan-secrets.sh` before committing | Include `.mcp.json` in release bundles |
| Rotate keys immediately after accidental exposure | Assume git history is clean after `.gitignore` |
| Document credential names in `.env.example` | Store actual values in `.env.example` |
| Report scan findings as counts only (FOUND/NOT FOUND) | Print actual secret values in agent responses or logs |

## Credential Inventory

| Credential | Environment Variable | Used By | Rotation |
|------------|---------------------|---------|----------|
| GitHub PAT (MCP) | `GITHUB_MCP_TOKEN` | `GithubMcp.php` | GitHub Settings > Developer settings > PAT |
| Context7 API Key | `CONTEXT7_API_KEY` | `Context7Mcp.php` | Upstash Console > Context7 |
| Anthropic API Key | `ANTHROPIC_API_KEY` | CI benchmarks only | Anthropic Console > API Keys |
| Packagist Token | Local `upload.sh` only | Package publishing | Packagist > API Tokens |

## Key Rotation Procedure

1. Generate new credential at provider's console
2. Update `.env` with new value
3. Run `brain compile` to regenerate `.mcp.json` with new credential
4. Verify MCP servers connect: test each `mcp__*` tool
5. Revoke old credential at provider's console
6. If old credential was committed to git: schedule BFG history cleanup (see Roadmap)

## Enforcement Mechanisms

### CI Gates (Blocking)

| Gate | Tool | Scope |
|------|------|-------|
| `scripts/scan-secrets.sh` | Standalone scanner | All git-tracked files + dist/ |
| `audit-enterprise.sh` Check 14 | Audit framework | All git-tracked files (patterns: `github_pat_`, `ctx7sk-`, `gsk_`, `sk-or-v1-`) |

### Local Development

- `.gitignore` excludes: `.mcp.json`, `.env`, `.brain/.env`, `upload.sh`, `settings.json`
- `.env.example` documents required variables with empty placeholders
- `build-release-bundle.sh` explicitly skips `.mcp.json`

### Expected Local Workspace Artifacts (Untracked & Symlinks)

`git clean -nd` may show items that are normal development artifacts, not leaks.

**Allowed (normal):**

| Item | Type | Why untracked |
|------|------|---------------|
| `node/Includes/` | Empty directory | Scaffold created by `brain make:include`. Git does not track empty directories. |
| `node/Skills/` | Empty directory | Scaffold created by `brain make:skill`. Git does not track empty directories. |
| `.brain` | Symlink (this repo only) | Self-hosting dev mode: `.brain → .` so Brain tooling develops itself using its own Node structure. In other projects `.brain/` is a real directory, not a symlink. |

**Verify:** `git clean -nd` should list ONLY items from the table above. Anything else — investigate immediately and run `bash scripts/scan-secrets.sh`.

**Red flags** (investigate if seen in `git clean -nd`):

- Stdout dumps (e.g. `pbcopy` from `> file` instead of `| pbcopy`) — delete after confirming content
- Editor temp files (`*.swp`, `*.bak`, `*~`) — configure global gitignore (`~/.config/git/ignore`), not repo `.gitignore`
- Files matching secret patterns (`github_pat_*`, `ctx7sk-*`, `*.key`) — run `scan-secrets.sh`, rotate if real

**Why not .gitignore:** These items are NOT added to `.gitignore` intentionally. Keeping `git clean -nd` signal value high ensures unexpected files are immediately visible, not silently hidden.

## Troubleshooting

### `.mcp.json` missing after fresh clone

Expected behavior. `.mcp.json` is gitignored (local runtime file).

**Fix:**
1. Copy `.env.example` to `.env`
2. Fill in your credential values
3. Run `brain compile` -- generates `.mcp.json` from MCP class definitions + env values

### Secret scanner false positive

If `scan-secrets.sh` flags a file that contains a pattern reference (not an actual secret):

1. Verify the file is in the exclusion list (`is_excluded()` function)
2. If it should be excluded, add it to the exclusion cases
3. If it contains an actual secret, remove the secret and use `getenv()` instead

### MCP server fails to connect after key rotation

1. Verify `.env` has the new key value
2. Run `brain compile` to regenerate `.mcp.json`
3. Restart Claude Code to reload MCP configuration
4. Check `mcp__*` tool availability

## Roadmap

### Variant 1 (Current) -- Gitignore + CI Scanning

Status: **Implemented**

- `.mcp.json` is local runtime file, generated by `brain compile`
- Secrets live in `.env`, resolved at compile time
- CI gates prevent accidental commits
- Release bundles exclude `.mcp.json`

### Variant 2 (Future) -- CLI Runtime Env Resolution

Placeholder tokens in `.mcp.json` instead of resolved values. CLI resolves `${ENV_VAR}` at MCP server startup, not at compile time. This would allow `.mcp.json` to be safely committed/bundled.

Requires: CLI compiler changes in `CompileTrait::generateMcpFile()`.

### Variant 3 (Future) -- Encrypted Secret Store

SQLite-based encrypted credential storage with OS keychain integration. Secrets never written as plaintext to any file.

Requires: New `brain secrets:*` CLI commands, keychain integration library.

### Git History Cleanup

Commits containing leaked secrets should be cleaned with BFG Repo-Cleaner:

```
# After rotating ALL affected credentials:
bfg --replace-text passwords.txt repo.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force
```

Affected commits (known): `2b54793`, `40afe0d`, `fee9a60`, `c976347`, `f3e4cb0`, `bf93744`.

This is a P2 backlog item -- credentials should be rotated first (which neutralizes the risk).
