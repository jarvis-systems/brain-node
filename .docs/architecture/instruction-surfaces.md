---
name: "Instruction Surfaces & Model-Tier Elasticity"
description: "Canonical reference for compiled brain instruction surfaces, mandatory invariants, elastic sections, and model-tier mapping policy"
---

# Instruction Surfaces & Model-Tier Elasticity

## Surface Map

Brain compiles to 4 instruction surfaces (standard mode):

| Surface | Target Clients | Lines | Rules | H1 Sections |
|---------|---------------|-------|-------|-------------|
| `.claude/CLAUDE.md` | Claude Code | 316 | 39 | 18 |
| `AGENTS.md` | Codex, OpenCode | 316 | 39 | 18 |
| `GEMINI.md` | Gemini CLI | 316 | 34 | 17 |
| `QWEN.md` | Qwen CLI | 316 | 34 | 17 |

All surfaces are uniform in standard mode. Premium mode (paranoid/exhaustive) adds ~282 lines via additional iron rules and expanded cookbook presets.

## Mandatory Invariants

These sections MUST be present in every surface, every tier, every mode. Absence is a P0 failure.

| Iron Rule ID | Severity | Purpose |
|-------------|----------|---------|
| Evidence-contract | CRITICAL | Dual-mode output contract (plan-only vs evidence-only) |
| No-secret-output | CRITICAL | Secret redaction policy |
| Quality-gates-mandatory | CRITICAL | Test + PHPStan gates |
| Compile-single-writer | CRITICAL | Compilation mutex |
| Cookbook-governance | CRITICAL | Cookbook call discipline |
| Mcp-json-only | CRITICAL | MCP payload format |
| Mandatory-source-scanning | CRITICAL | Source-first code generation |
| Never-write-compiled | CRITICAL | Compiled artifact protection |

## Elastic Sections

These sections scale with model cognitive budget. Same H2 header IDs across tiers, different body depth.

| Section Category | Economy (~330 lines) | Standard (~316 lines) | Premium (~598 lines) |
|-----------------|---------------------|----------------------|----------------------|
| Authority levels | brain + specialist | brain + specialist + tool | All 4 levels |
| Workflow phases | delegate + validate | 3 phases | All 5 phases |
| Error handling | 3 critical fallbacks | 5 scenarios | All 8 scenarios |
| Validation | semantic only | semantic + structural | Full chain (6 checks) |
| Rule detail | id + text + why | + short onViolation | + detailed onViolation |

## Model-Tier Mapping

| MODEL_TIER | STRICT_MODE | COGNITIVE_LEVEL | Target Models |
|-----------|-------------|-----------------|---------------|
| economy | strict | minimal | Haiku, Gemini Flash, Qwen Small |
| standard | strict | standard | Sonnet, Gemini Pro, Codex |
| premium | paranoid | exhaustive | Opus, Gemini Ultra |

Current compile knobs (`STRICT_MODE`, `COGNITIVE_LEVEL`) already implement this mapping. MODEL_TIER is a convenience alias, not a new mechanism.

## Drift Prevention

Iron Rule IDs are stable across all tiers and modes. The compile system enforces this by generating from the same PHP source. Tier-specific trimming happens via `#[Includes]` attributes and conditional blocks in Brain.php, not by post-processing.

Invariant sections use identical source text (byte-for-byte) across all surfaces. Changes propagate automatically through recompilation.

## Guard Coverage

| Guard Script | What It Checks |
|-------------|---------------|
| `verify-compile-metrics.sh` | Line counts, gated content, evidence-contract presence (all 4 surfaces), Codex 32KB limit, dev audit baseline |
| `verify-client-formats.sh` | Command extensions, agent extensions, YAML front matter, skills directories |
| `audit-enterprise.sh` | 20 categories: code quality, security, version consistency, compile hygiene |

### Line Count Thresholds (verify-compile-metrics.sh)

| Mode | Min Lines | Max Lines | Rationale |
|------|-----------|-----------|-----------|
| Standard | — | 400 | Economy tier; gated content excluded |
| Exhaustive | 550 | — | Premium tier; full iron rules + expanded cookbook |

