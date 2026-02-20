---
name: "MCP JSON Migration RFC"
description: "Canonical JSON format for MCP tool calls with schema validation"
type: "rfc"
version: "1.0.0"
date: "2026-02-19"
status: "approved"
checkpoint: "A"
---

# MCP JSON Migration RFC

## Executive Summary

This RFC establishes **JSON-strict format** as the canonical standard for all MCP tool invocations in the Brain system. The migration addresses three critical issues:

1. **Ambiguity**: Current pseudo-syntax (`'{query: "x"}'`) relies on AI semantic interpretation, not mechanical validation
2. **Reliability**: No schema validation exists, enabling hallucinated parameters
3. **Enterprise readiness**: No audit trail, no replay capability, no mechanical parsing

**Impact**: ~300 MCP calls across 34 files.

---

## Section A: Problem Analysis

### Current State

| Format | Example | Status |
|--------|---------|--------|
| PHP-literal | `mcp__vector-memory__search_memories('{query: "x", limit: 5}')` | Legacy |
| Bracketless | `mcp__vector-memory__search_memories(query: "x", limit: 5)` | Legacy artifact |
| JSON object | `mcp__vector-memory__search_memories({"query":"x","limit":5})` | Target |

### Failure Modes

1. **Nested structures**: `'{filters: {tags: ["a","b"]}}'` — parsing ambiguity
2. **Quote escaping**: `'{content: "He said \"hello\""}'` — breakage risk
3. **Schema violations**: `'{querry: "typo"}'` — silently accepted
4. **Mixed formats**: Inconsistent compiled output

---

## Section B: Proposed Solution

### B.1 New API Methods

**McpArchitecture::callJson()**
```php
public static function callJson(string $method, array $args = []): string
{
    $json = json_encode(
        $args,
        JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
    );
    return static::id() . "__$method($json)";
}
```

**McpSchemaValidator::validate()**
```php
public static function validate(
    string $method,
    array $args,
    array $schema,
    string $mode = 'standard'
): void
{
    // Check required keys
    foreach ($schema['required'] ?? [] as $key) {
        if (!array_key_exists($key, $args)) {
            throw new McpSchemaException("Missing required key: $key");
        }
    }
    
    // Check unknown keys (strict mode only)
    if ($mode === 'strict' || $mode === 'paranoid') {
        $extra = array_diff(array_keys($args), $schema['allowed'] ?? []);
        if (!empty($extra)) {
            throw new McpSchemaException("Unknown keys: " . implode(', ', $extra));
        }
    }
}
```

### B.2 Schema Map Location

Schemas are defined in MCP wrapper classes:

```
VectorMemoryMcp::schema() → returns method schemas
VectorTaskMcp::schema() → returns method schemas
```

**Rationale**: Schema is domain knowledge, not transport logic.

### B.3 Mode Resolution

```
Priority chain:
1. Task tags (strict:paranoid, cognitive:exhaustive)
2. CLI flags (--strict=paranoid)
3. ENV defaults (BRAIN_STRICT_DEFAULT)
4. Hard default (standard)
```

**Implementation**: `Variations/Traits/ModeResolverTrait.php`

---

## Section C: Mode Matrix

| Mode | JSON Format | Schema Validation | Legacy Allowed | Lint Action |
|------|-------------|-------------------|----------------|-------------|
| `minimal` | Legacy OK | None | Yes | Warn |
| `standard` | Legacy OK | Optional | Yes | Warn |
| `strict` | **JSON required** | **Required** | No | **Fail** |
| `paranoid` | **JSON required** | **Required + whitelist** | No | **Fail** |

---

## Section D: Gates-Rules Population

### D.1 MCP-JSON-ONLY Gate [CRITICAL]

```
TRIGGER: strict:strict OR strict:paranoid

RULE:
All MCP tool calls MUST use JSON object payload.
Forbidden: string pseudo-objects, named arguments without braces.

FORMAT:
mcp__{id}__{method}({"key":"value"})  ← REQUIRED
mcp__{id}__{method}('{key: "value"}')  ← FORBIDDEN
mcp__{id}__{method}(key: "value")      ← FORBIDDEN

ON VIOLATION:
Hard-fail with schema error. No fallback.
```

### D.2 Lightweight Lawyer Gate [HIGH]

