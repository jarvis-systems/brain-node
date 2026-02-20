---
name: "Benchmark v2 Verification"
description: "Commands and procedures for verifying benchmark v2 functionality"
type: "verification"
date: "2026-02-20"
version: "2.0"
---

# Verification Procedures

## 1. Dry-run (no API calls)

Validates all 28 scenario JSON files structurally.

```bash
composer benchmark:dry
```

Expected: 28/28 valid, 0 errors.

## 2. Session ID check

Verify Init DTO emits sessionId.

```bash
ai claude --ask "test" --json --model haiku 2>/dev/null | head -1
```

Expected: `{"type":"init","sessionId":"<uuid>","processType":"run","agent":"claude"}`

## 3. Resume check

Verify session continuity works.

```bash
# Get session ID from first call
SID=$(ai claude --ask "Remember number 42" --json --model haiku 2>/dev/null | head -1 | jq -r '.sessionId')

# Resume with follow-up
ai claude --resume "$SID" --ask "What number did I mention?" --json --model haiku
```

Expected: Response contains "42".

## 4. Individual scenario

```bash
# Single-turn telemetry
scripts/benchmark-llm-suite.sh --scenario ST-001 --model haiku

# Multi-turn memory
scripts/benchmark-llm-suite.sh --scenario MT-001 --model haiku

# Multi-turn task
scripts/benchmark-llm-suite.sh --scenario MT-002 --model haiku
```

## 5. Profile runs

```bash
# Telemetry-CI (9 scenarios, ~2.5 min)
composer benchmark:telemetry

# CI profile (17 scenarios, ~5 min)
composer benchmark:ci

# Multi-turn only
composer benchmark:mt
```

## 6. Full suite

```bash
# All 28 scenarios
scripts/benchmark-llm-suite.sh --profile full --model sonnet
```

## 7. Regression check

Compare a run report against baseline budgets.

```bash
# Check against baselines (WARN mode)
bash scripts/benchmark-regression-check.sh benchmark-report.json

# Override threshold (e.g., 10% instead of default 20%)
bash scripts/benchmark-regression-check.sh benchmark-report.json --threshold 10

# Strict mode (exit 1 on regression)
bash scripts/benchmark-regression-check.sh benchmark-report.json --strict
```

Baselines stored in `.docs/benchmarks/baselines/baselines.json`.

## CI Behavior

### Pull Request Gate

On every PR that touches Brain sources, scenarios, or scripts:

1. **smoke-test** — S00 only, haiku (~20s)
2. **pr-gate** (after smoke passes):
   - `telemetry-ci` profile (9 scenarios, haiku, ~2.5 min)
   - `ci` profile (17 scenarios, haiku, ~5 min)
   - Regression check on both reports (WARN, not blocking)
3. Artifacts: `pr-benchmark-reports` retained 14 days

### Nightly / Manual Dispatch

1. **smoke-test** — S00 only
2. **benchmark-suite**:
   - Default: `full` profile, `sonnet` model
   - Manual: selectable profile + model
   - Regression check (WARN mode)
3. Artifact: `benchmark-report` retained 30 days

### Regression Thresholds

| Metric | Baseline source | Threshold | Action |
|--------|----------------|-----------|--------|
| `total_output_tokens` | per-profile in baselines.json | +20% | WARN |
| `total_duration_ms` | per-profile in baselines.json | +20% | WARN |
| `total_mcp_calls` | per-profile in baselines.json | +20% | WARN |
| `failed` scenarios | any > 0 | exact | WARN |

Current action: WARN (non-blocking). Switch to `--strict` in CI when baselines stabilize.

### Updating Baselines

After adding scenarios or changing profiles, update `.docs/benchmarks/baselines/baselines.json`:

1. Run target profile: `composer benchmark:ci > report.json`
2. Review actual values in report
3. Set baseline to ~150% of observed values (headroom for non-determinism)
4. Commit updated baselines

## Checklist

- [ ] `composer benchmark:dry` → 28/28 pass
- [ ] Init DTO contains sessionId
- [ ] Resume preserves context
- [ ] ST-001 passes expected-tool check
- [ ] MT-001 passes 2-turn memory workflow
- [ ] MT-002 passes 2-turn task workflow
- [ ] MT-003 passes 3-turn governance check
- [ ] telemetry-ci profile: 9 scenarios
- [ ] ci profile: 17 scenarios (no MT)
- [ ] full profile: 28 scenarios
- [ ] Regression check passes on smoke report
- [ ] PR gate runs on PR to Brain sources
- [ ] Nightly runs full profile with sonnet
