# Brain LLM Benchmark Suite

Behavioral benchmarks for compiled Brain/agents via Brain CLI `--ask --json` mode.

## What It Tests

Each scenario sends a prompt through the full Brain pipeline (compile → claude --print → parse DTOs) and validates the response with grep-based checks. No subjective text evaluation.

**Levels:**

| Level | Complexity | Description | Scenarios |
|-------|-----------|-------------|-----------|
| L1 | Tiny | Knowledge retrieval: rules, constraints, ecosystem | 7 |
| L2 | Normal | Applied knowledge: MCP formats, policies, protocols | 7 |
| L3 | Hard | Governance reasoning: violations, conflicts, mode matrix | 7 |

**Check types:**

| Check | Description |
|-------|-------------|
| `required_patterns` | Regex patterns that MUST appear in response |
| `banned_patterns` | Regex patterns that MUST NOT appear in response |
| `global-banned` | Applied to ALL scenarios: uncertainty triggers |
| `token-budget` | Output tokens <= scenario max |
| `mode-leakage` | Deep-only content absent in standard mode |

## How to Run

### Local (full suite)

```bash
scripts/benchmark-llm-suite.sh --mode standard --model sonnet
```

### Local (CI profile — L1+L2 only)

```bash
scripts/benchmark-llm-suite.sh --mode standard --profile ci --model sonnet
```

### Single scenario

```bash
scripts/benchmark-llm-suite.sh --scenario L1-001 --model sonnet
```

### Dry-run (validate scenarios, no AI calls)

```bash
scripts/benchmark-llm-suite.sh --dry-run
```

### JSON output (for CI parsing)

```bash
scripts/benchmark-llm-suite.sh --json --mode standard --profile ci --model sonnet
```

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--json` | off | Output JSON report only |
| `--mode` | standard | Compilation mode: standard, exhaustive, paranoid |
| `--profile` | full | ci = L1+L2, full = all levels |
| `--scenario` | all | Run single scenario by ID substring |
| `--model` | sonnet | AI model: sonnet, opus, haiku |
| `--dry-run` | off | Validate scenario files without AI calls |
| `--timeout` | 120 | Per-scenario timeout in seconds |
| `--yolo` | off | Pass --yolo to Brain CLI (bypass permissions) |

## Cost Control

Each scenario invocation costs ~$0.05-0.25 depending on model and cache state.

| Model | Approx. cost/scenario | 21 scenarios | 14 (ci) |
|-------|----------------------|-------------|---------|
| haiku | ~$0.02-0.05 | ~$0.42-1.05 | ~$0.28-0.70 |
| sonnet | ~$0.05-0.15 | ~$1.05-3.15 | ~$0.70-2.10 |
| opus | ~$0.15-0.30 | ~$3.15-6.30 | ~$2.10-4.20 |

**Cost reduction strategies:**

1. Use `--profile ci` in CI (14 scenarios instead of 21)
2. Use `--model haiku` for routine checks
3. Use `--model sonnet` for standard validation (recommended)
4. Reserve `--model opus` for release validation only
5. Sequential runs reuse Claude's prompt cache (5min TTL)

## How to Add a Scenario

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
    "banned_patterns": ["forbidden_pattern"]
  }
}
```

**Rules:**

- `id` format: `L{N}-{NNN}` (L1/L2/L3 + sequence number)
- `prompt` should be in Ukrainian (Brain responds in Ukrainian)
- Patterns are POSIX extended regex (case-insensitive via grep -iE)
- Use `|` for alternatives in patterns
- L1: no tools needed, knowledge verification
- L2: tool format knowledge, 1 preset cookbook
- L3: governance reasoning, policy compliance

## Scenario Coverage Map

