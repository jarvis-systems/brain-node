---
name: "Self-Hosting Workspace Contract"
description: "Canonical workspace model for self-hosting development mode vs consumer projects"
type: "architecture"
date: "2026-02-24"
version: "1.0.0"
status: "active"
---

# Self-Hosting Workspace Contract

## What Self-Hosting Is

Self-hosting mode is when the Brain repository develops itself using its own tooling. This repo (`jarvis-brain-node`) is a self-hosting project — Brain CLI develops Brain.

## The Symlink Invariant

**Self-hosting repos ONLY:** `.brain` is a symlink pointing to repo root:

```
.brain -> .
```

### Implications

1. **Path mirroring:** Any path under `.brain/` resolves to repo root
   - `.brain/.env` → `./.env`
   - `.brain/node/` → `./node/`
   - `.brain/memory/` → `./memory/`

2. **No separate tree:** `.brain/` is NOT a separate directory tree — it's the root viewed through a symlink

3. **Config location:** Self-hosting overrides go in `.brain-config/` (NOT under `.brain/`)
   - Correct: `.brain-config/mcp-tools.allowlist.json`
   - Wrong: `.brain/config/...` (this would be root/config which doesn't exist)

## Consumer Projects

In consumer projects (non-self-hosting), `.brain/` is a **real directory**:

```
.brain/          # Real directory
├── .env         # Environment config
├── config/      # Project overrides
├── memory/      # SQLite storage
└── node/        # Brain components
```

Consumer config override: `.brain/config/mcp-tools.allowlist.json`

## Directory Classification

| Directory | Self-Hosting | Consumer | Purpose |
|-----------|-------------|----------|---------|
| `.brain/` | Symlink to `.` | Real directory | Brain workspace |
| `.brain-config/` | ✅ Override location | ❌ Does NOT exist | Self-hosting policy |
| `.brain/config/` | ❌ Wrong (root/config) | ✅ Override location | Consumer policy |
| `.brain/memory/` | `./memory/` via symlink | Real directory | SQLite storage |
| `.brain/node/` | `./node/` via symlink | Real directory | Brain components |

## CANON vs BUILD vs EVIDENCE vs RUNTIME

| Category | Location | VCS | Purpose |
|----------|----------|-----|---------|
| CANON | `.brain/node/*.php` | ✅ Tracked | Source of truth (Agents, Commands, Skills) |
| CANON | `.brain/.env` | ❌ Gitignored | Environment secrets |
| CANON | `.brain-config/` | ✅ Tracked | Self-hosting policy overrides |
| BUILD | `.opencode/` | ❌ Gitignored | Compiled output (auto-generated) |
| BUILD | `.claude/` | ❌ Gitignored | Legacy compiled output |
| EVIDENCE | `dist/evidence/` | ❌ Gitignored | Audit bundles, gate reports |
| RUNTIME | `.brain/memory/` | ❌ Gitignored | SQLite database (credentials, memory) |

## Red Flags Checklist

If you see these patterns, verify self-hosting mode:

- [ ] `.brain/node/Brain.php` AND `node/Brain.php` both exist → Likely symlink mirror
- [ ] `config/brain/` directory exists in self-hosting repo → Misplaced consumer pattern
- [ ] `.brain/config/` used in self-hosting → Wrong location (use `.brain-config/`)
- [ ] Duplicate files under `.brain/` and root → Expected in self-hosting (symlink)

## Detection

Run `brain diagnose` and check:

```json
{
  "self_hosting": true,
  "brain_dir_is_symlink": true,
  "brain_dir_target": "."
}
```

- `self_hosting: true` — Self-hosting mode active
- `brain_dir_is_symlink: true` — `.brain` is a symlink
- `brain_dir_target: "."` — Symlink points to repo root

## Related

- [MCP Tool Policy](mcp-tool-policy.md) — Policy location resolution
- [Security 3.0 Playbook](../product/16-security-3.0-playbook.md) — Self-hosting backup implications
- [Secrets Policy](../product/09-secrets.md) — Storage paths