```
TRIGGER: Before storing ANY proposal to memory

CHECKS:
1. Does NOT violate Iron Rules
2. Has measurable benefit
3. Is reversible
4. Does NOT expand task scope
5. Does NOT weaken security

PASS: 5/5 → store with gate:passed
FAIL: Security → reject/escalate
FAIL: <4/5 → reject with explanation
```

### D.3 Constitutional Learn Protocol [CRITICAL]

```
TRIGGER SIGNALS:
- retries > 0 in task comment
- stuck tag on task
- validation-fix tag
- "BLOCKED:" in comment
- User correction

FORMAT:
store_memory({
    content: "FAILURE: {what}\nROOT CAUSE: {why}\nFIX: {how}\nPREVENTION: {pattern}",
    category: "bug-fix",
    tags: ["type:lesson", "signal:{trigger}", "{domain}"]
})

FORBIDDEN:
- Store without ROOT CAUSE
- Store raw error logs
- Store proposals here (use Suggestion Mode)
```

### D.4 Category Discipline Contract [HIGH]

```
SEPARATION IS MANDATORY:

bug-fix category:
  → type:lesson ONLY (past failures)
  → NEVER type:proposal

architecture category:
  → type:proposal, type:decision ONLY
  → NEVER type:lesson

code-solution category:
  → type:pattern ONLY (working solutions)
  → NEVER type:proposal, NEVER type:lesson
```

### D.5 Cookbook-First Gate [HIGH]

```
TRIGGER:
- strict:strict OR strict:paranoid
- OR ambiguous/complex query
- OR unfamiliar domain

ACTION:
BEFORE significant actions → cookbook(include="cases", case_category="...", priority="critical")

CATEGORIES:
- store → before memory storage
- search → before complex queries
- validation → before quality checks
- gates-rules → when uncertain about protocol
```

### D.6 Failure Escalation Gate [HIGH]

```
TRIGGER: Schema validation error OR tool error OR lint failure

ACTION:
1. DO NOT guess or retry blindly
2. cookbook(include="cases", case_category="essential-patterns,debugging", priority="critical")
3. Extract relevant patterns
4. Apply pattern-specific fix
5. Retry with validated approach

FORBIDDEN:
- Silent retry without pattern lookup
- "Trying something else" without cookbook reference
```

---

## Section E: Lint Patterns

### E.1 Detection Patterns

```regex
# Pattern 1: String pseudo-object
mcp__[a-z-]+__[a-z_]+\('{

# Pattern 2: Named arguments without braces
mcp__[a-z-]+__[a-z_]+\([a-z_]+:\s*[^{]

# Pattern 3: Empty object string
mcp__[a-z-]+__[a-z_]+\('{}'\)
```

### E.2 Lint Implementation

**Script:** `scripts/lint-mcp-syntax.sh`

**Usage:**
```bash
# Warn mode (default)
./scripts/lint-mcp-syntax.sh

# Strict mode (fail on legacy)
./scripts/lint-mcp-syntax.sh --strict
STRICT_MCP_LINT=1 ./scripts/lint-mcp-syntax.sh
```

**Scanned directories:**
- `.opencode/agent/` — Compiled agent instructions
- `.opencode/command/` — Compiled command instructions

**Detection patterns:**
```regex
# Pattern 1: String pseudo-object with single quotes
mcp__[a-z-]+__[a-z_]+\s*\(\s*'{...}'

# Pattern 2: Named arguments without braces  
mcp__[a-z-]+__[a-z_]+\s*\(\s*[a-z_]+\s*:

# Pattern 3: String pseudo-object with double quotes
mcp__[a-z-]+__[a-z_]+\s*\(\s*"{...}"
```

**CI Integration:**
```yaml
# .github/workflows/lint.yml
- name: MCP Syntax Lint
  run: ./scripts/lint-mcp-syntax.sh --strict
  env:
    STRICT: ${{ vars.BRAIN_STRICT }}  # 'strict' or 'paranoid'
```

**Current status:** 34 files with legacy syntax detected (pre-migration baseline)

---

## Section F: Deprecation Timeline

