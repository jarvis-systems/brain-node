---
name: "Repo Topology"
description: "Architecture invariant: three independent git repos (node, core, cli) co-located on disk with composer symlink binding"
type: architecture
date: 2026-02-22
version: "1.0"
status: active
---

# Repo Topology

Brain consists of three independent git repositories co-located on disk. This is not a monorepo, not submodules, not subtrees. Each repo has its own `.git/`, its own remote, its own commit history.

## 1. Topology

```
jarvis-brain-node/                    # ROOT REPO (jarvis-systems/brain-node)
├── .git/                             # Root git
├── .brain/
│   └── vendor/jarvis-brain/
│       └── core -> ../../core        # Composer symlink to local core
├── .docs/                            # Documentation (tracked in root)
├── .claude/                          # Compiled output (tracked in root)
├── scripts/                          # CI/benchmark scripts (tracked in root)
├── core/                             # CORE REPO (jarvis-systems/brain-core)
│   ├── .git/                         # Separate git — NOT tracked by root
│   ├── src/                          # Core PHP source (169 files)
│   ├── tests/                        # Core tests (19 files)
│   └── bin/                          # Entry points (brain-core, brain-script)
└── cli/                              # CLI REPO (jarvis-systems/brain-cli)
    ├── .git/                         # Separate git — NOT tracked by root
    ├── src/                          # CLI source (125 files)
    └── tests/                        # CLI tests
```

## 2. Invariants