Thresholds are calibrated to actual compiled output (~316 standard, ~598 exhaustive) with headroom for growth.

### Canonical Enabled Agents (agent-schema.json)

The following agents are enabled by default and appear in `agent-schema.json`:

| Agent ID | Model | Purpose |
|----------|-------|---------|
| `commit-master` | sonnet | Conventional commits, git workflow |
| `documentation-master` | haiku | Package/library documentation research |
| `explore-master` | haiku | Fast codebase exploration |
| `vector-master` | sonnet | Deep vector memory operations |
| `web-research-master` | sonnet | Multi-source web research |

**Meta-agents (disabled by default):** `agent-master`, `prompt-master`, `script-master` — require explicit `*_ENABLE` env var.

**Changing the enabled set:** Requires explicit GO signal. Update canon list in `audit-enterprise.sh` Check 20 and this section together.

## Output Contract

Brain enforces a dual-mode output contract via the `Evidence-contract` iron rule. Every readiness or snapshot report MUST declare exactly one mode.

### Modes

| Mode | Trigger Keywords | Requirements | Banner |
|------|-----------------|-------------|--------|
| PLAN-ONLY | checklist, runbook, plan | No commands executed. Descriptive only. | `PLAN-ONLY: No repo state was read.` |
| EVIDENCE-ONLY | evidence, verify, current, snapshot | Every claim backed by live command output. | None (evidence IS the banner). |

Ambiguous requests default to EVIDENCE-ONLY (safer — forces verification).

### Required Anchors (Brain-Level)

These grepable markers MUST appear in every compiled surface. Guards enforce their presence.

| Anchor | Min Count | Verified By |
|--------|-----------|-------------|
| `PLAN-ONLY` | 3 | `verify-compile-metrics.sh` |
| `EVIDENCE-ONLY` | 3 | `verify-compile-metrics.sh` |
| `Evidence-contract` | 1 | `verify-compile-metrics.sh` |
| `evidence pack` | 1 | grep scan |
| `dual-mode` | 2 | grep scan |

### Per-Task Contract Elements

These are operational directives supplied per-task in user prompts, NOT brain-level invariants. They are NOT expected in compiled surfaces.

| Element | Purpose | Example |
|---------|---------|---------|
| Touch Whitelist | Constrains which files an agent may modify in a given task | `Touch whitelist: instruction-surfaces.md, verify-compile-metrics.sh` |
| STOP CONDITION | Defines when the agent must halt execution | `STOP: if any gate produces FAIL` |
| PARALLELISM_BUDGET | Caps concurrent sub-agent invocations | `PARALLELISM_BUDGET=3` |

These are user-prompt patterns, not compiled invariants. Adding them to brain instructions would conflate orchestration-time directives with compile-time policy.

### Forbidden Patterns

| Pattern | Why Forbidden |
|---------|--------------|
| Mixed mode (plan claims + evidence output) | Creates false confidence — P0 failure |
| EVIDENCE-ONLY without live command output | Unverifiable claims look verified |
| PLAN-ONLY with executed commands | Mutates repo state during "read-only" plan |
| Missing mode declaration | Ambiguous reports cannot be trusted |

### Evidence Pack Structure

When mode is EVIDENCE-ONLY, the response MUST include:

1. **Gate results table** — gate name, command, status (PASS/FAIL), key metric
2. **Raw output** — actual stdout/stderr from each command (truncated if >50 lines)
3. **Summary line** — total pass/fail/skip counts

## Cost-Aware Client Presets

Different clients have different token budgets and cognitive capabilities. The compile system adapts output density accordingly.

### Token Budget Constraints

| Client | Format | Max Size | Notes |
|--------|--------|----------|-------|
| Claude Code | XML+Markdown | ~32KB soft | No hard limit, but context window pressure |
| Codex | Markdown | 32,768 bytes | Hard limit enforced by `verify-compile-metrics.sh` |
| Gemini CLI | XML+Markdown | ~32KB soft | Similar to Claude |
| Qwen CLI | XML+Markdown | ~32KB soft | Inherits Gemini format |
| OpenCode | Markdown | ~32KB soft | Similar to Claude |

### Tier → Budget Mapping

