---
name: "Operational Runbooks"
description: "Step-by-step procedures for common Brain operations: compile, benchmark, memory status, update, rollback"
type: "product"
version: "v0.2.0"
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

## 2. Compile Diff Preview

Preview compilation changes without modifying output files. Useful for CI gates and pre-merge checks.

```
brain compile --diff
```

**How it works:** backup current output → compile → diff backup vs new → restore original files.

**Exit codes:**

| Code | Meaning | Use in scripts |
|------|---------|----------------|
| 0 | No differences — compiled output is up to date | `brain compile --diff && echo "clean"` |
| 1 | Compilation error — diff aborted | Treat as build failure |
| 2 | Differences found — source and compiled output diverged | `brain compile --diff; [ $? -eq 2 ] && echo "needs recompile"` |

**JSON output for scripting:**
```
brain compile --diff --json
```

Returns a stable schema with `status` (`no_diff` / `diff`), `exit_code`, per-file summary with `hash_before` / `hash_after` (sha256, 12 chars), and line-level counts.

**CI gate example:**
```bash
brain compile --diff --json > /tmp/diff.json
STATUS=$(jq -r '.status' /tmp/diff.json)
if [ "$STATUS" = "diff" ]; then
  echo "Compile output is stale. Run: brain compile"
  jq '.files[] | "\(.status) \(.path)"' /tmp/diff.json
  exit 1
fi
```

**Volatile exclusions** (automatically ignored during diff):
- `.phpunit.cache` — PHPUnit result cache
- `.phpstan` — PHPStan cache directory
- `compile.lock` — compilation lock file

**Safety:** Restore runs in a `finally` block — original files are always restored, even on compilation failure.

## 3. Memory Status Dashboard

Quick read-only snapshot of memory health. Reads cached artifacts from `.work/memory-hygiene/` — no MCP server spawned, completes in <1s.

```
brain memory:status
```

**Default output (human-readable):**

```
  Memory Status

  Status ............. ok
  Namespace .......... jarvis-brain-node
  Total memories ..... 207 (190 active)
  Health ............. Healthy
  Smoke pass rate .... 100% (15/15) — threshold met
  Critical score ..... 100% (7/7)
  Rank safety ........ ALL_CLEAR (0 overlap risks)
  Last hygiene run ... 2026-02-22 19:00 UTC

  Top categories:
    code-solution .... 127
    architecture ..... 57
    bug-fix .......... 9
    tool-usage ....... 8
    learning ......... 3
```

**JSON output for scripting:**

```
brain memory:status --json
```

Returns a stable schema:

```json
{
  "version": "1.0.0",
  "status": "ok",
  "namespace": "jarvis-brain-node",
  "counts": { "total_memories": 207, "active_memories": 190, "canonical_tags": 15, "unique_tags": 553 },
  "health": "Healthy",
  "smoke": { "pass_rate": 1.0, "critical_pass_rate": 1.0, "threshold_met": true, "passed": 15, "total": 15, "critical_passed": 7, "critical_total": 7 },
  "rank_safety": { "verdict": "ALL_CLEAR", "overlap_risks": 0 },
  "last_run": "2026-02-22T19:00:00Z",
  "top_categories": [ { "name": "code-solution", "count": 127 } ],
  "hints": []
}
```

**Statuses:**

| Status | Meaning | Action |
|--------|---------|--------|
| `ok` | All 3 artifacts present, total_memories > 0 | None — memory is healthy |
| `stale` | One or more artifacts missing | Run `brain memory:hygiene` to regenerate |
| `no_data` | No artifacts at all, or total_memories = 0 | Run `brain memory:hygiene` to generate initial baseline |

**Staleness hints:** If `snapshot_date` in ledger is > 24h old, a warning hint appears. Over 7 days triggers an urgent hint.

**Readiness integration:** `brain readiness:check` includes `memory_status` as an informational (NEUTRAL) section. It never affects the pass/fail outcome.

## 4. Run Benchmarks

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

## 5. Update MCP Server Versions

1. Check current pins: `cat pins.json`
2. Update version in `pins.json`
3. Compile with pinning: `PIN_STRICT=1 brain compile`
4. Verify pins: `PIN_STRICT=1 bash scripts/verify-pins.sh`
5. Run telemetry benchmark: `composer benchmark:telemetry`
6. If all pass, commit changes

## 6. Rollback to Previous Version

```
git checkout <tag> -- .mcp.json .claude/ .codex/ .opencode/
brain compile
```

Or reset entirely:
```
git checkout <tag>
brain compile
```

## 7. Add New Benchmark Scenario

1. Create scenario JSON in `.docs/benchmarks/scenarios/`
2. Validate: `composer benchmark:dry`
3. Run scenario: `bash scripts/benchmark-llm-suite.sh --scenario <ID> --json --model haiku`
4. Update baselines if needed: add entry to `.docs/benchmarks/baselines/baselines.json`
5. Commit all changes

## 8. Debug CI Failure

1. Read CI artifacts/logs for the failing step
2. Reproduce locally:
   - Lint: `bash scripts/lint-mcp-syntax.sh`
   - Benchmarks: `composer benchmark:dry`
   - Baselines: `jq empty .docs/benchmarks/baselines/baselines.json`
   - Pins: `PIN_STRICT=1 bash scripts/verify-pins.sh`
   - Compile discipline: check if `.brain/node/` changed without `.claude/` update
3. Fix and re-run locally before pushing