| Phase | Version | Status |
|-------|---------|--------|
| A | 1.0.0 | JSON-strict available, legacy warned |
| B | 1.1.0 | Core includes migrated, cookbook delegation |
| C | 1.2.0 | Commands migrated |
| D | 2.0.0 | Legacy syntax forbidden in strict/paranoid |

---

## Section G: Definition of Done — Checkpoint A

### A.1 Infrastructure (COMPLETED)
- [x] `McpArchitecture::callJson()` with `JSON_THROW_ON_ERROR`
- [x] `McpSchemaValidator::validate()` implemented
- [x] `VectorMemorySchema::get()` returns complete schema map
- [x] `VectorTaskSchema::get()` returns complete schema map
- [x] `McpSchemaTrait` for wrapper classes
- [x] Mode resolver in Variations (`ModeResolverTrait`)
- [x] Lint script (`scripts/lint-mcp-syntax.sh`)

### A.2 Gates-Rules (COMPLETED)
- [x] gates-rules category exists in Task MCP
- [x] Header fixed: `## Gates & Rules` → `## Gates Rules` (removed `&` for regex compatibility)
- [x] Test file: `vector-task-mcp/tests/test_cases_integrity.py`
- [x] gates-rules populated in MCP cookbook (6 blocks)
- [x] MCP-JSON-ONLY rule [CRITICAL]
- [x] Lightweight Lawyer Gate [HIGH]
- [x] Constitutional Learn Protocol [CRITICAL]
- [x] Category Discipline Contract [HIGH]
- [x] Cookbook-First Gate [HIGH]
- [x] Failure Escalation Gate [HIGH]
- [x] Cross-project sync: vector-memory-mcp updated

### A.3 Testing (COMPLETED)
- [x] `test_cases_integrity.py` — validates all categories have descriptions
- [x] Test checks for 6 required gates in gates-rules section
- [x] Tests passing in both MCPs
- [ ] Unit tests for schema validation (optional)
- [ ] Integration test: legacy call in paranoid mode throws (optional)
- [ ] CI workflow integration (optional)

---

## Appendix A: Schema Map Template

```php
// VectorMemoryMcp::schema()
return [
    'search_memories' => [
        'required' => [],
        'allowed' => ['query', 'limit', 'category', 'offset', 'tags'],
        'types' => [
            'query' => 'string',
            'limit' => 'integer',
            'category' => 'string',
            'offset' => 'integer',
            'tags' => 'array',
        ],
    ],
    'store_memory' => [
        'required' => ['content'],
        'allowed' => ['content', 'category', 'tags'],
        'types' => [
            'content' => 'string',
            'category' => 'string',
            'tags' => 'array',
        ],
    ],
    // ... all methods
];
```

---

## Appendix B: Migration Checklist Per Include

```markdown
## {IncludeName}.php Migration

### Before (lines, calls, rules, guidelines)
- Lines: X
- MCP calls: Y
- Iron Rules: Z
- Guidelines: W

### After
- Lines: X' (target: -40%)
- MCP calls: Y' (via cookbook delegation)
- Iron Rules: Z' (conditional gates only)
- Guidelines: W' (0 — all in cookbook)

### Cookbook Presets
- standard: cookbook(include="cases", case_category="search", limit=15)
- deep: cookbook(include="cases", case_category="search,store", cognitive="deep", limit=25)
- paranoid: cookbook(include="cases", case_category="gates-rules,essential-patterns", priority="critical", strict="paranoid")

### Removed Content (→ Cookbook)
- [ ] Multi-probe strategy
- [ ] Query decomposition
- [ ] Smart store protocol
- [ ] Categories taxonomy
- [ ] MCP tools reference

### Retained Content (Iron Rules)
- [ ] MCP-only-access (conditional)
- [ ] Search-before-store (conditional)
- [ ] Triggered-suggestion (gate)

### Risks / Tests
- [ ] Test: cookbook returns expected categories
- [ ] Test: conditional rules fire correctly
- [ ] Risk: AI may skip cookbook — mitigation: gate enforcement
```

---

---

## Section H: Checkpoint B Plan — Universal Includes Migration

### B.0 Preparation (COMPLETED)
- [x] Cookbook presets defined for memory/task domains
- [x] Iron Rules skeleton for VectorMemoryInclude (4 rules)
- [x] Iron Rules skeleton for VectorTaskInclude (6 rules)
- [x] Migration contracts documented:
  - `.docs/migration/includes/VectorMemoryInclude.md`
  - `.docs/migration/includes/VectorTaskInclude.md`