| ID | Area | Tests |
|----|------|-------|
| L1-001 | VectorMemory | Iron rules names + severity |
| L1-002 | Delegation | Max depth + chain levels |
| L1-003 | Compilation | Source vs compiled dirs |
| L1-004 | Constraints | Token limit + execution time |
| L1-005 | Ecosystem | Available agents + roles |
| L1-006 | Pipeline | Compilation flow steps |
| L1-007 | CLI | Command format (no php prefix) |
| L2-001 | MCP | VectorTask create call format |
| L2-002 | MCP | VectorMemory search call format |
| L2-003 | Quality | Quality gates commands |
| L2-004 | Error | Escalation policy levels |
| L2-005 | Budget | Memory search + cookbook pull limits |
| L2-006 | Docs | brain docs protocol |
| L2-007 | Rules | Spirit vs letter interpretation |
| L3-001 | Governance | Iron rules vs cookbook precedence |
| L3-002 | Violation | Search-before-store detection |
| L3-003 | Cookbook | Pull policy compliance |
| L3-004 | Mode | Standard vs exhaustive awareness |
| L3-005 | Mode | No-mode-self-switch enforcement |
| L3-006 | Delegation | Chain depth violation detection |
| L3-007 | Compile | Compile-time vs runtime constraints |

## Ground Truth

Checks are derived from compiled Brain artifacts:

- **Iron rules**: Defined in `core/src/Includes/Universal/*.php` and `core/src/Includes/Brain/*.php`
- **MCP formats**: Defined in `.brain/node/Mcp/*.php` via `McpArchitecture::callJson()`
- **Governance policy**: Defined in `VectorMemoryInclude.php` and `VectorTaskInclude.php`
- **Quality gates**: Defined in `core/src/Includes/Universal/QualityGates.php`
- **Compilation dirs**: Defined in `CompilationSystemKnowledgeInclude.php`

When source includes change, scenario checks may need updating.

## Limitations

1. **No direct tool call tracking**: Brain CLI DTOs don't include MCP tool_use events. Behavioral checks are indirect (response text analysis).
2. **Non-determinism**: AI responses vary between runs. Pattern checks are designed to be resilient (multiple alternatives via `|`), but false failures are possible.
3. **Token costs**: Each run burns real API tokens. Use appropriate model/profile.
4. **Single-turn only**: `--ask` mode is single-turn. Multi-turn agent delegation is not testable.
5. **Language coupling**: Prompts and some checks assume Ukrainian-language responses per Brain configuration.

## CI Integration

Add to your CI pipeline:

```yaml
benchmark-llm:
  stage: test
  script:
    - scripts/benchmark-llm-suite.sh --json --mode standard --profile ci --model haiku
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
    - if: $CI_PIPELINE_SOURCE == "web"
  allow_failure: true
```

For nightly/manual runs with full suite:

```yaml
benchmark-llm-full:
  stage: test
  script:
    - scripts/benchmark-llm-suite.sh --json --mode standard --profile full --model sonnet
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
    - when: manual
  allow_failure: true
```

## JSON Report Schema

```json
{
  "total": 21,
  "passed": 21,
  "failed": 0,
  "errors": 0,
  "pass_rate": "100.0%",
  "mode": "standard",
  "cognitive": "standard",
  "profile": "full",
  "model": "sonnet",
  "dry_run": false,
  "total_input_tokens": 1500,
  "total_output_tokens": 4200,
  "total_duration_ms": 85000,
  "scenarios": [
    {
      "id": "L1-001",
      "title": "Vector Memory iron rules knowledge",
      "difficulty": "L1",
      "status": "PASS",
      "duration_ms": 8500,
      "input_tokens": 150,
      "output_tokens": 420,
      "response_chars": 1200,
      "checks": [
        {"check": "response-received", "status": "PASS"},
        {"check": "global-banned:when", "status": "PASS"},
        {"check": "required:mcp-json-only", "status": "PASS", "detail": "2 matches"},
        {"check": "token-budget", "status": "PASS", "detail": "420 <= 1500"}
      ]
    }
  ]
}
```
