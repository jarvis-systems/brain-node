---
name: "Instruction Surfaces & Model-Tier Elasticity"
description: "Canonical reference for compiled brain instruction surfaces, mandatory invariants, elastic sections, and model-tier mapping policy"
---

# Instruction Surfaces & Model-Tier Elasticity

## Surface Map

Brain compiles to 4 instruction surfaces (standard mode):

| Surface | Target Clients | Lines | Rules | H1 Sections |
|---------|---------------|-------|-------|-------------|
| `.claude/CLAUDE.md` | Claude Code | 352 | 39 | 18 |
| `AGENTS.md` | Codex, OpenCode | 352 | 39 | 18 |
| `GEMINI.md` | Gemini CLI | 316 | 34 | 17 |
| `QWEN.md` | Qwen CLI | 316 | 34 | 17 |

Tier 1 (Claude/AGENTS): full delegation hierarchy (39 rules).
Tier 2 (Gemini/Qwen): trimmed delegation — 5 rules removed (Accountability, Approval-chain, Context-integrity, Delegation-limit, Non-recursive).

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

| Section Category | Economy (~300 lines) | Standard (~400 lines) | Premium (~700+ lines) |
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
| Economy (~300 lines) | Minimal | id + text + why | Haiku, Flash, small models |
| Standard (~400 lines) | Moderate | + short onViolation | Sonnet, Pro, Codex |
| Premium (~700+ lines) | Full | + detailed onViolation + all scenarios | Opus, Ultra |

### Compile Knob Presets

| Preset Name | `STRICT_MODE` | `COGNITIVE_LEVEL` | Use Case |
|-------------|--------------|-------------------|----------|
| Prototyping | standard | standard | Day-to-day dev, feature work |
| Production | strict | deep | Production features, API contracts |
| Enterprise | paranoid | exhaustive | Security-critical, compliance, audits |

The compile system enforces these via environment variables. Changing tier mid-session is forbidden (`No-mode-self-switch` iron rule) — tier is a compile-time decision only.
