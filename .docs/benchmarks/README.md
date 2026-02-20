---
name: "Brain LLM Benchmark Suite"
description: "Behavioral benchmarks for compiled Brain/agents via Brain CLI with telemetry and multi-turn sessions"
type: "benchmark"
date: "2026-02-20"
version: "2.0"
---

# Brain LLM Benchmark Suite

Behavioral benchmarks for compiled Brain/agents via Brain CLI `--ask --json` mode.

## What It Tests

Each scenario sends a prompt through the full Brain pipeline (compile → claude --print → parse DTOs) and validates the response with grep-based checks + ToolUse DTO telemetry. No subjective text evaluation.

### Single-turn vs Multi-turn

**Single-turn** (default): One `--ask` prompt, validate response text and DTOs.

**Multi-turn** (`type: "multi"`): Sequential turns using `--resume <sessionId>` from Init DTO. Validates per-turn checks and scenario-level aggregates. Tests workflow correctness: store → search, create → list, governance continuity.

**Levels:**

| Level | Complexity | Description | Scenarios |
|-------|-----------|-------------|-----------|
| S0 | Smoke | Pipeline health check: compile → run → parse | 1 |
| L1 | Tiny | Knowledge retrieval: rules, constraints, ecosystem | 9 |
| L2 | Normal | Applied knowledge: MCP formats, policies, protocols | 9 |
| L3 | Hard | Governance reasoning: violations, conflicts, mode matrix | 8 |

**Check types:**

| Check | Description |
|-------|-------------|
| `required_patterns` | Regex patterns that MUST appear in response |
| `banned_patterns` | Regex patterns that MUST NOT appear in response |
| `global-banned` | Applied to ALL scenarios: uncertainty triggers |
| `expected_tools` | Exact tool names validated in ToolUse DTOs (telemetry-primary) |
| `expected_mcp_calls` | MCP call count range {min, max} |
| `token-budget` | Output tokens <= scenario max |
| `dto-schema` | All 3 DTO types present in JSONL output (init + message + result) |
| `session-init` | sessionId extracted from Init DTO (multi-turn only) |
| `duration` | Execution time within scenario timeout |
| `mode-leakage` | Deep-only content absent in standard mode |

## How to Run

### Composer aliases (recommended)

```bash
composer benchmark              # Full suite, interactive
composer benchmark:smoke        # S00 smoke test only (haiku, fast)
composer benchmark:ci           # CI profile (L1+L2+ST, haiku, JSON)
composer benchmark:telemetry    # Telemetry-CI profile (S00+L1+L2+ST+MT, haiku)
composer benchmark:mt           # Multi-turn scenarios only (haiku)
composer benchmark:dry          # Dry-run: validate scenarios, no AI calls
```

### Direct script

