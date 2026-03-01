#!/usr/bin/env bash
#
# Check 46: MCP Thin Adapter Lock
# Enforces invariants that prevent drift from "thin adapter" design
#
# FAIL if:
#   A) FORBIDDEN brain-tools wrapper commands exist (McpDocsSearchCommand, McpDiagnoseCommand, McpListMastersCommand)
#   B) shell_exec/exec/proc_open/passthru/system in McpServeCommand.php
#   C) Direct filesystem scanning in McpServeCommand.php (RecursiveDirectoryIterator, glob, scandir)
#   D) Daemon/supervisor docs outside NON-GOALS sections

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

ERRORS=0
ERROR_DETAILS=""

# A) Forbidden brain-tools wrapper commands
# NOTE: mcp:list, mcp:call, mcp:describe are for EXTERNAL MCP servers - NOT forbidden
FORBIDDEN_WRAPPERS=(
    "McpDocsSearchCommand.php"
    "McpDiagnoseCommand.php"
    "McpListMastersCommand.php"
)

for wrapper in "${FORBIDDEN_WRAPPERS[@]}"; do
    if [[ -f "cli/src/Console/Commands/$wrapper" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS+="\n[A] FORBIDDEN wrapper: cli/src/Console/Commands/$wrapper"
    fi
done

# B) Shell execution in McpServeCommand.php
MCP_SERVE="cli/src/Console/Commands/McpServeCommand.php"
if [[ -f "$MCP_SERVE" ]]; then
    SHELL_MATCH=$(grep -n -E '\bshell_exec\b|\bexec\s*\(|\bproc_open\b|\bpassthru\b|\bsystem\s*\(' "$MCP_SERVE" 2>/dev/null || true)
    if [[ -n "$SHELL_MATCH" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS+="\n[B] Shell call in $MCP_SERVE:"
        ERROR_DETAILS+="\n$SHELL_MATCH"
    fi
else
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS+="\n[B] MISSING: $MCP_SERVE"
fi

# C) Direct filesystem scanning in McpServeCommand.php
if [[ -f "$MCP_SERVE" ]]; then
    FS_SCAN_MATCH=$(grep -n -E 'RecursiveDirectoryIterator|RecursiveIteratorIterator|\\glob\s*\(|scandir\s*\(' "$MCP_SERVE" 2>/dev/null || true)
    if [[ -n "$FS_SCAN_MATCH" ]]; then
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS+="\n[C] Filesystem scan in $MCP_SERVE:"
        ERROR_DETAILS+="\n$FS_SCAN_MATCH"
    fi
fi

# D) Daemon/supervisor docs outside NON-GOALS
# Only check architecture docs for daemon language outside explicit NON-GOALS
DAEMON_PATTERN='(daemon|supervisor|start.*mcp|stop.*mcp|mcp.*status|background.*server)'
NON_GOALS_PATTERN='(Non-goals|NON-GOALS|Out of scope)'

check_daemon_docs() {
    local file="$1"
    local in_non_goals=0
    local line_num=0
    local found_issues=""
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))
        
        # Track NON-GOALS section boundaries
        if echo "$line" | grep -qiE "$NON_GOALS_PATTERN"; then
            in_non_goals=1
        fi
        
        # Reset on next major section (## heading)
        if [[ "$line" =~ ^##[[:space:]] && $in_non_goals -eq 1 ]]; then
            if ! echo "$line" | grep -qiE "$NON_GOALS_PATTERN"; then
                in_non_goals=0
            fi
        fi
        
        # Check for daemon language only outside NON-GOALS
        if [[ $in_non_goals -eq 0 ]]; then
            if echo "$line" | grep -qiE "$DAEMON_PATTERN"; then
                # Exclude negative patterns (describing what NOT to do)
                NEGATIVE_PATTERNS='(without.*daemon|no.*daemon|not.*daemon|no.*supervisor|no.*start|no.*stop|no.*status|no.*background|single.*request|ephemeral|kill.?switch|global.*status)'
                if ! echo "$line" | grep -qiE "$NEGATIVE_PATTERNS"; then
                    found_issues+="\n  $file:$line_num: $line"
                fi
            fi
        fi
    done < "$file"
    
    echo "$found_issues"
}

DAEMON_ISSUES=""
for doc in .docs/architecture/mcp-*.md; do
    if [[ -f "$doc" ]]; then
        ISSUES=$(check_daemon_docs "$doc")
        if [[ -n "$ISSUES" ]]; then
            DAEMON_ISSUES+="$ISSUES"
        fi
    fi
done

if [[ -n "$DAEMON_ISSUES" ]]; then
    ERRORS=$((ERRORS + 1))
    ERROR_DETAILS+="\n[D] Daemon/supervisor refs outside NON-GOALS:$DAEMON_ISSUES"
fi

# Report
if [[ $ERRORS -gt 0 ]]; then
    echo "[FAIL] Check 46: MCP Thin Adapter Lock ($ERRORS violation(s))"
    echo -e "$ERROR_DETAILS"
    exit 1
fi

echo "[PASS] Check 46: MCP Thin Adapter Lock"
exit 0
