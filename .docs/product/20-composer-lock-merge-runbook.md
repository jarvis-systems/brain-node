---
name: "Composer Lock Merge Runbook"
description: "Conflict-proof procedure for composer.json + composer.lock merges in brain-cli and core repos"
type: runbook
date: 2026-02-22
version: "1.0.0"
status: active
---

# Composer Lock Merge Runbook

## Principle

`composer.lock` is a binary-like artifact — never hand-merge its JSON sections. Always regenerate deterministically from the merged `composer.json`.

## When This Applies

- PR with `composer.lock` changes hits a merge conflict
- Two branches both update dependencies
- Rebasing a branch that touches `composer.lock`

## Procedure

### Step 1: Resolve composer.json

Merge `composer.json` manually (it is small and human-readable). Accept both constraint changes where they do not conflict. If constraints conflict (e.g. both branches change the same package version), choose the more permissive or more recent constraint.

Then validate:

```bash
composer validate
```

### Step 2: Regenerate Lock

**Option A — Constraints unchanged, only lock conflict (preferred):**

```bash
rm composer.lock
composer install --no-interaction --prefer-dist --no-progress
```

This recreates the lock consistent with `composer.json`. Output may vary by composer version and platform — ensure the PHP version matches the project baseline (currently PHP 8.2).

**Option B — Constraints changed, want updated versions:**

```bash
composer update --with-all-dependencies --no-interaction
```

This intentionally refreshes all resolvable versions. Expect a larger diff.

### Step 3: Sanity Checks

```bash
composer audit          # 0 advisories
composer test           # all tests pass
composer analyse        # PHPStan 0 errors
git diff --stat         # only composer.lock (and composer.json if changed)
```

### Step 4: Commit

```bash
git add composer.json composer.lock
git commit -m "chore(deps): resolve composer.lock conflict

Evidence: composer audit 0, tests N/N OK, PHPStan L2 0 errors."
```

## Anti-Patterns

| Do NOT | Why |
|--------|-----|
| Hand-edit `composer.lock` JSON | Breaks content-hash, corrupts dependency tree |
| `git checkout --ours composer.lock` | Silently drops the other branch's dependency changes |
| Merge without `composer audit` | May reintroduce patched vulnerabilities |
| Skip `composer test` after regeneration | Transitive changes can break runtime behavior |

## Platform Baseline

| Setting | Value |
|---------|-------|
| PHP | 8.2.x |
| Composer | 2.9.x |
| Lock strategy | Tracked in git, regenerated on conflict |
| CI | Local gates only (P2-011: CLI CI workflow pending) |
