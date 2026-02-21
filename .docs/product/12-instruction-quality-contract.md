---
name: "Instruction Quality Contract"
description: "Defines what is enforced by code/CI vs intent-only, benchmark tiers, instruction budget process, and scenario taxonomy"
type: "contract"
date: "2026-02-21"
version: "1.0"
---

# Instruction Quality Contract

## 1. Enforcement Classification

### Enforced by Code/CI (Hard Gates)

These checks run automatically and block merges or produce actionable warnings.

| Gate | Tool | Trigger | Action |
|------|------|---------|--------|
| Scenario JSON schema | benchmark-llm-suite.sh --dry-run | PR + nightly | BLOCK (exit 1 on invalid) |
| Instruction budget | check-instruction-budget.sh --strict | PR (brain-lint) | BLOCK (exit 1 if delta > 10%) |
| Baselines JSON validity | jq empty baselines.json | PR (brain-lint) | BLOCK |
| PHPStan static analysis | composer analyse | PR (brain-lint) | BLOCK |
| Unit tests | composer test | PR (brain-lint) | BLOCK |
| Compile discipline | brain-lint compile check | PR (brain-lint) | BLOCK (source change requires compiled update) |
| Docs front matter | brain docs --validate | PR (brain-lint) | BLOCK |
| MCP syntax lint | lint-mcp-syntax.sh | PR (brain-lint) | BLOCK |
| Secret scanning | scan-secrets.sh | PR (brain-lint) | BLOCK |
| Enterprise audit | audit-enterprise.sh | PR (brain-lint) | BLOCK |
| Regression check | benchmark-regression-check.sh | Nightly (post-live) | WARN (20% threshold) |

### Intent-Only (Prompt Directives)

These exist in compiled instructions but enforcement relies on LLM behavioral compliance, not code.

| Directive | Location | Verification Method |
|-----------|----------|---------------------|
| Cookbook governance (compile-time only) | Iron rule in CLAUDE.md | ADV-003 scenario (behavioral) |
| No-mode-self-switch | Iron rule in CLAUDE.md | ST-003 scenario (behavioral) |
| Search-before-store | Iron rule in CLAUDE.md | MT-001 scenario (behavioral, expected_tools) |
| Concise responses | Iron rule in CLAUDE.md | ST-002 scenario (token budget) |
| File safety (read-only) | Iron rule in CLAUDE.md | ADV-008 scenario (behavioral) |
| Delegation depth (no chaining) | Iron rule in CLAUDE.md | L3-008 scenario (behavioral) |
| Constitutional Learn Protocol | Brain include | MT-LP-001/002/003 scenarios (behavioral) |

### Key Distinction

Code gates catch structural regressions deterministically. Behavioral directives catch LLM compliance probabilistically via benchmark scenarios. Neither replaces the other.

## 2. Benchmark Tiers and Gating

### Tier Hierarchy

| Tier | Model | Cost | Use Case |
|------|-------|------|----------|
| haiku | claude-haiku | Low | Knowledge checks, format validation, governance |
| sonnet | claude-sonnet | Medium | MCP execution, Constitutional Learn Protocol |
| opus | claude-opus | High | Reserved for complex multi-step reasoning |

### Model Gating (min_model_tier)

Scenarios can declare `min_model_tier` in JSON. The runner skips scenarios when the current model tier is below the required tier.

Tier values: haiku=1, sonnet=2, opus=3.

SKIP status is non-failing in CI — it does not increment `failed` or `errors` counts.

### Gating Rationale

Model gating exists because some behaviors (MCP tool execution) require minimum model capability. A scenario that fails on haiku due to model limitations is not an instruction quality issue — it is a model capability boundary.

Current gated scenarios:

| Scenario | min_model_tier | Reason |
|----------|---------------|--------|
| MT-LP-001 | sonnet | Haiku cannot reliably execute store_memory via MCP |

### Profile Summary

| Profile | Scenarios | Model | Trigger | Purpose |
|---------|-----------|-------|---------|---------|
| smoke | 1 | haiku | All (pre-gate) | Basic connectivity |
| nightly-live | 8 | sonnet | Nightly + manual | Live behavioral proof |
| telemetry-ci | 12 | haiku | Manual | Telemetry coverage |
| ci | 25 | haiku | Manual | Broad knowledge coverage |
| full | 38 | sonnet | Manual | Complete non-adversarial |
| cmd-auto | 28 | haiku | Dry-run only | Command knowledge |
| matrix | 4x4 | haiku | Nightly | Stress (mode combinations) |
| adversarial-matrix | 7x4 | haiku | Nightly | Attack resistance |

