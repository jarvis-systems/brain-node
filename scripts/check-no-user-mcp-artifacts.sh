#!/usr/bin/env bash
# Check 54: No user MCP artifacts
# Ensures no user-facing MCP junk remains in the project

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

ERRORS=0
FINDINGS=""

# ═══════════════════════════════════════════════════════════════════════════
# SUB-CHECK 54.1: No MockEcho files
# ═══════════════════════════════════════════════════════════════════════════
mockecho_files=$(find . -type f -name "*[Mm]ock[Ee]cho*" 2>/dev/null | grep -v "vendor\|node_modules\|.git" || true)
if [[ -n "$mockecho_files" ]]; then
    ERRORS=$((ERRORS + 1))
    FINDINGS+="\n[54.1 FAIL] MockEcho files found:\n$mockecho_files"
else
    FINDINGS+="\n[54.1 PASS] No MockEcho files"
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUB-CHECK 54.2: No mock-mcp-server.php
# ═══════════════════════════════════════════════════════════════════════════
if [[ -f "scripts/mock-mcp-server.php" ]]; then
    ERRORS=$((ERRORS + 1))
    FINDINGS+="\n[54.2 FAIL] scripts/mock-mcp-server.php exists"
else
    FINDINGS+="\n[54.2 PASS] No scripts/mock-mcp-server.php"
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUB-CHECK 54.3: No MockEcho in registry
# ═══════════════════════════════════════════════════════════════════════════
if [[ -f ".brain-config/mcp-registry.json" ]]; then
    if grep -qi "mock-echo\|MockEcho" .brain-config/mcp-registry.json 2>/dev/null; then
        ERRORS=$((ERRORS + 1))
        FINDINGS+="\n[54.3 FAIL] MockEcho found in mcp-registry.json"
    else
        FINDINGS+="\n[54.3 PASS] No MockEcho in mcp-registry.json"
    fi
else
    FINDINGS+="\n[54.3 PASS] mcp-registry.json not found (OK)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUB-CHECK 54.4: No MockEcho in agent-schema.json
# ═══════════════════════════════════════════════════════════════════════════
if [[ -f "agent-schema.json" ]]; then
    if grep -qi "MockEcho" agent-schema.json 2>/dev/null; then
        ERRORS=$((ERRORS + 1))
        FINDINGS+="\n[54.4 FAIL] MockEcho found in agent-schema.json"
    else
        FINDINGS+="\n[54.4 PASS] No MockEcho in agent-schema.json"
    fi
else
    FINDINGS+="\n[54.4 PASS] agent-schema.json not found (OK)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUB-CHECK 54.5: No "server start/stop/status" COMMANDS terminology
# ═══════════════════════════════════════════════════════════════════════════
# Note: mcp:list/describe/call are LEGITIMATE commands for external MCP servers
# We only check for brain mcp:start/stop/status which would suggest daemon mode.
server_commands=$(grep -rE "brain mcp:(start|stop|status)" .docs/ 2>/dev/null | head -5 || true)
if [[ -n "$server_commands" ]]; then
    ERRORS=$((ERRORS + 1))
    FINDINGS+="\n[54.5 FAIL] brain mcp:start/stop/status commands found:\n$server_commands"
else
    FINDINGS+="\n[54.5 PASS] No brain mcp:start/stop/status commands"
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUB-CHECK 54.6: mcp:serve command registered
# ═══════════════════════════════════════════════════════════════════════════
# Note: tools:* wrapper commands were removed - brain-tools uses mcp:serve only
mcp_serve=$(php cli/bin/brain list 2>/dev/null | grep -E "^  mcp:serve" | wc -l | tr -d ' ')
if [[ "$mcp_serve" -lt 1 ]]; then
    ERRORS=$((ERRORS + 1))
    FINDINGS+="\n[54.6 FAIL] Expected mcp:serve command, found: $mcp_serve"
else
    FINDINGS+="\n[54.6 PASS] Found mcp:serve command"
fi

# ═══════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════
echo -e "$FINDINGS"

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "[FAIL] Check 54: $ERRORS sub-check(s) failed"
    exit 1
else
    echo ""
    echo "[PASS] Check 54: No user MCP artifacts (6/6)"
    exit 0
fi
