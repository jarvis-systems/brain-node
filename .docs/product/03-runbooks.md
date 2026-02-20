---
name: "Operational Runbooks"
description: "Step-by-step procedures for common Brain operations: compile, benchmark, update, rollback"
type: "product"
version: "v0.1.0"
status: "active"
---

# Operational Runbooks

## 1. Standard Compile

```
brain compile
```

Compiles all targets (claude, codex, opencode). Default mode from `.brain/.env`.

**Paranoid mode compile:**
```
STRICT_MODE=paranoid brain compile
```

**Debug compile (on failure):**
```
BRAIN_CLI_DEBUG=1 brain compile
```

## 2. Run Benchmarks

Ordered by scope — run the smallest sufficient suite first.

| Profile | Command | Scenarios | Use Case |
|---------|---------|-----------|----------|
| smoke | `composer benchmark:smoke` | 1 (S00) | Quick sanity check |
| telemetry-ci | `composer benchmark:telemetry` | ~5 | PR gate, tool verification |
| ci | `composer benchmark:ci` | ~15 | Full CI validation |
| full | `composer benchmark` | All | Nightly comprehensive |
| matrix | `composer benchmark:matrix` | Stress subset x4 configs | Cross-mode validation |
| adversarial | `composer benchmark:adversarial` | ADV scenarios | Security boundary testing |

**Dry run (validate scenarios, no LLM calls):**
```
composer benchmark:dry
```

**Regression check (compare against baselines):**
```
composer benchmark:regression
```

## 3. Update MCP Server Versions

1. Check current pins: `cat pins.json`
2. Update version in `pins.json`
3. Compile with pinning: `PIN_STRICT=1 brain compile`
4. Verify pins: `PIN_STRICT=1 bash scripts/verify-pins.sh`
5. Run telemetry benchmark: `composer benchmark:telemetry`
6. If all pass, commit changes

## 4. Rollback to Previous Version

```
git checkout <tag> -- .mcp.json .claude/ .codex/ .opencode/
brain compile
```

Or reset entirely:
```
git checkout <tag>
brain compile
```

## 5. Add New Benchmark Scenario

1. Create scenario JSON in `.docs/benchmarks/scenarios/`
2. Validate: `composer benchmark:dry`
3. Run scenario: `bash scripts/benchmark-llm-suite.sh --scenario <ID> --json --model haiku`
4. Update baselines if needed: add entry to `.docs/benchmarks/baselines/baselines.json`
5. Commit all changes

## 6. Debug CI Failure

1. Read CI artifacts/logs for the failing step
2. Reproduce locally:
   - Lint: `bash scripts/lint-mcp-syntax.sh`
   - Benchmarks: `composer benchmark:dry`
   - Baselines: `jq empty .docs/benchmarks/baselines/baselines.json`
   - Pins: `PIN_STRICT=1 bash scripts/verify-pins.sh`
   - Compile discipline: check if `.brain/node/` changed without `.claude/` update
3. Fix and re-run locally before pushing
