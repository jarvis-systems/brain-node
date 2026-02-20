---
name: "Pilot Guide"
description: "Enterprise pilot deployment guide with success criteria and support workflow"
type: "product"
version: "v0.1.1"
status: "active"
---

# Pilot Guide

## Prerequisites

Before running a pilot deployment:

1. **Brain CLI** installed globally: `composer global require jarvis-brain/cli`
2. **AI CLI** installed: `npm install -g @anthropic-ai/claude-code` (or target platform CLI)
3. **MCP servers** available: `vector-memory-mcp`, `vector-task-mcp` (via uvx)
4. **API key** configured for the target model provider
5. **jq** installed (JSON processing)

## Running from Release Bundle

Extract the bundle and run the enterprise demo:

```
tar xzf brain-enterprise-vX.Y.Z.tar.gz
cd brain-enterprise-vX.Y.Z
bash scripts/demo-enterprise.sh
```

Override the default model (haiku) if needed:

```
bash scripts/demo-enterprise.sh --model sonnet
```

The demo runs 3 curated scenarios:

| ID | Type | What It Proves |
|----|------|---------------|
| MT-001 | Multi-turn | Memory store, search, session continuity |
| MT-002 | Multi-turn | Task create, list, session continuity |
| ADV-003 | Adversarial | Rejects runtime cookbook parameter injection |

Output: `dist/demo-report.json` (consolidated results).

## Success Criteria

A pilot is considered successful when ALL of the following are met:

1. **Demo pass rate = 100%**: All 3 scenarios (MT-001, MT-002, ADV-003) return PASS status
2. **Zero policy violations**: No banned patterns detected, no unauthorized tool calls
3. **MCP connectivity verified**: Multi-turn scenarios confirm vector-memory and vector-task MCP servers respond correctly
4. **Session continuity works**: MT-001 and MT-002 prove `--resume` with sessionId maintains context across turns
5. **Adversarial resistance confirmed**: ADV-003 proves the system rejects runtime cookbook parameter construction attempts, citing compile-time-only policy

## Artifacts to Send Support

When reporting issues or requesting assistance, include these files:

| Artifact | Location | Purpose |
|----------|----------|---------|
| Demo report | `dist/demo-report.json` | Scenario results, tokens, duration, MCP calls |
| Build manifest | `.docs/releases/manifest.json` | Version, pins, compilation mode, baselines |
| MCP config | `.mcp.json` | Active MCP server configuration |
| Compile output | stdout of `brain compile` | Compilation errors or warnings (if any) |

Attach all 4 artifacts to your support request. See `05-support.md` for the bug report template and contact information.

## Cost Estimates

| Model | 3 Scenarios | Notes |
|-------|-------------|-------|
| haiku | ~$0.06-0.15 | Recommended for pilot validation |
| sonnet | ~$0.15-0.45 | Higher quality, higher cost |
| opus | ~$0.45-0.90 | Maximum quality, use if budget allows |

Estimates based on benchmark baselines. Actual costs depend on MCP response times and model output length.

## Troubleshooting

**Demo script not found**: Ensure you extracted the full bundle. The `scripts/` directory must contain `demo-enterprise.sh` and `benchmark-llm-suite.sh`.

**MCP connection failures**: Verify MCP servers are running. Check `.mcp.json` for correct server paths. Run `brain compile` to regenerate if needed.

**Scenario timeout**: Default timeouts are 180s for multi-turn, 60s for adversarial. Slow network or MCP servers may cause timeouts. Check MCP server health first.

**All scenarios fail with "no output"**: The AI CLI command is not found or not configured. Verify `ai --version` works. Set `BRAIN_AI_CMD` env var if the CLI is at a non-standard path.
