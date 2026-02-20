# Phase 2: WebRecursiveResearchInclude Gating — VERIFICATION

---
date: "2026-02-20"
---

## Automated

```bash
bash scripts/verify-compile-metrics.sh
# Expected: 15/15 PASS
```

## Manual

### Compile standard and check agent size

```bash
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
wc -l .claude/agents/web-research-master.md
# Expected: 282
```

### Leakage proof (standard)

```bash
# Detailed phases should be absent
grep -c 'Formulate and execute initial web search' .claude/agents/web-research-master.md
# Expected: 0

# Compact workflow should be present
grep -c 'Research execution flow' .claude/agents/web-research-master.md
# Expected: 1

# Source priority should be present
grep -c 'Source selection priority' .claude/agents/web-research-master.md
# Expected: 1
```

### Exhaustive proof

```bash
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile
wc -l .claude/agents/web-research-master.md
# Expected: 406

grep -c 'Formulate and execute initial web search' .claude/agents/web-research-master.md
# Expected: 1 (phases present in exhaustive)
```

### Full test suite

```bash
bash scripts/lint-mcp-syntax.sh
# Expected: PASSED

cd core && ./vendor/bin/phpunit tests/McpSchemaValidatorTest.php
# Expected: OK (10 tests, 16 assertions)
```
