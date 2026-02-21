---
name: "ADR-001: Free-First + Golden Verification Strategy"
description: "Architecture decision for multi-model benchmark strategy: free model for nightly runs, opus for golden verification"
type: "adr"
date: "2026-02-21"
status: "accepted"
---

# ADR-001: Free-First + Golden Verification Strategy

## Status

Accepted

## Context

The benchmark suite was hardcoded to Claude (`ai claude`) for all runs. This had two problems:

1. **Cost:** Every nightly run costs API credits (haiku/sonnet). With 8 live scenarios plus matrix and adversarial tests, nightly costs accumulate.
2. **Coverage:** No multi-provider verification. Instructions are compiled for multiple agents (Claude, OpenCode, Codex, Gemini, Qwen) but only tested against Claude.

Additionally, only `ClaudeClient` implemented `processParseOutputToolUse()` for tool tracking. All other clients returned `null`, meaning benchmarks with `expected_tools`, `banned_tools`, or `mcp_calls` checks would produce incorrect results on non-Claude agents.

## Decision

### Multi-Model Strategy

Implement a **free-first** strategy with **golden verification**:

- **Free-first (nightly):** Run the same 8-scenario nightly proof set on a free model (`opencode/glm-4.7-free` via OpenCode CLI) at zero API cost. This catches structural instruction regressions without spending budget.
- **Golden verification (manual/weekly):** Run the same 8 scenarios on Claude Opus (`claude-opus-4-6`) for high-confidence behavioral verification. Golden reports are retained 90 days as long-term reference baselines.

### Universal ToolUse Parsing

Implement `processParseOutputToolUse()` for all client families:

| Client | JSONL Format |
|--------|-------------|
| ClaudeClient | `assistant.message.content[].type === "tool_use"` |
| OpenCodeClient | `type === "tool_use"`, `part.{tool, callID, state.input}` |
| CodexClient | `item.completed.item.type` matching `command_execution`, `mcp_tool_call`, `collab_tool_call`, `web_search` |
| GeminiClient | `type === "tool_use"`, `{tool_name, tool_id, parameters}` |
| QwenClient | Claude-compatible format (Qwen CLI is a Claude Code fork) |

Inheritors (GroqClient, OpenRouterClient, LMStudioClient) inherit from CodexClient automatically.

### Runner Changes

- `--agent <name>` flag selects which CLI to use (default: `claude`)
- `--model-tier <tier>` overrides automatic tier detection for non-standard model names
- `free-live` and `golden-live` profiles added to runner, baselines, CI, and composer scripts

## Consequences

### Positive

- Nightly structural coverage at zero cost
- Multi-provider instruction validation
- Golden reports provide high-confidence baselines for comparison
- All 5 client families now have correct tool tracking
- Model gating handles capability gaps (free model maps to haiku tier, skips sonnet-requiring scenarios)

### Negative

- Free model quality is lower than Claude; more scenario failures expected (mitigated by model gating + WARN-only mode)
- Free model baselines need tuning after initial runs (higher token/duration budgets)
- CLI version changes may break JSONL format parsing (mitigated by reading source code for format verification)

### Neutral

- Existing profiles (ci, full, nightly-live, etc.) are completely unchanged
- Zero instruction budget delta (no compiled instruction changes)
