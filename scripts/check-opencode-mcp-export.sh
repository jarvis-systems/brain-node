#!/usr/bin/env bash
#
# Check Client MCP Export Contract (All Clients)
# Usage: scripts/check-opencode-mcp-export.sh
#
# Validates brain-tools MCP presence for ALL clients:
#   A) Claude: .mcp.json mcpServers.brain-tools with agent=claude
#   B) Codex: .codex/config.toml mcp_servers.brain-tools with agent=codex
#   C) Gemini: .gemini/settings.json mcpServers.brain-tools with agent=gemini
#   D) Qwen: .qwen/settings.json mcpServers.brain-tools with agent=qwen
#   E) OpenCode: .opencode/settings.json mcp.brain-tools with agent=opencode
#
# Exit: 0 = PASS, 1 = FAIL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

ERRORS=0

# A) Claude
echo "A) Testing Claude .mcp.json..."
if [[ ! -f ".mcp.json" ]]; then
    echo "  FAIL: .mcp.json not found"
    ERRORS=$((ERRORS + 1))
elif ! jq -e '.mcpServers["brain-tools"]' .mcp.json >/dev/null 2>&1; then
    echo "  FAIL: brain-tools not found in .mcp.json"
    ERRORS=$((ERRORS + 1))
else
    AGENT=$(jq -r '.mcpServers["brain-tools"].args[-1]' .mcp.json)
    if [[ "$AGENT" != "claude" ]]; then
        echo "  FAIL: brain-tools agent expected 'claude', got '$AGENT'"
        ERRORS=$((ERRORS + 1))
    else
        echo "  PASS: brain-tools with agent=claude"
    fi
fi

# B) Codex
echo "B) Testing Codex .codex/config.toml..."
if [[ ! -f ".codex/config.toml" ]]; then
    echo "  FAIL: .codex/config.toml not found"
    ERRORS=$((ERRORS + 1))
elif ! grep -q "mcp_servers.brain-tools" .codex/config.toml; then
    echo "  FAIL: brain-tools not found in .codex/config.toml"
    ERRORS=$((ERRORS + 1))
else
    if ! grep -q '"--agent","codex"' .codex/config.toml && ! grep -q '"--agent", "codex"' .codex/config.toml; then
        echo "  FAIL: brain-tools missing --agent codex in .codex/config.toml"
        ERRORS=$((ERRORS + 1))
    else
        echo "  PASS: brain-tools with agent=codex"
    fi
fi

# C) Gemini
echo "C) Testing Gemini .gemini/settings.json..."
if [[ ! -f ".gemini/settings.json" ]]; then
    echo "  FAIL: .gemini/settings.json not found"
    ERRORS=$((ERRORS + 1))
elif ! jq -e '.mcpServers["brain-tools"]' .gemini/settings.json >/dev/null 2>&1; then
    echo "  FAIL: brain-tools not found in .gemini/settings.json"
    ERRORS=$((ERRORS + 1))
else
    AGENT=$(jq -r '.mcpServers["brain-tools"].args[-1]' .gemini/settings.json)
    if [[ "$AGENT" != "gemini" ]]; then
        echo "  FAIL: brain-tools agent expected 'gemini', got '$AGENT'"
        ERRORS=$((ERRORS + 1))
    else
        echo "  PASS: brain-tools with agent=gemini"
    fi
fi

# D) Qwen
echo "D) Testing Qwen .qwen/settings.json..."
if [[ ! -f ".qwen/settings.json" ]]; then
    echo "  FAIL: .qwen/settings.json not found"
    ERRORS=$((ERRORS + 1))
elif ! jq -e '.mcpServers["brain-tools"]' .qwen/settings.json >/dev/null 2>&1; then
    echo "  FAIL: brain-tools not found in .qwen/settings.json"
    ERRORS=$((ERRORS + 1))
else
    AGENT=$(jq -r '.mcpServers["brain-tools"].args[-1]' .qwen/settings.json)
    if [[ "$AGENT" != "qwen" ]]; then
        echo "  FAIL: brain-tools agent expected 'qwen', got '$AGENT'"
        ERRORS=$((ERRORS + 1))
    else
        echo "  PASS: brain-tools with agent=qwen"
    fi
fi

# E) OpenCode
echo "E) Testing OpenCode .opencode/settings.json..."
if [[ ! -f ".opencode/settings.json" ]]; then
    echo "  FAIL: .opencode/settings.json not found"
    ERRORS=$((ERRORS + 1))
elif ! jq -e '.mcp["brain-tools"]' .opencode/settings.json >/dev/null 2>&1; then
    echo "  FAIL: brain-tools not found in .opencode/settings.json mcp section"
    ERRORS=$((ERRORS + 1))
else
    AGENT=$(jq -r '.mcp["brain-tools"].command[-1]' .opencode/settings.json)
    if [[ "$AGENT" != "opencode" ]]; then
        echo "  FAIL: brain-tools agent expected 'opencode', got '$AGENT'"
        ERRORS=$((ERRORS + 1))
    else
        echo "  PASS: brain-tools with agent=opencode"
    fi
fi

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "FAIL: $ERRORS client(s) missing brain-tools MCP"
    exit 1
fi

echo ""
echo "PASS: All 5 clients have brain-tools MCP with correct agent IDs"
exit 0