### B.1 VectorMemoryInclude Migration (PENDING)
- [ ] Reduce from 124 to ~50 lines
- [ ] Implement conditional Iron Rules
- [ ] Add cookbook preset delegation
- [ ] Remove guidelines → cookbook
- [ ] Test: cookbook returns expected categories
- [ ] Test: conditional rules fire by mode

### B.2 VectorTaskInclude Migration (PENDING)
- [ ] Reduce from 183 to ~60 lines
- [ ] Implement conditional Iron Rules
- [ ] Add cookbook preset delegation
- [ ] Remove guidelines → cookbook
- [ ] Test: parent-readonly blocks
- [ ] Test: timestamps-auto enforced

### Cookbook Presets Reference

```python
# Memory domain presets
minimal:    cookbook(include="init")
standard:   cookbook(include="cases", case_category="search", limit=15)
deep:       cookbook(include="cases", case_category="search,store", cognitive="deep", limit=25)
paranoid:   cookbook(include="cases", case_category="gates-rules,essential-patterns", priority="critical", strict="paranoid", limit=40)

# Task domain presets
minimal:    cookbook(include="init")
standard:   cookbook(include="cases", case_category="essential-patterns,task-execution", limit=15)
deep:       cookbook(include="cases", case_category="plan,validate,hierarchy-decomposition", cognitive="deep", limit=25)
paranoid:   cookbook(include="cases", case_category="gates-rules,essential-patterns,parallel-execution", priority="critical", strict="paranoid", limit=40)
```

### Iron Rules Summary

**VectorMemoryInclude (4 rules):**
1. MCP-Only-Access [CRITICAL] — Always
2. Multi-Probe-Mandatory [CRITICAL] — Conditional (strict/deep/compound)
3. Search-Before-Store [HIGH] — Conditional (strict/standard)
4. Triggered-Suggestion [HIGH] — Conditional (paranoid/exhaustive/user)

**VectorTaskInclude (6 rules):**
1. MCP-Only-Access [CRITICAL] — Always
2. Explore-Before-Execute [CRITICAL] — Always (except trivial)
3. Estimate-Required [CRITICAL] — Conditional (strict/non-trivial)
4. Parent-Readonly [CRITICAL] — Always
5. Timestamps-Auto [CRITICAL] — Always
6. Single-In-Progress [HIGH] — Conditional (not minimal+relaxed)

---

## Section I: CI Contract (Post-C2)

### I.1 No-Legacy Regression Gate

The lint script `scripts/lint-mcp-syntax.sh` is the CI gate. It detects legacy pseudo-JSON syntax in compiled artifacts.

```bash
# CI — fails on any legacy syntax (default mode)
./scripts/lint-mcp-syntax.sh

# Local dev — warn only (transition/debugging)
./scripts/lint-mcp-syntax.sh --warn
```

**Scanned targets** (auto-detected):
- `.claude/CLAUDE.md`, `.claude/agents/`, `.claude/commands/`, `.claude/skills/`
- `.opencode/agent/`, `.opencode/command/`, `.opencode/OPENCODE.md`

**Exit codes**: 0 = clean, 1 = legacy detected (strict), 2 = config error.

**Developer workflow**: Run `brain compile && bash scripts/lint-mcp-syntax.sh` after every source change. This is the equivalent of `composer test` for MCP syntax.

**Recommendation**: Default is STRICT (fail). C2 achieved 0 legacy across 67 compiled files. Warn mode exists only for debugging or legacy project onboarding.

### I.2 Determinism Guarantee

All `callJson()` / `callValidatedJson()` output is fully deterministic:
1. `ksortRecursive()` sorts all keys alphabetically at every nesting level before serialization
2. `json_encode()` uses `JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES`
3. Given identical `$args`, output is byte-identical regardless of PHP array insertion order
4. The `call()` path (VarExporter) has no sorting — acceptable because it handles `Store::get()` runtime variables only
5. No `JSON_PRETTY_PRINT` anywhere — compact output guaranteed

### I.3 Compile-time Single-Mode Rationale

Compiled output contains exactly ONE mode configuration. No conditional mode branching exists in artifacts.

