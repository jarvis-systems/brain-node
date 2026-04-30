---
name: "Enterprise Prompt Architecture — Verification Commands"
description: "Verification commands and procedures for enterprise prompt architecture audit"
date: "2026-02-20"
---

# Enterprise Prompt Architecture — Verification Commands

## Automated Verification (single command)

```bash
bash scripts/verify-compile-metrics.sh
```

Expected: 15/15 PASS, standard <= 400, exhaustive > 700.

## Manual Verification Steps

### 1. Compile standard and check line count

```bash
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
wc -l .claude/CLAUDE.md
# Expected: ~362
```

### 2. Verify gated content absent in standard

```bash
# Phase 1 gating
grep -ciE 'Level brain|Level architect|Level specialist|Level tool' .claude/CLAUDE.md
# Expected: 0

grep -ciE 'Error delegation failed|Error agent timeout|Error invalid response|Error context loss|Error resource exceeded' .claude/CLAUDE.md
# Expected: 0

grep -ciE 'Validation semantic|Validation structural|Validation policy|Validation actions' .claude/CLAUDE.md
# Expected: 0

# Phase 1b gating (agents)
grep -c 'Decompose task into objectives' .claude/agents/explore.md
# Expected: 0

grep -c 'Strict sequential execution' .claude/agents/explore.md
# Expected: 1 (always-on phase-flow)
```

### 3. Verify always-on content present in standard

```bash
grep -ciE 'Delegation-limit|Escalation policy|Exploration delegation' .claude/CLAUDE.md
# Expected: > 0

grep -c 'Cookbook calls ONLY via' .claude/CLAUDE.md
# Expected: > 0

grep -ciE 'Gate 5.*compile-time preset|NOT a runtime uncertainty trigger' .claude/CLAUDE.md
# Expected: > 0
```

### 4. Verify no uncertainty triggers

```bash
grep -ciE 'Trigger.*Uncertainty|when uncertain.*cookbook|before assuming.*cookbook' .claude/CLAUDE.md
# Expected: 0
```

### 5. Compile exhaustive and verify gated content present

```bash
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile
wc -l .claude/CLAUDE.md
# Expected: ~756

grep -ciE 'Level brain|Level architect' .claude/CLAUDE.md
# Expected: > 0

grep -c 'Decompose task into objectives' .claude/agents/explore.md
# Expected: > 0
```

### 6. Restore standard

```bash
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
```

### 7. Lint and tests

```bash
bash scripts/lint-mcp-syntax.sh
# Expected: PASSED

cd core && ./vendor/bin/phpunit tests/McpSchemaValidatorTest.php
# Expected: OK (10 tests, 16 assertions)
```

### 8. Agent line counts (standard)

```bash
wc -l .claude/agents/*.md
# Expected:
#   275 documentation-master.md
#   318 explore.md
#   247 vector-master.md
#   340 web-research-master.md
#  1490 total
```
