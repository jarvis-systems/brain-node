#!/usr/bin/env bash
#
# Check 52: MCP No External Surface
# Validates that brain-tools (internal MCP) has NO external surface references.
#
# brain-tools uses ONLY: mcp:serve
# External MCP servers (context7, vector-memory) use: mcp:list, mcp:describe, mcp:call
#
# This check ensures:
# 1. No client code references mcp:list/describe/call for brain-tools
# 2. No shadow wrapper commands (mcp:docs_search, mcp:diagnose, mcp:list-masters)
# 3. No shell execution in brain-tools serve path
# 4. Documentation clearly separates internal vs external MCP surfaces
#
# Forbidden patterns in CLIENT code (cli/src/Services/Clients/, cli/src/Services/Mcp/):
#   - "mcp:list", "mcp:describe", "mcp:call" (unless in error hints for external MCP)
#   - "mcp-registry" references for brain-tools
#
# Forbidden files:
#   - cli/src/Console/Commands/McpDocsSearchCommand.php
#   - cli/src/Console/Commands/McpDiagnoseCommand.php
#   - cli/src/Console/Commands/McpListMastersCommand.php
#
# Allowlist:
#   - Error hints mentioning mcp:list/describe/call for EXTERNAL MCP servers
#   - Documentation in .docs/ that clearly marks NON-GOALS or external server docs
#

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

ERRORS=0
ERROR_DETAILS=""

# ── Check A: No shadow wrapper commands ───────────────────────────────────

FORBIDDEN_COMMANDS=(
    "cli/src/Console/Commands/McpDocsSearchCommand.php"
    "cli/src/Console/Commands/McpDiagnoseCommand.php"
    "cli/src/Console/Commands/McpListMastersCommand.php"
)

for file in "${FORBIDDEN_COMMANDS[@]}"; do
    if [[ -f "$PROJECT_ROOT/$file" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[A] FORBIDDEN FILE: $file exists (shadow wrapper command)"
    fi
done

# ── Check B: BrainMcpBridge only spawns mcp:serve ───────────────────────────

BRIDGE_FILE="$PROJECT_ROOT/cli/src/Services/Mcp/BrainMcpBridge.php"
if [[ -f "$BRIDGE_FILE" ]]; then
    # Check that it contains 'mcp:serve'
    if ! grep -q "'mcp:serve'" "$BRIDGE_FILE" 2>/dev/null; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[B] BrainMcpBridge missing 'mcp:serve' - may be using wrong entrypoint"
    fi

    # Check that it does NOT contain mcp:list, mcp:describe, mcp:call as commands
    if grep -qE "mcp:(list|describe|call)" "$BRIDGE_FILE" 2>/dev/null; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[B] BrainMcpBridge contains forbidden mcp:list/describe/call references"
    fi
fi

# ── Check C: ClientToolingRouter only uses BrainMcpBridge ──────────────────

ROUTER_FILE="$PROJECT_ROOT/cli/src/Services/Mcp/ClientToolingRouter.php"
if [[ -f "$ROUTER_FILE" ]]; then
    # Check that it does NOT spawn processes directly
    if grep -qE "shell_exec|proc_open|exec\s*\(" "$ROUTER_FILE" 2>/dev/null; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[C] ClientToolingRouter contains shell execution (must use BrainMcpBridge only)"
    fi
fi

# ── Check D: No mcp:list/describe/call in client wiring ─────────────────────

# Check that client classes don't reference mcp:list/describe/call
while IFS=: read -r file line content; do
    [[ -z "$file" ]] && continue
    relative="${file#$PROJECT_ROOT/}"
    # Skip error hints (lines containing "Run: brain mcp:")
    if [[ "$content" == *"Run: brain mcp:"* ]]; then
        continue
    fi
    # Skip comments
    trimmed="${content#"${content%%[![:space:]]*}"}"
    [[ "$trimmed" == //* ]] && continue
    [[ "$trimmed" == \* ]] && continue
    [[ "$trimmed" == \*\** ]] && continue

    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS="${ERROR_DETAILS}
[D] $relative:$line contains mcp:list/describe/call in client code"
done < <(grep -rn "mcp:list\|mcp:describe\|mcp:call" "$PROJECT_ROOT/cli/src/Services/Clients" "$PROJECT_ROOT/cli/src/Services/Mcp" --include='*.php' 2>/dev/null || true)

# ── Check E: No shell execution in McpServeCommand ─────────────────────────

SERVE_FILE="$PROJECT_ROOT/cli/src/Console/Commands/McpServeCommand.php"
if [[ -f "$SERVE_FILE" ]]; then
    if grep -qE "shell_exec|proc_open|exec\s*\(" "$SERVE_FILE" 2>/dev/null; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[E] McpServeCommand contains shell execution (must use in-process dispatch)"
    fi
fi

# ── Check F: Documentation clearly separates internal vs external ───────────

MCP_DOCS="$PROJECT_ROOT/.docs/architecture/mcp-stdio-adapter.md"
if [[ -f "$MCP_DOCS" ]]; then
    # Check that docs mention ONLY mcp:serve for brain-tools
    if ! grep -q "mcp:serve is the only entrypoint" "$MCP_DOCS" 2>/dev/null; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS="${ERROR_DETAILS}
[F] mcp-stdio-adapter.md missing 'only entrypoint' language"
    fi
fi

# ── Report ───────────────────────────────────────────────────────────────

if [[ $ERRORS -gt 0 ]]; then
    echo -e "[FAIL] Check 52: MCP No External Surface ($ERRORS violation(s))"
    echo -e "$ERROR_DETAILS"
    exit 1
fi

echo "[PASS] Check 52: MCP No External Surface"
exit 0
