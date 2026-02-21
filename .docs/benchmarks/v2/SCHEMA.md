---
name: "Benchmark Scenario Schema"
description: "Scenario JSON schema reference for single-turn and multi-turn types"
type: "reference"
date: "2026-02-20"
version: "2.0"
---

# Scenario Schema Reference

## Single-turn (default)

```json
{
  "id": "L1-001",
  "title": "Short description",
  "difficulty": "S0|L1|L2|L3",
  "prompt": "Question for Brain",
  "timeout_s": 120,
  "max_output_tokens": 2000,
  "checks": {
    "required_patterns": ["regex1", "regex2"],
    "banned_patterns": ["regex"],
    "expected_mcp_calls": { "min": 0, "max": 5 },
    "expected_tools": ["mcp__vector-memory__search_memories"]
  }
}
```

## Multi-turn (type: "multi")

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
        "required_patterns": ["regex"],
        "banned_patterns": ["regex"],
        "expected_mcp_calls": { "min": 1, "max": 5 },
        "expected_tools": ["tool_name"]
      }
    },
    {
      "ask": "Turn 2 prompt",
      "checks": { ... }
    }
  ],
  "checks": {
    "expected_mcp_calls": { "min": 2, "max": 7 },
    "banned_patterns": ["scenario-level regex"]
  }
}
```

## Field Reference

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `id` | yes | string | Unique ID: S00-NNN, L{N}-NNN, ST-NNN, MT-NNN, MT-LP-NNN, CMD-NNN, CMD-AUTO-*, ADV-NNN |
| `title` | yes | string | Short description |
| `difficulty` | yes | string | S0, L1, L2, L3 |
| `type` | no | string | "single" (default) or "multi" |
| `prompt` | single only | string | Prompt for single-turn |
| `turns` | multi only | array | Array of turn objects |
| `turns[].ask` | yes | string | Prompt for this turn |
| `turns[].checks` | no | object | Per-turn checks |
| `timeout_s` | no | int | Per-scenario timeout (default: 120) |
| `max_output_tokens` | no | int | Token budget (default: 2000/3000) |
| `checks` | no | object | Scenario-level checks |

## Check Types

| Check | Scope | Description |
|-------|-------|-------------|
| `required_patterns` | per-turn / scenario | Regex must match response |
| `banned_patterns` | per-turn / scenario | Regex must NOT match |
| `expected_mcp_calls` | per-turn / scenario | MCP call count range {min, max} |
| `expected_tools` | per-turn / scenario | Exact tool names in ToolUse DTOs |
| `global-banned` | all scenarios | Hardcoded in runner: uncertainty triggers |
| `token-budget` | scenario | output_tokens <= max_output_tokens |
| `duration` | scenario | execution_ms <= timeout_s * 1000 |
| `dto-schema` | single only | init + message + result DTOs present |
| `session-init` | multi only | sessionId extracted from init DTO |
| `mode-leakage` | standard mode | Deep-mode content absent |

## ID Convention

| Prefix | Type | Range | Count |
|--------|------|-------|-------|
| S00 | Smoke | S00-000 | 1 |
| L1 | Tiny knowledge | L1-001..L1-007 | 7 |
| L2 | Applied knowledge | L2-001..L2-007 | 7 |
| L3 | Governance reasoning | L3-001..L3-008 | 8 |
| ST | Single-turn telemetry | ST-001..ST-006 | 6 |
| MT | Multi-turn | MT-001..MT-003 | 3 |
| MT-LP | Multi-turn learn protocol | MT-LP-001..MT-LP-003 | 3 |
| CMD | Command knowledge | CMD-001..CMD-006 | 6 |
| CMD-AUTO | Auto-generated command | CMD-AUTO-* | 28 |
| ADV | Adversarial | ADV-001..ADV-009 | 9 |
| **Total** | | | **78** |
