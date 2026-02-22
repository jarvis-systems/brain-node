---
name: "Pre-Publication Kill-Switch Checklist"
description: "Mandatory checklist before any public release — credential rotation, git history cleanup, final gate verification"
type: product
date: 2026-02-21
version: "1.0.0"
status: active
---

# Pre-Publication Kill-Switch Checklist

Execute this checklist BEFORE any public release (GitHub public, Packagist, npm, or distribution to external parties).

**Strategic playbook:** For the full decision matrix (BFG vs Fresh Repo vs New Canon Repo), credential inventory, pattern governance, and recommended migration path, see `.docs/product/16-security-3.0-playbook.md`.

## 1. Credential Rotation (BLOCKING)

All credentials that ever touched git history MUST be rotated before publication.

| Credential | Location | Rotation Action | Verify |
|------------|----------|-----------------|--------|
| Packagist API token | Was in `upload.sh:3` | Regenerate at packagist.org → Profile → API Tokens | Old token returns 401 |
| Context7 API key | Was in `settings.json:10` | Regenerate at Context7 dashboard | Old key returns 403 |
| GitHub PAT | Was in `node/Mcp/GithubMcp.php:21` | Regenerate at github.com → Settings → Developer settings → PAT | Old token returns 401 |
| GROQ API key | Was in `.brain/.env` | Regenerate at console.groq.com → API Keys | Old key returns 401 |
| OpenRouter API key | Was in `.brain/.env` | Regenerate at openrouter.ai → Keys | Old key returns 401 |

After rotation, update `.brain/.env` with new values and run `brain compile`.

## 2. Git History Cleanup (BLOCKING)

Leaked credentials exist in git history. Two options:

### Option A: BFG Repo-Cleaner (recommended for existing repos)

```bash
# 1. Create secrets file
cat > /tmp/secrets-to-remove.txt << 'EOF'
jarvis:YOUR_PACKAGIST_TOKEN_HERE
YOUR_CTX7SK_KEY_HERE
# Add any other leaked values here (get exact values from .brain/.env)
EOF

# 2. Run BFG
bfg --replace-text /tmp/secrets-to-remove.txt

# 3. Clean and force push
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force

# 4. Verify
git log --all -p | grep -c 'github_pat_\|ctx7sk-\|gsk_\|sk-or-v1-'
# Expected: 0
```

Known affected commits: `2b54793`, `40afe0d`, `fee9a60`, `c976347`, `f3e4cb0`, `bf93744`.

### Option B: Fresh Repository (cleanest)

If the repository has never been public, a fresh repo with squashed history is simpler:

```bash
# Export current state (no history)
git archive HEAD | tar -x -C /tmp/brain-clean/
cd /tmp/brain-clean/
git init && git add -A && git commit -m "Initial commit: Brain v0.2.0"
```

## 3. Final Gate Verification (BLOCKING)

Run ALL gates and confirm green:

```bash
# Core quality gates
composer test           # Expected: 245+ tests, 0 failures
composer analyse        # Expected: 0 errors (core + CLI)

# Security gates
bash scripts/scan-secrets.sh          # Expected: 0 secrets found
bash scripts/audit-enterprise.sh      # Required: FAIL:0. Target: WARN:0.
                                      # PASS count is informational (varies with check set).
                                      # Source of truth: script output, not this doc.

# History secrets scan (redacted, low-noise)
bash scripts/scan-secrets-history.sh  # Default: exit 0 required for publication
                                      # Exit 2 = matches found (see exception below)
```

**History scan rule:**

- **Publication mode** (going public, Packagist, npm, external distribution): exit 0 is **mandatory**. Exit 2 = BLOCKED. Requires rotation/archive plan per `.docs/product/16-security-3.0-playbook.md`.
- **Private repo, mitigated-history variant** (non-publication): exit 2 is allowed ONLY when ALL conditions are met:
  1. Repository is private (not public, not shared externally)
  2. Provider-side credential revocation confirmed (incident CLOSED in `16-security-3.0-playbook.md`)
  3. `scan-secrets-history.sh` baseline is tracked in FIX-QUEUE P2-008 (status: MITIGATED/OPEN)
  4. Pre-pub gate still runs and result is recorded (TOTAL_MATCHES logged)
  5. Clear upgrade path documented (Option C / BFG — plan-only, in `16-security-3.0-playbook.md`)
- If **any** condition above is not met → treat exit 2 as blocking, same as publication mode.
- If repo visibility changes to public, the private exception is **revoked**; exit 0 becomes mandatory immediately.

```bash

# Documentation gate
brain docs --validate                 # Expected: 0 errors, 0 warnings

# Release bundle gate
bash scripts/build-release-bundle.sh  # Expected: dist/*.tar.gz created, no .mcp.json
```

### Worktree Isolation Compliance (Manual, when quad-mode active)

If multi-agent / quad-mode was used during the release cycle:

- [ ] All agent tasks ran in dedicated worktrees (not root repo) per `.docs/product/17-worktree-isolation-contract.md`
- [ ] Root repo worktree is clean: `git status --porcelain` in root = empty
- [ ] No stale worktrees: `git worktree list` shows only root (or explicitly active tasks)
- [ ] Agent branches merged or cleaned: `git branch --merged master | grep agent/`
- [ ] Root CI files clean (no quad-mode drift): `git diff --name-only -- '.github/workflows/*.yml'` — must be empty. See `17-worktree-isolation-contract.md` § Hard Rule 4.6.

