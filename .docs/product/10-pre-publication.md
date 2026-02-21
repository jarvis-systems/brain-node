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
composer test           # Expected: 233+ tests, 0 failures
composer analyse        # Expected: 0 errors (core + CLI)

# Security gates
bash scripts/scan-secrets.sh          # Expected: 0 secrets found
bash scripts/audit-enterprise.sh      # Expected: PASS:18, WARN:0, FAIL:0

# History secrets scan (redacted, low-noise)
bash scripts/scan-secrets-history.sh  # Expected: exit 0 (no matches)
                                      # Exit 2 = matches found → requires
                                      # rotation/archive plan before publication
                                      # See: .docs/product/16-security-3.0-playbook.md

# Documentation gate
brain docs --validate                 # Expected: 0 errors, 0 warnings

# Release bundle gate
bash scripts/build-release-bundle.sh  # Expected: dist/*.tar.gz created, no .mcp.json
```

## 4. Release Bundle Inspection (BLOCKING)

```bash
# Verify bundle contents — NO secrets
tar tzf dist/brain-enterprise-v*.tar.gz | grep -c '.mcp.json'
# Expected: 0

# Verify no secret patterns in bundle
tar xzf dist/brain-enterprise-v*.tar.gz -C /tmp/bundle-check/
grep -rE 'github_pat_|ctx7sk-|gsk_|sk-or-v1-' /tmp/bundle-check/ || echo "CLEAN"
rm -rf /tmp/bundle-check/
```

## 5. Post-Publication Verification

After publication, verify:

- [ ] Old credentials no longer work (all return 401/403)
- [ ] `git clone` of public repo + `grep -rE 'github_pat_|ctx7sk-'` = 0 matches
- [ ] `scan-secrets.sh` passes on fresh clone
- [ ] `brain compile` works with new `.brain/.env` credentials

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-21 | Created kill-switch checklist | Pre-publication safety net for credential rotation and history cleanup |
