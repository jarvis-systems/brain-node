#!/usr/bin/env bash
#
# Client Format Drift Detection — Verifies compiled artifacts match expected formats
# Usage: scripts/verify-client-formats.sh
#
# Checks command file extensions, agent YAML front matter, and format consistency
# across all compile targets. Detects format drift before it breaks client UX.
#
# Exit codes:
#   0 - All checks passed
#   1 - Format drift detected
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ERRORS=$((ERRORS + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

# ── Check: no wrong-format files in a directory ──────────────────────────
# Usage: check_no_ext <dir> <banned_ext> <label>
check_no_ext() {
    local dir="$1" ext="$2" label="$3"
    if [ ! -d "$dir" ]; then
        skip "$label — directory missing"
        return
    fi
    local bad
    bad=$(find "$dir" -maxdepth 1 -name "*.$ext" 2>/dev/null | head -1)
    if [ -n "$bad" ]; then
        fail "$label — found .$ext files (expected none): $(basename "$bad")"
    else
        pass "$label"
    fi
}

# ── Check: directory has files of expected extension ─────────────────────
# Usage: check_has_ext <dir> <expected_ext> <label>
check_has_ext() {
    local dir="$1" ext="$2" label="$3"
    if [ ! -d "$dir" ]; then
        skip "$label — directory missing"
        return
    fi
    local count
    count=$(find "$dir" -maxdepth 1 -name "*.$ext" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        pass "$label ($count files)"
    else
        fail "$label — no .$ext files found"
    fi
}

# ── Check: all .md files in a directory start with YAML front matter ─────
# Usage: check_yaml_frontmatter <dir> <label>
check_yaml_frontmatter() {
    local dir="$1" label="$2"
    if [ ! -d "$dir" ]; then
        skip "$label — directory missing"
        return
    fi
    local bad_files=0
    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        if ! head -1 "$f" | grep -q '^---$'; then
            fail "$label — $(basename "$f") missing YAML front matter"
            bad_files=$((bad_files + 1))
        fi
    done
    if [ "$bad_files" -eq 0 ]; then
        pass "$label"
    fi
}

echo "=========================================="
echo "Client Format Drift Detection"
echo "=========================================="
echo ""

# ── Claude ───────────────────────────────────────────────────────────────
echo -e "${YELLOW}Claude${NC}"
check_has_ext "$PROJECT_ROOT/.claude/commands" "md" "claude commands are .md"
check_no_ext "$PROJECT_ROOT/.claude/commands" "toml" "claude commands have no .toml"
check_has_ext "$PROJECT_ROOT/.claude/agents" "md" "claude agents are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.claude/agents" "claude agents have YAML front matter"
check_has_ext "$PROJECT_ROOT/.claude/skills" "md" "claude skills are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.claude/skills" "claude skills have YAML front matter"
echo ""

# ── Qwen ─────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Qwen${NC}"
check_has_ext "$PROJECT_ROOT/.qwen/commands" "toml" "qwen commands are .toml"
check_no_ext "$PROJECT_ROOT/.qwen/commands" "md" "qwen commands have no .md"
check_has_ext "$PROJECT_ROOT/.qwen/agents" "md" "qwen agents are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.qwen/agents" "qwen agents have YAML front matter"
check_has_ext "$PROJECT_ROOT/.qwen/skills" "md" "qwen skills are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.qwen/skills" "qwen skills have YAML front matter"
echo ""

# ── Gemini ───────────────────────────────────────────────────────────────
echo -e "${YELLOW}Gemini${NC}"
check_has_ext "$PROJECT_ROOT/.gemini/commands" "toml" "gemini commands are .toml"
check_no_ext "$PROJECT_ROOT/.gemini/commands" "md" "gemini commands have no .md"
check_has_ext "$PROJECT_ROOT/.gemini/agents" "md" "gemini agents are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.gemini/agents" "gemini agents have YAML front matter"
check_has_ext "$PROJECT_ROOT/.gemini/skills" "md" "gemini skills are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.gemini/skills" "gemini skills have YAML front matter"
echo ""

# ── OpenCode ─────────────────────────────────────────────────────────────
echo -e "${YELLOW}OpenCode${NC}"
# OpenCode uses singular dir names (builder convention)
OC_CMD="$PROJECT_ROOT/.opencode/command"
OC_AGT="$PROJECT_ROOT/.opencode/agent"
# Also check plural (official docs convention) if singular missing
[ -d "$OC_CMD" ] || OC_CMD="$PROJECT_ROOT/.opencode/commands"
[ -d "$OC_AGT" ] || OC_AGT="$PROJECT_ROOT/.opencode/agents"
check_has_ext "$OC_CMD" "md" "opencode commands are .md"
check_no_ext "$OC_CMD" "toml" "opencode commands have no .toml"
check_has_ext "$OC_AGT" "md" "opencode agents are .md"
check_yaml_frontmatter "$OC_AGT" "opencode agents have YAML front matter"
check_has_ext "$PROJECT_ROOT/.opencode/skills" "md" "opencode skills are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.opencode/skills" "opencode skills have YAML front matter"
echo ""

# ── Codex ────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Codex${NC}"
if [ -d "$PROJECT_ROOT/.codex/prompts" ]; then
    check_has_ext "$PROJECT_ROOT/.codex/prompts" "md" "codex prompts are .md"
    check_no_ext "$PROJECT_ROOT/.codex/prompts" "toml" "codex prompts have no .toml"
else
    skip "codex prompts — .codex/prompts/ not found"
fi
# Codex skills use subdirectory format: .agents/skills/<name>/SKILL.md
if [ -d "$PROJECT_ROOT/.agents/skills" ]; then
    CODEX_SKILL_COUNT=$(find "$PROJECT_ROOT/.agents/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CODEX_SKILL_COUNT" -gt 0 ]; then
        pass "codex skills have SKILL.md ($CODEX_SKILL_COUNT files)"
    else
        fail "codex skills — .agents/skills/ exists but no SKILL.md found"
    fi
else
    skip "codex skills — .agents/skills/ not found"
fi
# Trust stanza: ensures Codex runs non-interactive (no "trust this directory?" prompt)
CODEX_TOML="$PROJECT_ROOT/.codex/config.toml"
if [ -f "$CODEX_TOML" ]; then
    if grep -q 'trust_level\s*=\s*"trusted"' "$CODEX_TOML"; then
        pass "codex config has trust_level = trusted"
    else
        fail "codex config missing trust_level = trusted (interactive prompt risk)"
    fi
else
    fail "codex config.toml missing (.codex/config.toml)"
fi
echo ""

# ── Summary ──────────────────────────────────────────────────────────────
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}FAILED: $ERRORS format drift(s) detected${NC}"
    exit 1
else
    echo -e "${GREEN}PASSED: All client formats correct${NC}"
    exit 0
fi