Failure: stop release until root repo is verified clean and all agent worktrees are pruned.

### CLI Worktree Stabilization (Required for Release)

Audit sub-checks for CLI tests and PHPStan skip when `cli/` worktree is dirty (dev-safe). For release, CLI MUST be clean so these sub-checks actually execute:

1. Verify CLI worktree: `git -C cli status --porcelain` — must return empty
2. If dirty — quarantine WIP: `cd cli && git checkout -b wip/release-stabilize && git add -A && git commit -m "wip: quarantine for release" && git checkout master && cd ..`
3. Rerun audit: `bash scripts/audit-enterprise.sh` — CLI sub-checks must show `PASS` (not `WARN`/`SKIP`)
4. After release: restore WIP if needed: `cd cli && git merge wip/release-stabilize && cd ..`

## 4. Version Alignment (BLOCKING)

All three repos must have matching git tags and matching `composer.json` version fields before publication. This gate applies only at release time (GO PRE-PUB). During normal dev batches, version drift is non-blocking — do not tag during regular work.

### Iron Rules

- **No remote retag.** If the target tag already exists on a remote (`git ls-remote --tags origin | grep vX.Y.Z`), do NOT delete and recreate it. Bump to the next version (`v0.2.1`, `v0.3.0`, etc.) instead. Retagging a pushed tag is forbidden except under explicit GO PRE-PUB with separate incident-style approval.
- **Preflight: jq required.** All steps below use `jq`. Verify availability before starting: `command -v jq >/dev/null || { echo "BLOCKED: jq not installed"; exit 1; }`. Fallback: `php -r "echo json_decode(file_get_contents('composer.json'))->version;"`.

### Lock Semantics (dev vs release)

- **Dev mode (path repo):** `.brain/composer.lock` may show `dev-master` with a commit reference for `jarvis-brain/core`. This is informational only — the path symlink resolves at runtime.
- **Packagist / publication mode:** Root and CLI `composer.json` constraints MUST be semver tags (no `"*"`), and `composer.lock` must be regenerated from the registry (not from the path symlink). Run `composer update jarvis-brain/core` after switching the constraint from `"*"` to `"^v0.2.0"`.

### Steps

0. Preflight — verify `jq` and check remote tags:

```bash
command -v jq >/dev/null || { echo "BLOCKED: jq not installed"; exit 1; }
git ls-remote --tags origin | grep 'v0\.2\.0' || echo "Tag not on remote — safe to use"
git -C core ls-remote --tags origin | grep 'v0\.2\.0' || echo "Tag not on remote — safe to use"
git -C cli ls-remote --tags origin | grep 'v0\.2\.0' || echo "Tag not on remote — safe to use"
# If ANY tag exists on remote: choose next version. Do NOT retag.
```

1. Verify `composer.json` version fields match across repos:

```bash
echo "root: $(jq -r '.version' composer.json)"
echo "core: $(jq -r '.version' core/composer.json)"
echo "cli:  $(jq -r '.version' cli/composer.json)"
# All three must be identical (e.g., v0.2.0)
```

2. Verify git tags exist and are exact (no `-N-gXXXXXXX` suffix):

```bash
git describe --tags --exact-match            # root
git -C core describe --tags --exact-match    # core
git -C cli describe --tags --exact-match     # cli
# All three must succeed. Failure = HEAD is not tagged.
```

3. If tags are missing, create them (operator action):

```bash
cd core && git tag v0.2.0 && cd ..
cd cli  && git tag v0.2.0 && cd ..
git tag v0.2.0
```

4. Verify composer constraints are release-ready:

```bash
jq -r '.require["jarvis-brain/core"]' composer.json      # root: "*" (path dev) or "^0.2.0"
jq -r '.require["jarvis-brain/core"]' cli/composer.json  # cli: "^v0.x.y"
```

Any mismatch = BLOCKED. Fix versions/tags before proceeding.

For the canonical version model (dev vs release), see `.docs/architecture/repo-topology.md` § "Canonical Version Sources".

## 5. Release Bundle Inspection (BLOCKING)

```bash
# Verify bundle contents — NO secrets
tar tzf dist/brain-enterprise-v*.tar.gz | grep -c '.mcp.json'
# Expected: 0

# Verify no secret patterns in bundle
tar xzf dist/brain-enterprise-v*.tar.gz -C /tmp/bundle-check/
grep -rE 'github_pat_|ctx7sk-|gsk_|sk-or-v1-' /tmp/bundle-check/ || echo "CLEAN"
rm -rf /tmp/bundle-check/
```

## 6. Post-Publication Verification

After publication, verify:

- [ ] Old credentials no longer work (all return 401/403)
- [ ] `git clone` of public repo + `grep -rE 'github_pat_|ctx7sk-'` = 0 matches
- [ ] `scan-secrets.sh` passes on fresh clone
- [ ] `brain compile` works with new `.brain/.env` credentials

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-21 | Created kill-switch checklist | Pre-publication safety net for credential rotation and history cleanup |
| 2026-02-21 | Added mitigated-history private exception | Aligns history scan gate with SCORECARD "Mitigated History Variant" for private repos; publication rule unchanged |
