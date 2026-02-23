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