```bash
scripts/benchmark-llm-suite.sh --mode standard --model sonnet
scripts/benchmark-llm-suite.sh --profile smoke --model haiku
scripts/benchmark-llm-suite.sh --scenario L1-001 --model sonnet
scripts/benchmark-llm-suite.sh --scenario MT-001 --model haiku
scripts/benchmark-llm-suite.sh --dry-run --json
```

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--json` | off | Output JSON report only |
| `--mode` | standard | Compilation mode: standard, exhaustive, paranoid |
| `--profile` | full | smoke, ci, telemetry-ci, full |
| `--scenario` | all | Run single scenario by ID substring |
| `--model` | sonnet | AI model: sonnet, opus, haiku |
| `--dry-run` | off | Validate scenario files without AI calls |
| `--timeout` | 120 | Per-scenario timeout in seconds |
| `--yolo` | off | Pass --yolo to Brain CLI (bypass permissions) |

## Profiles

| Profile | Count | Scenarios | Approx. time |
|---------|-------|-----------|-------------|
| smoke | 1 | S00-000 | ~20s |
| ci | 17 | 7×L1 + 7×L2 + 3×ST | ~5-6 min |
| telemetry-ci | 9 | S00 + 3×L1 + 2×L2 + ST-001 + MT-001 + MT-002 | ~2.5 min |
| full | 28 | 7×L1 + 7×L2 + 7×L3 + 3×ST + 3×MT + S00 excluded | ~12 min |

## Cost Control

Each scenario invocation costs ~$0.05-0.25 depending on model and cache state. Multi-turn scenarios cost ~2x (2-3 API calls per scenario).

| Model | Approx. cost/scenario | 28 scenarios | 17 (ci) |
|-------|----------------------|-------------|---------|
| haiku | ~$0.02-0.05 | ~$0.56-1.40 | ~$0.34-0.85 |
| sonnet | ~$0.05-0.15 | ~$1.40-4.20 | ~$0.85-2.55 |
| opus | ~$0.15-0.30 | ~$4.20-8.40 | ~$2.55-5.10 |

**Cost reduction strategies:**

1. Use `--profile ci` in CI (17 scenarios, excludes MT and L3)
2. Use `--model haiku` for routine checks
3. Use `--model sonnet` for standard validation (recommended)
4. Reserve `--model opus` for release validation only
5. Sequential runs reuse Claude's prompt cache (5min TTL)

## How to Add a Scenario

### Single-turn

Create a JSON file in `.docs/benchmarks/scenarios/`:

```json
{
  "id": "L2-004",
  "title": "Short description",
  "difficulty": "L1|L2|L3",
  "prompt": "Question for the Brain in Ukrainian",
  "timeout_s": 120,
  "max_output_tokens": 2000,
  "checks": {
    "required_patterns": ["pattern1|alternative", "pattern2"],
    "banned_patterns": ["forbidden_pattern"],
    "expected_tools": ["mcp__vector-memory__search_memories"],
    "expected_mcp_calls": { "min": 1, "max": 5 }
  }
}
```

### Multi-turn

```json
{
  "id": "MT-001",
  "title": "Short description",
  "type": "multi",
  "difficulty": "L2",
  "timeout_s": 180,
  "max_output_tokens": 3000,
  "turns": [
    {
      "ask": "Turn 1 prompt",
      "checks": {
        "required_patterns": ["pattern"],
        "expected_mcp_calls": { "min": 1, "max": 5 }
      }
    },
    {
      "ask": "Turn 2 prompt",
      "checks": {
        "required_patterns": ["pattern"]
      }
    }
  ],
  "checks": {
    "expected_mcp_calls": { "min": 2, "max": 7 },
    "banned_patterns": ["scenario-level banned"]
  }
}
```

**Rules:**

- `id` format: `S00-{NNN}` for smoke, `L{N}-{NNN}` for L1/L2/L3, `ST-{NNN}` for single-turn telemetry, `MT-{NNN}` for multi-turn
- `prompt` (single) or `turns[].ask` (multi) should be in Ukrainian
- Patterns are POSIX extended regex (case-insensitive via grep -iE)
- Use `|` for alternatives in patterns (resilience against non-determinism)
- Multi-turn: minimum 2 turns, each must have `ask` field
- Avoid overly specific patterns; prefer broad alternatives
- Tag benchmark side-effects with `benchmark-test` for cleanup

## Scenario Coverage Map

| ID | Area | Type | Tests |
|----|------|------|-------|
| S00-000 | Smoke | single | Pipeline health: compile → run → parse DTOs |
| L1-001 | VectorMemory | single | Iron rules names + severity |
| L1-002 | Delegation | single | Max depth + chain levels |
| L1-003 | Compilation | single | Source vs compiled dirs |
| L1-004 | Constraints | single | Token limit + execution time |
| L1-005 | Ecosystem | single | Available agents + roles |
| L1-006 | Pipeline | single | Compilation flow steps |
| L1-007 | CLI | single | Command format (no php prefix) |
| L2-001 | MCP | single | VectorTask create call format |
| L2-002 | MCP | single | VectorMemory search call format |
| L2-003 | Quality | single | Quality gates commands |
| L2-004 | Error | single | Escalation policy levels |
| L2-005 | Budget | single | Memory search + cookbook pull limits |
| L2-006 | Docs | single | brain docs protocol |
| L2-007 | Rules | single | Spirit vs letter interpretation |
| L3-001 | Governance | single | Iron rules vs cookbook precedence |
| L3-002 | Violation | single | Search-before-store detection |
| L3-003 | Cookbook | single | Pull policy compliance |
| L3-004 | Mode | single | Standard vs exhaustive awareness |
| L3-005 | Mode | single | No-mode-self-switch enforcement |
| L3-006 | Delegation | single | Chain depth violation detection |
| L3-007 | Compile | single | Compile-time vs runtime constraints |
| ST-001 | Telemetry | single | Force MCP call, verify via expected_tools |
| ST-002 | Budget | single | Tight token/duration limits |
| ST-003 | Mode | single | Compile-time mode invariant |
| MT-001 | Memory | multi | Store → search → verify retrieval (2 turns) |
| MT-002 | Task | multi | Create → list → validate fields (2 turns) |
| MT-003 | Governance | multi | Cookbook limits across 3 turns |

## Ground Truth

Checks are derived from compiled Brain artifacts:

- **Iron rules**: Defined in `core/src/Includes/Universal/*.php` and `core/src/Includes/Brain/*.php`
- **MCP formats**: Defined in `.brain/node/Mcp/*.php` via `McpArchitecture::callJson()`
- **Governance policy**: Defined in `VectorMemoryInclude.php` and `VectorTaskInclude.php`
- **Quality gates**: Defined in `core/src/Includes/Universal/QualityGates.php`
- **Compilation dirs**: Defined in `CompilationSystemKnowledgeInclude.php`

When source includes change, scenario checks may need updating.

## Limitations

1. **Non-determinism**: AI responses vary between runs. Pattern checks are designed to be resilient (multiple alternatives via `|`), but false failures are possible. Multi-turn amplifies this.
2. **Token costs**: Each run burns real API tokens. Use appropriate model/profile.
3. **Multi-turn side effects**: MT-001 stores memory, MT-002 creates tasks. Tagged `benchmark-test` for cleanup.
4. **Language coupling**: Prompts and some checks assume Ukrainian-language responses per Brain configuration.

## Telemetry: tool_use Tracking

The benchmark runner captures MCP tool_use events emitted by Brain CLI via the `ToolUse` DTO. This provides observability into which tools the Brain invokes during each scenario.

**How it works:**

1. Brain CLI emits `{type: "tool_use", name: "...", id: "...", input: {...}}` JSONL lines alongside `message` and `result` DTOs
2. The runner counts tool_use lines per scenario → `mcp_calls_count`
3. `expected_tools` check validates exact tool names from ToolUse DTOs (telemetry-primary)
4. Report aggregates → `total_mcp_calls`

**v2 additions:**

- `expected_tools` check type: validates exact tool names against ToolUse events
- Init DTO parsing: extracts `sessionId` for multi-turn `--resume`
- Per-turn telemetry: each turn independently tracks tool_use events

**CLI changes (for reference):**

- `ToolUse` DTO: `cli/src/Dto/ProcessOutput/ToolUse.php`
- Message parsing fix: `ClaudeClient::processParseOutputMessage()` now iterates ALL content blocks (text + tool_use), not just `content[0]`
- Pipeline emit: `ProcessTrait::processParseOutput()` emits ToolUse DTOs after Message DTOs
- ProcessTrait fix: `type: Type::RUN` → `type: $type` (correct processType for resume/continue)

**Backward compatible:** Existing consumers that switch on `type` field simply ignore unknown types.

## CI Integration

GitHub Actions workflow: `.github/workflows/brain-benchmark.yml`

**Jobs:**

| Job | Trigger | Profile | Model | Purpose |
|-----|---------|---------|-------|---------|
| `smoke-test` | Every run | S00 only | haiku | Quick pipeline gate (< 2 min) |
| `benchmark-suite` | After smoke | Input or `ci` | Input or `sonnet` | Full benchmark with artifact upload |

**Triggers:**
- Nightly at 03:00 UTC (schedule)
- Manual dispatch with profile/model selection

**Requirements:**
- `ANTHROPIC_API_KEY` secret
- `jarvis-brain/cli` (composer global)
- `@anthropic-ai/claude-code` (npm global)

**Artifacts:** `benchmark-report.json` retained 30 days.

**Dry-run validation** (no secrets needed) runs in `brain-lint.yml` on every push/PR.

## JSON Report Schema

### Single-turn result

```json
{
  "id": "L1-001",
  "title": "Vector Memory iron rules knowledge",
  "difficulty": "L1",
  "status": "PASS",
  "duration_ms": 8500,
  "input_tokens": 150,
  "output_tokens": 420,
  "mcp_calls_count": 2,
  "response_chars": 1200,
  "checks": [
    {"check": "response-received", "status": "PASS"},
    {"check": "dto-schema", "status": "PASS", "detail": "init=1 msg=1 result=1"},
    {"check": "required:mcp-json-only", "status": "PASS", "detail": "2 matches"},
    {"check": "expected-tool:mcp__vector-memory__search_memories", "status": "PASS"},
    {"check": "token-budget", "status": "PASS", "detail": "420 <= 1500"}
  ]
}
```

### Multi-turn result

```json
{
  "id": "MT-001",
  "title": "Memory: store → search → verify",
  "difficulty": "L2",
  "status": "PASS",
  "duration_ms": 45000,
  "input_tokens": 1200,
  "output_tokens": 600,
  "mcp_calls_count": 3,
  "response_chars": 2500,
  "turns": 2,
  "checks": [
    {"check": "session-init", "status": "PASS", "detail": "abc123ef..."},
    {"check": "turn1:required:store", "status": "PASS", "detail": "2 matches"},
    {"check": "turn2:required:XML", "status": "PASS", "detail": "1 matches"},
    {"check": "global-banned:when", "status": "PASS"},
    {"check": "token-budget", "status": "PASS", "detail": "600 <= 3000"}
  ]
}
```