| Tier | Line Target | Rule Detail Level | Suitable For |
|------|------------|-------------------|-------------|
| Economy (~330 lines) | Minimal | id + text + why | Haiku, Flash, small models |
| Standard (~316 lines) | Moderate | + short onViolation | Sonnet, Pro, Codex |
| Premium (~598 lines) | Full | + detailed onViolation + all scenarios | Opus, Ultra |

### Compile Knob Presets

| Preset Name | `STRICT_MODE` | `COGNITIVE_LEVEL` | Use Case |
|-------------|--------------|-------------------|----------|
| Prototyping | standard | standard | Day-to-day dev, feature work |
| Production | strict | deep | Production features, API contracts |
| Enterprise | paranoid | exhaustive | Security-critical, compliance, audits |

The compile system enforces these via environment variables. Changing tier mid-session is forbidden (`No-mode-self-switch` iron rule) — tier is a compile-time decision only.

### MODEL_TIER Preset Resolution

`MODEL_TIER` is a convenience alias that maps to `STRICT_MODE` + `COGNITIVE_LEVEL`. Implemented as a shell wrapper (`scripts/tier-compile.sh`) because the var() resolution chain (ENV → Runtime → Meta → Method) doesn't support reverse-override from node-level hooks — `.brain/.env` always takes priority.

| `MODEL_TIER` | `STRICT_MODE` | `COGNITIVE_LEVEL` | Primary Clients |
|-------------|--------------|-------------------|----------------|
| economy | strict | minimal | Haiku, Flash, Qwen Small |
| standard | strict | standard | Sonnet, Pro, Codex |
| premium | paranoid | exhaustive | Opus, Ultra |

**Resolution rules:**
1. Explicit `STRICT_MODE` / `COGNITIVE_LEVEL` always override preset defaults
2. `MODEL_TIER` only sets defaults for unset variables (via `${VAR:-default}`)
3. Without `MODEL_TIER`, existing `STRICT_MODE` + `COGNITIVE_LEVEL` workflow unchanged

**Usage:**
- `MODEL_TIER=economy scripts/tier-compile.sh` — compile with economy preset
- `MODEL_TIER=premium STRICT_MODE=strict scripts/tier-compile.sh` — premium cognitive, but strict (not paranoid)
- `STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile` — direct (bypass preset)

### Surface Profile

| Surface | Target | Standard (lines) | Economy (lines) | Premium (lines) | Tier |
|---------|--------|:-:|:-:|:-:|:---:|
| `.claude/CLAUDE.md` | Claude Code | 316 | 330 | 598 | 1 |
| `AGENTS.md` | Codex, OpenCode | 316 | 330 | 598 | 1 |
| `GEMINI.md` | Gemini CLI | 316 | 330 | 598 | 2 |
| `QWEN.md` | Qwen CLI | 316 | 330 | 598 | 2 |

Economy adds ~14 lines (strict-only rules) while reducing cognitive depth. Premium adds ~282 lines via additional iron rules and expanded cookbook presets. All surfaces are now uniform in size per mode (tier 1/2 distinction removed).

## Client Format Compatibility Matrix

| Client | Commands | Agents | Skills | Config File | Model ID Format |
|--------|----------|--------|--------|-------------|-----------------|
| Claude | .md (YAML FM) | .md (YAML FM) | .md (YAML FM) | CLAUDE.md | Optional (defaults) |
| Qwen | .toml | .md (YAML FM) | .md (YAML FM) | QWEN.md | Optional |
| Gemini | .toml | .md (YAML FM) | .md (YAML FM) | GEMINI.md | Optional |
| OpenCode | .md (YAML FM) | .md (YAML FM) | .md (YAML FM) | AGENTS.md + settings.json | Required: provider/model |
| Codex | .md (prompts/) | N/A | SKILL.md | AGENTS.md (trust_level) | Optional |

### Known Pitfalls

1. **Qwen Migration**: Commands use .toml, NOT .md. No migration to MD exists.
2. **Codex Trust Model**: Requires `trust_level: trusted` in AGENTS.md for self-hosted configs.
3. **OpenCode Model IDs**: Must use full `provider/model` format (e.g., `anthropic/claude-3-opus`). No bare model names allowed.
