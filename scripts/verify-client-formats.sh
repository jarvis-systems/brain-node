#!/usr/bin/env bash
#
# Client Format Drift Detection — Verifies compiled artifacts match expected formats
# Usage: scripts/verify-client-formats.sh
#
# Checks command file extensions, agent YAML front matter, and format consistency
# across all compile targets. Detects format drift before it breaks client UX.
#
# ENHANCED: Per-client required key validation, OpenCode model alias map, skill key checks
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

# ═══════════════════════════════════════════════════════════════════════════
# OPENCODE MODEL ALIAS MAP
# ═══════════════════════════════════════════════════════════════════════════
# Known model aliases that are ALLOWED without "/" prefix
# These are short aliases that OpenCode resolves to full provider/model IDs
# Format: newline-separated list for grep matching
OPENCODE_MODEL_ALIASES="sonnet
sonnet-4
opus
opus-4
haiku
gpt-4o
gpt-4
gpt-4-turbo
gpt-3.5-turbo
o1
o1-mini
o1-preview
claude-3-5-sonnet
claude-3-opus
claude-3-haiku"

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

# ═══════════════════════════════════════════════════════════════════════════
# ENHANCED: YAML REQUIRED KEYS VALIDATION
# ═══════════════════════════════════════════════════════════════════════════

