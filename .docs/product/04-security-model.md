---
name: "Security Model"
description: "Threat model, mitigations, and residual risks for Brain system"
type: "product"
version: "v0.1.0"
status: "active"
---

# Security Model

## Threat Model

| Threat | Vector | Mitigation | Residual Risk |
|--------|--------|------------|---------------|
| Prompt injection | User input to AI agent | ADV-004 benchmark scenario, governance iron rules | Non-deterministic LLM behavior |
| Hallucinated tools | AI invents non-existent MCP tools | ADV-001/ADV-002 benchmark scenarios, strict mode | Model-dependent hallucination rate |
| Supply chain (MCP) | uvx/npx pulling latest unvetted versions | `PIN_STRICT=1`, `pins.json` version pinning | Manual pin bump process |
| Cookbook poisoning | Runtime cookbook pulls inject bad patterns | Compile-time presets, 2-pull-per-session limit | Preset staleness over time |
| Secret leakage | API keys in `.mcp.json` or `.env` | `.gitignore` exclusions, no secrets in PHP source | API keys referenced in MCP PHP classes (future: vault) |
| Mode bypass | Agent changes strict/cognitive mode at runtime | `no-mode-self-switch` iron rule, ADV-003 benchmark | LLM non-compliance |
| Memory pollution | Duplicate or incorrect vector memory entries | `search-before-store` iron rule, memory dedup | Semantic similarity thresholds |
| Command execution | Executing write/scaffold commands via MCP | Policy strictly allows read-only operations only | LLM hallucinations bypassing standard schema |
| Persistent servers | Attacks on long-running daemon memory/sockets | Stdio-only execution model (no daemons) | OS-level isolation limits |

## Architectural Boundaries: MCP Stdio-Only

The Brain MCP implementation strictly adheres to a **CLI stdio-only** execution model.
- **No background servers**: There are no daemons, supervisors, or background processes.
- **Attack surface reduction**: By eliminating long-running servers, we eliminate persistent memory corruption risks, connection hijacking, and daemon privilege escalation vectors.

### Test Fixtures
No test fixtures are embedded in the codebase. All MCP servers are production servers or external packages.



## Enforcement Layers

1. **Compile-time**: Iron rules baked into compiled artifacts. Cannot be overridden at runtime.
2. **Runtime governance**: Strict/cognitive mode controls enforcement level.
3. **Benchmarks**: Adversarial scenarios test boundary conditions.
4. **CI gates**: Pin verification, compile discipline, baseline regression.

## Compile Safety Contract

Single-writer lock prevents concurrent `brain compile` race conditions. Lock uses `flock()` — kernel-managed, auto-released on process death.

**Rules:**
- Lock is mandatory. Concurrent compile attempts are blocked with holder PID/timestamp.
- `--no-lock` is emergency-only, gated by strict mode policy:
  - `paranoid` / `strict`: blocked unless `BRAIN_ALLOW_NO_LOCK=1` is set in environment.
  - `standard` / `relaxed`: allowed with warning.
- Compile auto-detects project root — running from a subdirectory triggers auto-chdir to root.
- Compile must never dirty tracked files. Gate: `scripts/check-compile-clean.sh` (audit check 19/19).

**Verification:** `brain compile` → `git status --porcelain` must show zero new changes.

## Test Mode Contract

The `--no-lock` flag bypasses the single-writer compile mutex. To prevent production misuse, this bypass is gated by a test mode contract with Ferrari-grade hardening:

**Requirements for `--no-lock` or `BRAIN_ALLOW_NO_LOCK=1`:**

1. **Test mode indicator** — ONE of:
   - PHPUnit runtime detected (`PHPUnit\Framework\TestCase` class exists) — bypasses all isolation checks
   - `BRAIN_TEST_MODE=1` environment variable — requires isolation verification

2. **Leakage prevention** — If `BRAIN_TEST_MODE=1` without PHPUnit:
   - Requires `BRAIN_TEST_MODE_SOURCE=ci` to prevent accidental production leakage

3. **Isolated workdir** — Required when using `BRAIN_TEST_MODE` (PHPUnit bypasses this):
   - Under `sys_get_temp_dir()` OR under project `dist/tmp/`
   - `.brain-testmode.marker` file present
   - **NOT** a Brain project root (project root is NEVER isolated)

**Critical:** 
- PHPUnit detection bypasses ALL isolation checks. Tests can run from any directory.
- Project root is never considered isolated, even with marker file present.
- Marker in project root is treated as misconfiguration and will be rejected with `reason=marker_in_project_root`.

**Violation behavior:**
- Structured error: `code=NOLOCK_FORBIDDEN reason=<code> hint=<action>`
- Reasons: `missing_test_mode`, `leaky_test_mode`, `non_isolated_workdir`, `marker_in_project_root`
- No path leakage: only basenames in error messages

**Implementation:** `CompileLock::validateTestModeContract()` in CLI package.

**Inspector:** `brain diagnose` includes `test_mode_contract` section with full diagnostics.

**Audit:** Check 24 in `scripts/audit-enterprise.sh` validates:
- No `BRAIN_ALLOW_NO_LOCK` usage outside test files
- `CompileCommand` calls validation method
- `CompileLock` has required test mode methods
- `.brain-testmode.marker` file exists

## Known Gaps (Future Work)

- **Secret management**: API keys in MCP PHP source files need vault integration
- **NPX package pinning**: `context7` and `sequential-thinking` are not version-pinned
- **Audit logging**: No persistent audit trail for agent actions beyond session scope
- **Rate limiting**: No built-in rate limits for MCP server calls