| # | Invariant | Enforcement |
|---|-----------|-------------|
| 1 | **Root does not track core/ or cli/** | `.gitignore` lines 4-5: `core`, `cli` |
| 2 | **Edits must be committed in the owning repo** | `git add` in root will refuse core/ and cli/ files (gitignored) |
| 3 | **Each repo has independent version history** | Three separate `.git/` directories with distinct remotes |
| 4 | **Validation gates run per-repo** | `composer test` and `composer analyse` execute in core/; CLI has own phpstan.neon |
| 5 | **Composer symlink bridges root to core** | `.brain/vendor/jarvis-brain/core -> ../../core` — root uses core via `"jarvis-brain/core": "*"` |

## 3. Repo Inventory

| Repo | GitHub Remote | Root .gitignore | Versioned |
|------|---------------|-----------------|-----------|
| brain-node (root) | `jarvis-systems/brain-node` | — | `composer.json` root: no version field |
| brain-core | `jarvis-systems/brain-core` | `core` (line 4) | `core/composer.json`: `v0.2.0` |
| brain-cli | `jarvis-systems/brain-cli` | `cli` (line 5) | `cli/composer.json` |

## 4. Operator Cookbook

### Committing changes in core/

```bash
# 1. Navigate to core repo
cd core

# 2. Check status (this is core's git, not root)
git status

# 3. Stage and commit
git add <files>
git commit -m "fix(core): description"

# 4. Return to root
cd ..
```

Root `git status` will NOT show core changes — they are invisible to root git.

### Committing changes in cli/

Same pattern: `cd cli && git status && git add && git commit && cd ..`

### Referencing a core version from root

Currently: root `composer.json` uses `"jarvis-brain/core": "*"` with a local path symlink (dev mode). For production release: pin to a tagged version (`"jarvis-brain/core": "^0.2.0"`).

Version pinning strategy: see section 6 (Canonical Version Sources) and `.docs/product/10-pre-publication.md` § "Version Alignment".

### Running gates across repos

```bash
# Root gates (docs, audit, benchmarks)
brain docs --validate
bash scripts/audit-enterprise.sh

# Core gates (tests, phpstan)
composer test       # Runs core/phpunit.xml.dist
composer analyse    # Runs core/phpstan.neon + cli/phpstan.neon

# CLI-specific gates
cd cli && composer analyse && cd ..
```

Note: `composer test` and `composer analyse` in root are configured to reach into core/ (and cli/ for analyse) via root `composer.json` scripts.

## 5. Agent Guardrails

### Before editing any file

Agents and operators MUST detect which repo owns a file before staging changes.

**Detection method:**

```bash
# From the file's directory:
git rev-parse --show-toplevel
```

This returns the owning repo's root. If the result differs from the expected repo, the file belongs to a different repo — switch context before committing.

### Common mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `git add core/bin/file` from root | "ignored by .gitignore" error | `cd core && git add bin/file` |
| `git status` shows clean but edits were made to core/ | Root git does not see core changes | `cd core && git status` |
| Expecting root commit to include core changes | Core changes absent from root diff | Commit separately in core repo |
| Running `git diff` in root after editing cli/ files | No diff shown | `cd cli && git diff` |

### Repo Boundary Preflight (copy-paste)

Run before ANY task that touches files. Determines owning repo for each path:

```bash
repo_root=$(git rev-parse --show-toplevel)
core_root=$(git -C core rev-parse --show-toplevel 2>/dev/null || true)
cli_root=$(git -C cli rev-parse --show-toplevel 2>/dev/null || true)
```

**Decision tree:**

1. Determine target file path
2. If path starts with `core/` → owning repo is `$core_root`; commit with `git -C core add/commit`
3. If path starts with `cli/` → owning repo is `$cli_root`; commit with `git -C cli add/commit`
4. Otherwise → owning repo is `$repo_root`; commit normally from root
5. Root `.gitignore` lists `core` and `cli` — root git silently ignores these paths. This is by design, not a bug.
6. Never force-add (`-f`) gitignored paths — it breaks the topology invariant

## 6. Canonical Version Sources

Two modes with different version contracts:

### Dev mode (daily work)

Canonical version signal per repo: `git describe --tags --always`. This produces a string like `v0.2.0-50-g500a03f` (tag + commits-since-tag + short SHA). The `composer.json` version field may drift ahead of the latest git tag during development — this is non-blocking and expected.

No tagging required per commit or per batch.

### Release mode (GO PRE-PUB only)

All three repos MUST have matching git tags AND matching `composer.json` version fields. See `.docs/product/10-pre-publication.md` § "Version Alignment" for the blocking gate.

| Signal | Dev (non-blocking) | Release (BLOCKING) |
|--------|--------------------|--------------------|
| `git describe --tags` | Any value (informational) | Must return exact tag, no `-N-gXXX` suffix |
| `composer.json` version | May drift ahead of tag | Must equal the git tag |
| Cross-repo alignment | Not required | root = core = cli version |

### Evidence commands

```bash
# Per-repo version snapshot (dev or release)
jq -r '.version' composer.json                  # root
jq -r '.version' core/composer.json             # core
jq -r '.version' cli/composer.json              # cli
git describe --tags --always                    # root
git -C core describe --tags --always            # core
git -C cli describe --tags --always             # cli
```

### Retag policy

Never retag a version that has been pushed to a remote. If the target tag exists on remote (`git ls-remote --tags origin | grep vX.Y.Z`), bump to the next version instead. Full procedure: `10-pre-publication.md` § "Version Alignment" Iron Rules.

### Lock semantics

Dev mode: `.brain/composer.lock` references `dev-master` via path symlink — informational only. Release mode: constraints must be semver (`"^v0.2.0"`), lock regenerated from registry. See `10-pre-publication.md` § "Lock Semantics".

### Known mismatch (release-time debt)

As of 2026-02-22: `core/composer.json` says `v0.2.0` but core's latest git tag is `v0.0.1`. This is acceptable during dev (composer.json was bumped manually, tag was not). Before any release: either tag core `v0.2.0` or revert the composer.json version to match the tag. Tracked as release-time prerequisite, not a dev-blocking issue.

## 7. Future: X-Brain Single Bundle

**Status:** Informational roadmap. Not enforced. No current action required.

X-Brain (Go rewrite) will consolidate node + core + cli into a single binary distributed via Homebrew. The three-repo topology is a PHP-era artifact of Composer package separation. The Go version will be a single module with internal packages.

This does not affect current development. The three-repo topology remains the canonical structure until X-Brain reaches feature parity.

## 8. Cross-References

- Worktree Isolation: `.docs/product/17-worktree-isolation-contract.md` (per-repo boundary awareness)
- Pre-Publication: `.docs/product/10-pre-publication.md` (credential rotation spans all repos)
- Enterprise Release Pack: `.docs/README_ENTERPRISE.md`