## 3. Instruction Budget Baseline Update Process

### When to Update

Update baselines when:
- Adding new scenarios to a profile
- Removing scenarios from a profile
- Changing compiled instruction content that affects line counts

### Process

1. Run target profile live: `bash scripts/benchmark-llm-suite.sh --profile <name> --model <model> --json | tee report.json`
2. Review actual values in the report: `jq '{tokens: .total_output_tokens, duration: .total_duration_ms, mcp: .total_mcp_calls}' report.json`
3. Set baseline to ~150% of observed values (headroom for non-determinism)
4. Update `.docs/benchmarks/baselines/baselines.json` with new values
5. Run `bash scripts/check-instruction-budget.sh --strict` to verify instruction budget passes
6. Commit with explanation of why baselines changed

### Instruction Budget Thresholds

| Artifact | Metric | Threshold | Source |
|----------|--------|-----------|--------|
| .claude/CLAUDE.md | Line count | 10% delta | instruction-budgets.json |
| .claude/agents/*.md | Line count | 10% delta | instruction-budgets.json |
| .claude/commands/*.md | Line count | 10% delta | instruction-budgets.json |
| Grand total | Line count | 10% delta | instruction-budgets.json |

### Safety Rules

- NEVER update baselines without a live run producing the actual values
- NEVER set baselines below observed values (defeats purpose of regression detection)
- ALWAYS use 50% headroom above observed for non-deterministic metrics (tokens, duration)
- Instruction budget headroom is 10% (deterministic, compile-time values)

## 4. Scenario Taxonomy

### Knowledge Scenario

A scenario that tests the model's understanding of instructions, rules, or concepts without requiring tool execution.

Characteristics:
- No `expected_tools` field
- May have `banned_patterns` (to catch incorrect knowledge)
- `expected_mcp_calls` range includes 0 (model may optionally call tools)
- Prompt asks to explain, describe, list, or demonstrate format

Examples: L1-001 (compile-time knowledge), CMD-002 (MCP format knowledge), L2-003 (quality gates), ADV-001 (hallucination resistance).

### Execution Scenario

A scenario that requires the model to actually invoke MCP tools and produce observable side effects.

Characteristics:
- Has `expected_tools` field listing required tool names
- `expected_mcp_calls` range has min >= 1
- Prompt instructs to perform an action (store, search, create)
- Checks verify both text response AND tool invocation

Examples: ST-001 (search_memories), ST-004 (task_create), MT-001 (store + search lifecycle), MT-LP-001 (Constitutional Learn store).

### Governance Scenario

A scenario that tests enforcement of prohibitions — the model must NOT perform certain actions.

Characteristics:
- Has `banned_tools` field listing prohibited tool names
- Has `banned_patterns` checking for forbidden text
- Prompt may try to trick or pressure the model into violating rules
- Success = absence of prohibited behavior

Examples: MT-LP-002 (no-store on clean completion), ADV-004 (prompt injection), ADV-006 (destructive action refusal).

### Classification Rule

When adding a new scenario, classify it as exactly one of: knowledge, execution, or governance. This determines which check fields to use:
- Knowledge: `required_patterns` + optional `banned_patterns`
- Execution: `required_patterns` + `expected_tools` + `expected_mcp_calls`
- Governance: `banned_tools` and/or `banned_patterns` + optional `required_patterns`

## 5. Flakiness vs Regression

### Definitions

**Flakiness (variance):** A scenario that fails on first attempt but passes on retry within the same run. This indicates non-deterministic LLM behavior, not an instruction quality problem.

**Regression:** A scenario that fails consistently across retries AND across multiple nightly runs. This indicates a real instruction or model behavior change that requires investigation.

### Classification Rules

| Condition | Classification | Action |
|-----------|---------------|--------|
| Passes on first attempt | Stable | None |
| Fails first, passes on retry (FLAKY_PASS) | Variance | Monitor — investigate if rate > 20% of nightly runs |
| Fails all retries in one run | Possible regression | Wait for next nightly run before declaring regression |
| Fails all retries in 2+ consecutive runs | Confirmed regression | Investigate prompt, model, or scenario changes |

### Rules

1. FLAKY_PASS scenarios should be investigated if the flaky rate exceeds 20% of nightly runs for that scenario.
2. Do NOT update baselines to mask flakiness — fix the scenario patterns or model prompt instead.
3. Broadening regex patterns (`|` alternatives) is preferred over removing checks.
4. Increasing `timeout_s` is acceptable for latency-related flakiness.
5. Adding `"retry": N` to individual scenarios is acceptable for known-flaky execution scenarios.
