---
name: "Failure Runbooks"
description: "Triage and resolution procedures for common failure scenarios in Brain operations"
type: "product"
version: "v0.2.0"
status: "active"
---

# Failure Runbooks

Each section follows the format: **Symptoms** → **Commands** → **Expected Output** → **Escalation**.

## 1. MCP Server Not Running

**Symptoms:**
- AI agent cannot call vector-memory or vector-task tools
- Benchmark scenarios with `expected_mcp_calls.min > 0` fail
- Error messages: "MCP server not responding", "connection refused", timeout on MCP operations

**Commands:**
```
# Check if MCP servers are defined in compiled config
jq '.mcpServers | keys' .mcp.json

# Test vector-memory-mcp availability
uvx vector-memory-mcp --help

# Test vector-task-mcp availability
uvx vector-task-mcp --help

# Recompile MCP config
brain compile

# Verify compiled MCP args
jq '.mcpServers["vector-memory"].args' .mcp.json
```

**Expected Output:**
- `jq` lists server keys: `["vector-memory", "vector-task", ...]`
- `uvx` commands print help text without errors
- After recompile, `.mcp.json` contains correct server definitions with args

**Escalation:**
- If `uvx` fails: check Python/uvx installation, network access to PyPI
- If servers appear in `.mcp.json` but AI CLI cannot connect: restart AI CLI session, check `--working-dir` arg in MCP config
- If recompile does not fix: check `.brain/node/Mcp/` source files, run `BRAIN_CLI_DEBUG=1 brain compile`

## 2. Pins Mismatch / PIN_STRICT Failure

**Symptoms:**
- `verify-pins.sh` exits with code 1
- CI release gate fails at "Verify pin policy" step
- `.mcp.json` contains unpinned package names (e.g., `vector-memory-mcp` without `==1.9.3`)

**Commands:**
```
# Check current pins
jq 'del(._meta)' pins.json

# Verify pins against compiled config
PIN_STRICT=1 bash scripts/verify-pins.sh

# Recompile with strict pinning
PIN_STRICT=1 brain compile

# Re-verify after recompile
PIN_STRICT=1 bash scripts/verify-pins.sh

# Compare compiled args to pin values
jq '.mcpServers["vector-memory"].args[0]' .mcp.json
```

**Expected Output:**
- `pins.json` shows package versions (e.g., `"vector-memory-mcp": "1.9.3"`)
- After `PIN_STRICT=1 brain compile`, `.mcp.json` args contain `package==version` format
- `verify-pins.sh` exits with code 0 and prints "All pins verified"

**Escalation:**
- If pins.json is missing: create it from known-good versions, see `02-configuration.md`
- If compile does not apply pins: check CLI version (`brain --version`), ensure CLI has compile-time pin resolution in `CompileTrait`
- If pin version does not exist on PyPI: roll back `pins.json` to previous version, re-verify

## 3. Benchmark Flake vs Real Regression

**Symptoms:**
- Benchmark scenario shows FLAKY_PASS or FLAKY_FAIL status in runner output
- Scenario intermittently fails across nightly runs
- Regression check warns about token/duration budget exceeded
- Same scenario passes in one mode but fails in another

**Automated Detection:**

The runner has built-in flakiness detection via retry. Profiles with retry enabled (nightly-live: retry=1) automatically classify results:
- **FLAKY_PASS**: failed first attempt, passed on retry → counts as PASSED, signals instability
- **FLAKY_FAIL**: failed all attempts → counts as FAILED

Check the `flaky_passed` / `flaky_failed` fields in JSON reports and the `"attempts"` field per scenario.

**Commands:**
```
# Run with retry enabled (nightly-live profile has retry=1 by default)
bash scripts/benchmark-llm-suite.sh --profile nightly-live --json --model sonnet 2>/dev/null | \
    jq '{flaky_passed, flaky_failed, scenarios: [.scenarios[] | select(.attempts > 1) | {id, status, attempts}]}'

# Run specific scenario with explicit retry override
bash scripts/benchmark-llm-suite.sh --scenario <ID> --json --model haiku

# Check regression baselines
jq '.profiles' .docs/benchmarks/baselines/baselines.json

# Run dry-run to validate scenario JSON
composer benchmark:dry

# Compare against baseline budget
bash scripts/benchmark-regression-check.sh
```

**Expected Output:**
- FLAKY_PASS scenarios: variance, not regression — monitor frequency
- FLAKY_FAIL in single run: wait for next nightly before declaring regression
- FLAKY_FAIL in 2+ consecutive nightly runs: **confirmed regression**
- Dry-run always passes (validates JSON schema, not LLM behavior)
- Regression check shows which profiles exceed thresholds

