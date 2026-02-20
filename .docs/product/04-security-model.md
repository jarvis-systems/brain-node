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
| Delegation abuse | Recursive or unauthorized delegation chains | `non-recursive` iron rule, delegation depth limit (2) | Complex multi-agent scenarios |

## Enforcement Layers

1. **Compile-time**: Iron rules baked into compiled artifacts. Cannot be overridden at runtime.
2. **Runtime governance**: Strict/cognitive mode controls enforcement level.
3. **Benchmarks**: Adversarial scenarios test boundary conditions.
4. **CI gates**: Pin verification, compile discipline, baseline regression.

## Known Gaps (Future Work)

- **Secret management**: API keys in MCP PHP source files need vault integration
- **NPX package pinning**: `context7` and `sequential-thinking` are not version-pinned
- **Audit logging**: No persistent audit trail for agent actions beyond session scope
- **Rate limiting**: No built-in rate limits for MCP server calls
