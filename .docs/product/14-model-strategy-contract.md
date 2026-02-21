---
name: "Model Strategy Contract"
description: "Deterministic model routing: free-first stress testing, golden reference, zero paid tokens on PRs"
type: "contract"
date: "2026-02-21"
version: "1.0"
status: "active"
---

# Model Strategy Contract

## 1. Model Taxonomy

| Tier | Profile | Agent | Model | Cost | Schedule | Purpose |
|------|---------|-------|-------|------|----------|---------|
| Free | free-live | opencode | opencode/glm-4.7-free | $0 | Nightly (automatic) | Structural stress testing |
| Standard | nightly-live | claude | haiku/sonnet | Low-Medium | Nightly (automatic) | Behavioral verification |
| Golden | golden-live | claude | claude-opus-4-6 | High | Manual/Weekly | High-confidence reference baseline |
| PR Gate | (all profiles) | — | — | $0 | Every PR | Dry-run only, zero API calls |

## 2. Profile-Agent Binding

Profiles with cost implications are bound to specific agents. The benchmark runner enforces this at startup — mismatches exit immediately with error code 2.

| Profile | Required Agent | Enforcement |
|---------|---------------|-------------|
| free-live | opencode | Hard (exit 2 on mismatch, live only) |
| golden-live | claude | Hard (exit 2 on mismatch, live only) |
| nightly-live | (any) | Soft (no binding) |
| ci, full, telemetry-ci | (any) | Soft (no binding) |
| smoke | (any) | Soft (no binding) |

Binding is enforced only during live runs (not `--dry-run`). Dry-run validates JSON schema without API calls, so there is no cost risk and no binding needed. This allows the PR gate to dry-run all profiles without specifying agents.

### Binding Rationale

- **free-live → opencode**: Guarantees zero API cost. If someone accidentally uses `--agent claude`, the runner blocks before any API call is made. This is the primary budget safety mechanism.
- **golden-live → claude**: Guarantees results come from the reference model (Opus). Running golden-live on a free model would produce misleading baselines.

### Error Message

```
ERROR: Profile 'free-live' requires --agent opencode but got 'claude'
  free-live  → --agent opencode (zero cost, GLM-4.7-FREE)
  golden-live → --agent claude (paid, Opus reference)
  Use: --profile free-live --agent opencode
```

## 3. Scenario-Level Model Gating (min_model_tier)

Scenarios can declare minimum model capability via `min_model_tier` in their JSON definition.

### Tier Hierarchy

| Tier Name | Numeric | Models |
|-----------|---------|--------|
| haiku | 1 | haiku, free models (GLM-4.7-FREE, flash, lite, mini) |
| sonnet | 2 | sonnet, medium, pro, standard |
| opus | 3 | opus, max, codex-max |

### Gating Policy

| Scenario Category | min_model_tier | Rationale |
|-------------------|---------------|-----------|
| Knowledge (L1, L2, L3) | (none) | Text comprehension works across all tiers |
| Governance (ADV, banned_tools) | (none) | Refusal behavior works across all tiers |
| Execution (expected_tools) | varies | MCP tool execution requires minimum capability |
| Constitutional Learn KNOWLEDGE (MT-LP-001-KNOWLEDGE) | (none) | Reasoning/format knowledge — no MCP execution |
| Constitutional Learn EXEC (MT-LP-001-EXEC) | sonnet | Haiku cannot reliably execute store_memory via MCP |

### Runner Behavior

- Model tier is resolved once at startup: `RESOLVED_MODEL_TIER=$(model_tier "$MODEL")`
- `--model-tier` override takes absolute priority over model name heuristic
- If scenario's `min_model_tier` > resolved tier: status = `SKIP`, non-failing in CI
- `model_tier` (numeric) is included in every per-scenario JSON result and in the report root

## 4. Budget Routing Guarantees

### PR Gate (Zero Cost)

Every PR that touches Brain sources, scenarios, or scripts triggers `pr-gate`:
- Dry-run only for all profiles (full, telemetry-ci, nightly-live, cmd-auto, free-live, golden-live)
- Baselines JSON validation
- Zero API calls, zero tokens, zero cost

### Nightly (Automatic, Cost-Bounded)