**Why**: Multi-mode instructions in compiled output create an attack surface where the model self-selects the most permissive mode. By resolving mode at compile time (via `.env` → `ModeResolverTrait`), we guarantee:
1. The model cannot downgrade from paranoid to standard
2. No "if strict then X else Y" branching for the model to interpret
3. Mode is set by the human operator, not by the AI
4. Cookbook presets are baked with exact parameters (limit, priority, case_category)

**Escalation path for ambiguity**: cookbook-first (`gates-rules` cases) → apply most restrictive matching rule → if still ambiguous, escalate to user. The model must NEVER self-switch modes.

### I.4 Compiled Artifacts Discipline

CI enforces compile discipline via diff-guard (`.github/workflows/brain-lint.yml`):

**Rule**: If `.brain/node/` or `node/` source files changed in a PR, then `.claude/` and `.opencode/` compiled artifacts MUST also have changed. Violation = CI failure with instruction to run `brain compile`.

**Scope**: Only node sources trigger the check. `core/src/` changes (schema fixes, validator updates) may or may not change compiled output — no false positives.

**Why not dry-run compile in CI**: The `brain` CLI is a globally installed tool with `.env` configuration. CI compilation with `.env.ci` would produce DIFFERENT artifacts (standard mode vs local paranoid mode) — verifying an artifact nobody uses. The diff-guard catches the actual risk: stale artifacts from forgotten recompilation.

### I.5 Schema Method Whitelist (strict/paranoid)

Unknown MCP methods are rejected at compile time in strict/paranoid mode. In standard/relaxed mode, unknown methods pass silently (forward compatibility for development).

**Guard**: `McpSchemaValidator` checks `!isset($schema[$method])` — if schema exists but method is missing, throw in strict/paranoid. Empty schema (e.g., Context7Mcp without McpSchemaTrait) never triggers this check.

### I.6 Env Self-Validation

Invalid `.env` values for `STRICT_MODE` or `COGNITIVE_LEVEL` cause a hard compile failure with a clear error message listing allowed values. No silent fallback to standard — prevents the "thinks it's in paranoid but actually in standard" bug.

---

## Section J: Checkpoint C — MCP Call Syntax Migration (COMPLETED)

### C.0 Summary

| Metric | Before C | After C |
|--------|----------|---------|
| Legacy MCP calls (core/src) | 209+ | 0 |
| Legacy MCP calls (.brain/node) | 12 | 0 |
| Lint warnings | 28 | 0 |
| Compile targets passing | 3/3 | 3/3 |
| Files migrated | 0 | 27+ |

### C.1 Checkpoint C1 (COMPLETED)
- [x] TaskValidateInclude.php — 33 calls migrated
- [x] TaskCommandCommonTrait.php — 8 calls migrated

### C.2 Checkpoint C2 (COMPLETED)
- [x] All Task/* includes — 120+ calls across 9 files
- [x] All Do/* includes — 23 calls across 5 files
- [x] All Mem/* includes — 14 calls across 6 files
- [x] All Init* includes — 31 calls across 4 files
- [x] DocWorkInclude + InitDocsInclude — 9 calls
- [x] All Variations includes — 3 files (previous session)
- [x] CompilationSystemKnowledgeInclude — 1 documentation example
- [x] DoCommand.php (.brain/node) — 12 hardcoded strings

### C.3 Post-C2 Enterprise Hardening (COMPLETED)
- [x] CI gate: lint default inverted to STRICT, auto-detects .claude/ + .opencode/
- [x] Schema tests: 7 unit tests for McpSchemaValidator (missing key, unknown key, type mismatch)
- [x] Schema gap: `get_memory_stats` added to VectorMemorySchema
- [x] BUG FIX: ModeResolverTrait variable names aligned with .env (STRICT→STRICT_MODE, COGNITIVE→COGNITIVE_LEVEL)
- [x] Determinism audit: confirmed ksortRecursive + stable JSON flags
- [x] Mode resolver: confirmed compile-time single-mode, zero leakage

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-02-19 | Model 2 + Model 1 | Initial RFC, consensus approved |
| 1.1.0 | 2026-02-20 | Model 2 | C2 complete, enterprise hardening, CI contract, bug fixes |