**Escalation:**
- **Flake (< 20% rate)**: monitor, no action needed — retry handles it automatically
- **Flake (> 20% rate)**: increase `timeout_s`, broaden `required_patterns` regex, add `"retry": N` to scenario JSON
- **Real regression**: check if model version changed, review compiled artifacts for rule changes, compare with last known-good commit
- **Budget exceeded**: update baselines with `50%` headroom from new observed values, document reason in commit message (respect 3-run stability window)

## 4. Governance Violation Detected

**Symptoms:**
- Agent performs action outside its authority level (e.g., Brain executes directly instead of delegating)
- Adversarial benchmark scenario fails: `banned_patterns` match found in output
- Mode self-switch detected at runtime (strict → standard or vice versa)

**Commands:**
```
# Run adversarial suite
composer benchmark:adversarial

# Run specific governance scenario
bash scripts/benchmark-llm-suite.sh --scenario ADV-003 --json --model haiku

# Check which patterns matched/failed
bash scripts/benchmark-llm-suite.sh --scenario ADV --json --model haiku 2>/dev/null | \
    jq '.results[] | {id, status, checks_detail}'

# Verify iron rules are compiled
grep -c "iron rule\|Iron Rule\|CRITICAL" .claude/CLAUDE.md
```

**Expected Output:**
- All ADV scenarios should return `PASS`
- `banned_patterns` should have zero matches
- `required_patterns` should all match
- CLAUDE.md should contain iron rules (dozens of matches expected)

**Escalation:**
- If ADV scenario fails: check if compiled artifacts are stale (`brain compile`), verify iron rules in `.brain/node/` source
- If mode self-switch: this is a model compliance issue — strengthen the `no-mode-self-switch` iron rule text, add more explicit examples
- If delegation violation: review agent authority levels, check `delegation-depth` and `non-recursive` iron rules

## 5. Release Bundle Validation Failure

**Symptoms:**
- `build-release-bundle.sh` exits with error
- CI release workflow fails at "Build release bundle" step
- Bundle is missing expected files or fails sha256 verification

**Commands:**
```
# Pre-flight: check all required files exist
for f in .claude/CLAUDE.md pins.json LICENSE .docs/releases/manifest.json; do
    [[ -f "$f" ]] && echo "OK: $f" || echo "MISSING: $f"
done

# Regenerate required artifacts
brain compile
PIN_STRICT=1 bash scripts/generate-manifest.sh

# Build bundle
bash scripts/build-release-bundle.sh

# Verify bundle contents
tar tzf dist/brain-enterprise-*.tar.gz | head -20

# Verify sha256
shasum -a 256 -c dist/brain-enterprise-*.sha256
```

**Expected Output:**
- All pre-flight files exist (4/4 OK)
- Bundle builds without errors, reports file count and size
- `tar tzf` shows expected directory structure (`.claude/`, `.docs/`, `scripts/`, root files)
- SHA256 verification passes

**Escalation:**
- If `.claude/` missing: run `brain compile` first
- If manifest missing: run `generate-manifest.sh` with `PIN_STRICT=1`
- If LICENSE missing: this is a project setup issue — LICENSE must exist in repository root
- If sha256 mismatch: re-build bundle (file may have been modified after build)

## 6. CI Failing on Matrix/Adversarial

**Symptoms:**
- CI matrix job fails with one or more scenario errors
- Adversarial matrix shows failures in specific mode combinations
- Timeout errors on stress scenarios (MT/ST)

**Commands:**
```
# Reproduce locally: standard mode
bash scripts/benchmark-llm-suite.sh --profile adversarial-matrix --json --model haiku

# Reproduce locally: paranoid mode
STRICT_MODE=paranoid bash scripts/benchmark-llm-suite.sh --profile adversarial-matrix --json --model haiku

# Check specific failing scenario
bash scripts/benchmark-llm-suite.sh --scenario <FAILING_ID> --json --model haiku 2>/dev/null | jq '.results[0]'

# Validate all scenario JSONs
composer benchmark:dry

# Check if baselines are outdated
jq '.profiles["adversarial-matrix"]' .docs/benchmarks/baselines/baselines.json
```

**Expected Output:**
- Local run reproduces CI failure (confirms not environment-specific)
- Dry-run passes (confirms scenario JSON is valid)
- Individual scenario output shows specific check failures

**Escalation:**
- **Timeout on MT/ST**: increase `timeout_s` in scenario JSON (180s → 240s), check MCP server latency
- **Mode-specific failure**: some scenarios may behave differently under paranoid vs standard — document as known limitation or fix scenario patterns
- **All scenarios fail**: likely AI CLI or MCP connectivity issue, not scenario problem — check CI runner environment setup
- **Baselines outdated**: update `baselines.json` with current observed values + 50% headroom