| Job | Profile | Agent | Cost | Trigger |
|-----|---------|-------|------|---------|
| smoke-test | smoke | claude | ~$0.01 | Schedule + nightly gate |
| nightly-live | nightly-live | claude | ~$0.50 (sonnet) | After smoke passes |
| free-live | free-live | opencode | $0 | After smoke passes |
| matrix-stress | matrix | claude | ~$0.20 (haiku) | Nightly |
| adversarial-stress | adversarial-matrix | claude | ~$0.30 (haiku) | Nightly |

Total nightly budget: ~$1.00 (smoke + nightly-live + matrix + adversarial). Free-live adds zero.

### Manual (On-Demand)

| Job | Profile | Agent | Cost | Trigger |
|-----|---------|-------|------|---------|
| golden-live | golden-live | claude | ~$5.00 (opus) | Manual dispatch only |
| benchmark-suite | (any) | (any) | Varies | Manual dispatch |

Golden-live is never triggered automatically. It requires explicit `workflow_dispatch` with `profile=golden-live`.

## 5. CI Trigger Matrix

| Event | PR Gate | Smoke | Nightly-Live | Free-Live | Golden-Live | Matrix | Adversarial |
|-------|---------|-------|-------------|-----------|-------------|--------|-------------|
| Push to PR | dry-run | — | — | — | — | — | — |
| Schedule (03:00 UTC) | — | yes | yes | yes | — | yes | yes |
| Manual (profile=golden-live) | — | yes | — | — | yes | — | — |
| Manual (profile=free-live) | — | — | — | yes | — | — | — |
| Manual (profile=nightly-live) | — | — | yes | — | — | — | — |

## 6. Report Schema

### Report Root

```json
{
  "agent": "opencode",
  "model": "opencode/glm-4.7-free",
  "model_tier": 1,
  "model_tier_override": "haiku",
  "profile": "free-live",
  "dry_run": false,
  ...
}
```

### Per-Scenario

```json
{
  "id": "CMD-001",
  "executed_model": "opencode/glm-4.7-free",
  "model_tier": 1,
  "status": "PASS",
  ...
}
```

### Skipped Scenario

```json
{
  "id": "MT-LP-001",
  "executed_model": "opencode/glm-4.7-free",
  "model_tier": 1,
  "status": "SKIP",
  "skip_reason": "model_not_supported: opencode/glm-4.7-free < sonnet",
  ...
}
```

## 7. Fail-Fast Guarantees

The system prevents silent cost leaks at multiple layers:

| Layer | Mechanism | Failure Mode |
|-------|-----------|-------------|
| Runner startup | Profile-agent binding validation | Exit 2 before any API call |
| Runner startup | Model tier resolution | Resolved once, used for all scenarios |
| Per-scenario | min_model_tier gating | SKIP (non-failing, zero cost) |
| CI workflow | Job-level `if` conditions | Job skipped entirely if wrong trigger |
| CI workflow | Separate CLI installation | free-live installs opencode, not claude |

If OpenCode CLI fails or is unavailable, the benchmark fails with ERROR — it does NOT fall back to Claude. Each CI job installs only the CLI it needs.

## 8. Baselines

Separate baselines per profile with independent budgets:

| Profile | Tokens | Duration | MCP | Notes |
|---------|--------|----------|-----|-------|
| free-live | 20,000 | 1,200,000ms | 50 | Higher duration (free model slower) |
| golden-live | 25,000 | 1,000,000ms | 50 | Generous (opus verbose, runs rarely) |
| nightly-live | 15,000 | 800,000ms | 50 | Standard (sonnet, nightly reference) |

### Tuning Rules

1. Never tighten budgets without 3 stable consecutive runs proving headroom
2. Initial baselines set at ~150% of first observed values
3. Free-live baselines will need tuning after first real nightly run
4. Golden-live baselines are intentionally generous — opus runs are rare and valuable

## 9. Release Checklist Integration

Before tagging a release:

| Gate | Command | Required |
|------|---------|----------|
| Quality gates | `composer analyse && composer test` | Required |
| Dry-run | `composer benchmark:dry` | Required |
| Free-live stress | `composer benchmark:free` | Required |
| Golden verification | `composer benchmark:golden` | Optional (recommended before major releases) |

## 10. Cross-References

- ADR: `.docs/adr/ADR-001-free-first-golden-verify.md`
- Quality Contract: `.docs/product/12-instruction-quality-contract.md`
- Prompt Change Contract: `.docs/product/13-prompt-change-contract.md`
- Coverage Matrix: `.docs/instructions/COVERAGE.md`
- Baselines: `.docs/benchmarks/baselines/baselines.json`
- Runner: `scripts/benchmark-llm-suite.sh`