# ── Check: YAML front matter contains required keys ─────────────────────────
# Usage: check_yaml_required_keys <dir> <label> <required_keys...>
# Example: check_yaml_required_keys ".claude/agents" "claude agents keys" "name" "description"
check_yaml_required_keys() {
    local dir="$1" label="$2"
    shift 2
    local required_keys=("$@")
    
    if [ ! -d "$dir" ]; then
        skip "$label — directory missing"
        return
    fi
    
    local total_files=0
    local files_with_errors=0
    
    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        total_files=$((total_files + 1))
        
        # Extract YAML front matter (between --- lines)
        local in_fm=0 fm_content=""
        while IFS= read -r line; do
            if [[ "$line" == "---" ]]; then
                if [ "$in_fm" -eq 1 ]; then
                    break
                fi
                in_fm=1
                continue
            fi
            if [ "$in_fm" -eq 1 ]; then
                fm_content+="$line"$'\n'
            fi
        done < "$f"
        
        if [ -z "$fm_content" ]; then
            fail "$label — $(basename "$f") has no YAML front matter"
            files_with_errors=$((files_with_errors + 1))
            continue
        fi
        
        # Check each required key
        local missing_keys=()
        for key in "${required_keys[@]}"; do
            # Match: "key:" at start of line (with optional whitespace)
            if ! echo "$fm_content" | grep -qE "^[[:space:]]*${key}[[:space:]]*:"; then
                missing_keys+=("$key")
            fi
        done
        
        if [ ${#missing_keys[@]} -gt 0 ]; then
            fail "$label — $(basename "$f") missing required keys: ${missing_keys[*]}"
            files_with_errors=$((files_with_errors + 1))
        fi
    done
    
    if [ "$files_with_errors" -eq 0 ] && [ "$total_files" -gt 0 ]; then
        pass "$label — $total_files file(s) have all required keys (${required_keys[*]})"
    elif [ "$total_files" -eq 0 ]; then
        skip "$label — no .md files found"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ENHANCED: OPENCODE MODEL ID STRICTNESS
# ═══════════════════════════════════════════════════════════════════════════

# ── Check: OpenCode model IDs are either provider/model OR known alias ──────
# Usage: check_opencode_model_strict <dir> <label>
# Validates model field: must contain "/" OR be in OPENCODE_MODEL_ALIASES map
check_opencode_model_strict() {
    local dir="$1" label="$2"
    if [ ! -d "$dir" ]; then
        skip "$label — directory missing"
        return
    fi
    
    local bad_count=0
    local total_count=0
    local alias_count=0
    
    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        
        # Extract model value from YAML front matter
        local model_line model_value
        model_line=$(grep -E '^[[:space:]]*model[[:space:]]*:' "$f" 2>/dev/null | head -1) || true
        if [ -z "$model_line" ]; then
            continue
        fi
        
        total_count=$((total_count + 1))
        
        # Extract value: strip key, whitespace, and quotes
        model_value=$(echo "$model_line" | sed -E 's/^[[:space:]]*model[[:space:]]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//" | sed 's/\\//g')
        
        # Check: contains "/" OR is a known alias
        if [[ "$model_value" == *"/"* ]]; then
            : # Valid provider/model format
        elif echo "$OPENCODE_MODEL_ALIASES" | grep -qxF "$model_value"; then
            alias_count=$((alias_count + 1))
            : # Valid alias
        else
            fail "$label — $(basename "$f") has invalid model ID: \"$model_value\" (expected provider/model format or known alias)"
            bad_count=$((bad_count + 1))
        fi
    done
    
    if [ "$bad_count" -eq 0 ] && [ "$total_count" -gt 0 ]; then
        local msg="$label — $total_count model(s) valid"
        [ "$alias_count" -gt 0 ] && msg+=" ($alias_count using aliases)"
        pass "$msg"
    elif [ "$bad_count" -eq 0 ] && [ "$total_count" -eq 0 ]; then
        pass "$label — no model fields found (ok)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ENHANCED: COMMANDS FORMAT DRIFT DETECTION
# ═══════════════════════════════════════════════════════════════════════════

# ── Check: commands directory has ONLY expected format (strict) ─────────────
# Usage: check_commands_format_strict <dir> <expected_ext> <banned_ext> <client>
# Fails if ANY file has wrong extension, not just if banned files exist
check_commands_format_strict() {
    local dir="$1" expected_ext="$2" banned_ext="$3" client="$4"
    
    if [ ! -d "$dir" ]; then
        skip "$client commands — directory missing"
        return
    fi
    
    local expected_count banned_count total_count
    expected_count=$(find "$dir" -maxdepth 1 -name "*.$expected_ext" 2>/dev/null | wc -l | tr -d ' ')
    banned_count=$(find "$dir" -maxdepth 1 -name "*.$banned_ext" 2>/dev/null | wc -l | tr -d ' ')
    total_count=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$banned_count" -gt 0 ]; then
        local bad_files
        bad_files=$(find "$dir" -maxdepth 1 -name "*.$banned_ext" -exec basename {} \; 2>/dev/null | tr '\n' ' ')
        fail "$client commands — wrong format: found .$banned_ext files: $bad_files (expected .$expected_ext)"
    elif [ "$expected_count" -gt 0 ]; then
        pass "$client commands — correct .$expected_ext format ($expected_count files)"
    elif [ "$total_count" -eq 0 ]; then
        skip "$client commands — directory empty"
    else
        fail "$client commands — no .$expected_ext files found (expected .$expected_ext format)"
    fi
}

# ── Check: model IDs in compiled artifacts contain "/" (full provider/model format)
# Usage: check_model_ids_have_slash <dir> <label>
# Enforces enterprise strictness: model IDs must be provider-prefixed (e.g., "anthropic/claude-sonnet-4-5")
# Bare aliases like "sonnet" or "gpt-4o" are rejected.
check_model_ids_have_slash() {
    local dir="$1" label="$2"
    if [ ! -d "$dir" ]; then
        skip "$label — directory missing"
        return
    fi
    local bad_count=0
    local total_count=0
    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        # Extract model value from YAML front matter
        # Handles: model: "value" (with possible escaped slashes \/)
        local model_line
        model_line=$(grep '^model:' "$f" 2>/dev/null | head -1) || true
        if [ -z "$model_line" ]; then
            # No model field - skip (not all artifacts need model)
            continue
        fi
        total_count=$((total_count + 1))
        # Extract the value after "model:" - strip leading/trailing whitespace and quotes
        local model_value
        model_value=$(echo "$model_line" | sed 's/^model:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//" | sed 's/\\//g')
        # Check: must contain "/" (after unescaping)
        if [[ "$model_value" != *"/"* ]]; then
            fail "$label — $(basename "$f") has bare model ID: \"$model_value\" (expected provider/model format)"
            bad_count=$((bad_count + 1))
        fi
    done
    if [ "$bad_count" -eq 0 ] && [ "$total_count" -gt 0 ]; then
        pass "$label — $total_count model(s) have valid provider/model format"
    elif [ "$bad_count" -eq 0 ] && [ "$total_count" -eq 0 ]; then
        pass "$label — no model fields found (ok)"
    fi
}

# ── Check: agent-schema.json model IDs match canonical list ────────────────
# Usage: check_schema_model_ids_canonical
# Validates that model IDs in agent-schema.json don't contain known-wrong patterns.
# Focus: catches drift like "glm-5.0" vs canonical "glm-5".
check_schema_model_ids_canonical() {
    local schema="$PROJECT_ROOT/agent-schema.json"
    if [ ! -f "$schema" ]; then
        skip "schema model IDs — agent-schema.json not found"
        return
    fi
    
    local bad_count=0
    
    # Known-wrong model ID patterns (add more as discovered)
    # Format: "wrong_pattern" -> canonical is "correct_pattern"
    local wrong_patterns=(
        "zai-coding-plan/glm-5.0"
    )
    local correct_patterns=(
        "zai-coding-plan/glm-5"
    )
    
    local i=0
    for wrong in "${wrong_patterns[@]}"; do
        if grep -qF "\"$wrong\"" "$schema" 2>/dev/null; then
            fail "schema has non-canonical model ID: \"$wrong\" (should be \"${correct_patterns[$i]}\")"
            bad_count=$((bad_count + 1))
        fi
        i=$((i + 1))
    done
    
    if [ "$bad_count" -eq 0 ]; then
        pass "schema model IDs pass canonical check (${#wrong_patterns[@]} patterns checked)"
    fi
}

# ── Check: OpenCode settings.json exists and is valid JSON ──────────────────
# Usage: check_opencode_settings
# OpenCode requires settings.json for MCP and model configuration.
check_opencode_settings() {
    local settings="$PROJECT_ROOT/.opencode/settings.json"
    if [ ! -f "$settings" ]; then
        fail "opencode settings.json missing (.opencode/settings.json)"
        return
    fi
    if ! python3 -c "import json; json.load(open('$settings'))" 2>/dev/null; then
        fail "opencode settings.json is not valid JSON"
        return
    fi
    pass "opencode settings.json exists and is valid JSON"
}

# ── Check: client skills directory exists if agents exist ───────────────────
# Usage: check_skills_dir_if_agents <client_name> <agents_dir> <skills_dir>
# Skills are required for full client compatibility.
check_skills_dir_if_agents() {
    local client="$1" agents_dir="$2" skills_dir="$3"
    if [ ! -d "$agents_dir" ]; then
        return
    fi
    local agent_count
    agent_count=$(find "$agents_dir" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$agent_count" -eq 0 ]; then
        return
    fi
    if [ ! -d "$skills_dir" ]; then
        fail "$client skills directory missing ($skills_dir) — agents exist but no skills dir"
        return
    fi
    local skill_count
    skill_count=$(find "$skills_dir" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$skill_count" -eq 0 ]; then
        fail "$client skills directory empty ($skills_dir) — expected at least one skill"
        return
    fi
    pass "$client skills directory exists with $skill_count file(s)"
}

echo "=========================================="
echo "Client Format Drift Detection"
echo "=========================================="
echo ""

# ── Claude ───────────────────────────────────────────────────────────────
echo -e "${YELLOW}Claude${NC}"
check_commands_format_strict "$PROJECT_ROOT/.claude/commands" "md" "toml" "claude"
check_has_ext "$PROJECT_ROOT/.claude/agents" "md" "claude agents are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.claude/agents" "claude agents YAML front matter"
check_yaml_required_keys "$PROJECT_ROOT/.claude/agents" "claude agents required keys" "name" "description"
check_has_ext "$PROJECT_ROOT/.claude/skills" "md" "claude skills are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.claude/skills" "claude skills YAML front matter"
check_yaml_required_keys "$PROJECT_ROOT/.claude/skills" "claude skills required keys" "name" "description"
echo ""

# ── Qwen ─────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Qwen${NC}"
check_commands_format_strict "$PROJECT_ROOT/.qwen/commands" "toml" "md" "qwen"
check_has_ext "$PROJECT_ROOT/.qwen/agents" "md" "qwen agents are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.qwen/agents" "qwen agents YAML front matter"
check_yaml_required_keys "$PROJECT_ROOT/.qwen/agents" "qwen agents required keys" "name" "description"
check_has_ext "$PROJECT_ROOT/.qwen/skills" "md" "qwen skills are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.qwen/skills" "qwen skills YAML front matter"
check_yaml_required_keys "$PROJECT_ROOT/.qwen/skills" "qwen skills required keys" "name" "description"
echo ""

# ── Gemini ───────────────────────────────────────────────────────────────
echo -e "${YELLOW}Gemini${NC}"
check_commands_format_strict "$PROJECT_ROOT/.gemini/commands" "toml" "md" "gemini"
check_has_ext "$PROJECT_ROOT/.gemini/agents" "md" "gemini agents are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.gemini/agents" "gemini agents YAML front matter"
check_yaml_required_keys "$PROJECT_ROOT/.gemini/agents" "gemini agents required keys" "name" "description"
check_has_ext "$PROJECT_ROOT/.gemini/skills" "md" "gemini skills are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.gemini/skills" "gemini skills YAML front matter"
check_yaml_required_keys "$PROJECT_ROOT/.gemini/skills" "gemini skills required keys" "name" "description"
echo ""

# ── OpenCode ─────────────────────────────────────────────────────────────
echo -e "${YELLOW}OpenCode${NC}"
# OpenCode uses singular dir names (builder convention)
OC_CMD="$PROJECT_ROOT/.opencode/command"
OC_AGT="$PROJECT_ROOT/.opencode/agent"
# Also check plural (official docs convention) if singular missing
[ -d "$OC_CMD" ] || OC_CMD="$PROJECT_ROOT/.opencode/commands"
[ -d "$OC_AGT" ] || OC_AGT="$PROJECT_ROOT/.opencode/agents"
check_commands_format_strict "$OC_CMD" "md" "toml" "opencode"
check_has_ext "$OC_AGT" "md" "opencode agents are .md"
check_yaml_frontmatter "$OC_AGT" "opencode agents YAML front matter"
check_yaml_required_keys "$OC_AGT" "opencode agents required keys" "name" "description" "model"
check_opencode_model_strict "$OC_AGT" "opencode agents model IDs"
check_has_ext "$PROJECT_ROOT/.opencode/skills" "md" "opencode skills are .md"
check_yaml_frontmatter "$PROJECT_ROOT/.opencode/skills" "opencode skills YAML front matter"
check_yaml_required_keys "$PROJECT_ROOT/.opencode/skills" "opencode skills required keys" "name" "description"
echo ""

# ── Schema ─────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Schema${NC}"
check_schema_model_ids_canonical
echo ""

# ── OpenCode Settings ──────────────────────────────────────────────────────
echo -e "${YELLOW}OpenCode Config${NC}"
check_opencode_settings
echo ""

# ── Cross-Client Skills Integrity ──────────────────────────────────────────
echo -e "${YELLOW}Skills Integrity${NC}"
check_skills_dir_if_agents "claude" "$PROJECT_ROOT/.claude/agents" "$PROJECT_ROOT/.claude/skills"
check_skills_dir_if_agents "qwen" "$PROJECT_ROOT/.qwen/agents" "$PROJECT_ROOT/.qwen/skills"
check_skills_dir_if_agents "gemini" "$PROJECT_ROOT/.gemini/agents" "$PROJECT_ROOT/.gemini/skills"
check_skills_dir_if_agents "opencode" "$OC_AGT" "$PROJECT_ROOT/.opencode/skills"
echo ""

# ── Codex ────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Codex${NC}"
if [ -d "$PROJECT_ROOT/.codex/prompts" ]; then
    check_commands_format_strict "$PROJECT_ROOT/.codex/prompts" "md" "toml" "codex prompts"
else
    skip "codex prompts — .codex/prompts/ not found"
fi
# Codex skills use subdirectory format: .agents/skills/<name>/SKILL.md
if [ -d "$PROJECT_ROOT/.agents/skills" ]; then
    CODEX_SKILL_COUNT=$(find "$PROJECT_ROOT/.agents/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CODEX_SKILL_COUNT" -gt 0 ]; then
        pass "codex skills have SKILL.md ($CODEX_SKILL_COUNT files)"
        # Check each SKILL.md has required YAML front matter keys
        skill_errors=0
        while IFS= read -r skill_file; do
            [ -f "$skill_file" ] || continue
            # Extract YAML front matter content
            in_fm=0 fm_content=""
            while IFS= read -r line; do
                if [[ "$line" == "---" ]]; then
                    if [ "$in_fm" -eq 1 ]; then
                        break
                    fi
                    in_fm=1
                    continue
                fi
                if [ "$in_fm" -eq 1 ]; then
                    fm_content+="$line"$'\n'
                fi
            done < "$skill_file"
            
            skill_name=$(dirname "$skill_file" | xargs basename)
            
            if [ -z "$fm_content" ]; then
                fail "codex skill $skill_name — SKILL.md missing YAML front matter"
                skill_errors=$((skill_errors + 1))
                continue
            fi
            
            # Check required keys: name, description
            missing=()
            for key in name description; do
                if ! echo "$fm_content" | grep -qE "^[[:space:]]*${key}[[:space:]]*:"; then
                    missing+=("$key")
                fi
            done
            
            if [ ${#missing[@]} -gt 0 ]; then
                fail "codex skill $skill_name — missing keys: ${missing[*]}"
                skill_errors=$((skill_errors + 1))
            fi
        done < <(find "$PROJECT_ROOT/.agents/skills" -name "SKILL.md" 2>/dev/null)
        
        if [ "$skill_errors" -eq 0 ]; then
            pass "codex skills required keys — all $CODEX_SKILL_COUNT skill(s) have name + description"
        fi
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
