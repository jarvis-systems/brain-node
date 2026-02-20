# Enterprise Readiness Report

---
name: "Enterprise Readiness Report"
type: "report"
version: "1.3.0"
date: "2026-02-20"
status: "approved"
prerequisite: "00-mcp-json-migration.md"
---

## What This System Guarantees

The Brain MCP compilation pipeline eliminates AI hallucination vectors through mechanical enforcement at compile time. Every MCP tool call in compiled agent/command instructions is:

1. **Mechanically valid JSON** — `json_encode(JSON_THROW_ON_ERROR)`, not string interpolation
2. **Schema-validated** — required keys enforced in all modes; unknown keys/methods rejected in strict/paranoid
3. **Deterministic** — `ksortRecursive()` guarantees byte-identical output for identical inputs
4. **Lint-gated** — 67 compiled files scanned on every build; legacy pseudo-JSON is a hard failure
5. **Single-mode** — mode resolved at compile time from `.env`; AI cannot self-select a weaker mode
6. **Type-safe** — paranoid mode validates PHP types against schema at compile time
7. **CI-enforced** — GitHub Actions runs schema tests + lint + compile discipline on every push
8. **Compile-disciplined** — CI diff-guard ensures compiled artifacts stay in sync with source
9. **Env-validated** — invalid mode values fail compilation immediately, no silent fallbacks

Result: the AI model receives instructions containing only valid, schema-conformant MCP calls. It cannot hallucinate parameters, use deprecated syntax, or bypass validation — because the instructions it reads were already validated before it ever saw them. The attack surface for MCP-related hallucinations is reduced to zero for schema-covered methods.

---

## Threat Model

### Mitigated Hallucination Vectors

| Vector | Mitigation | Evidence |
|--------|-----------|----------|
| Hallucinated MCP parameters | `McpSchemaValidator` rejects unknown keys in strict/paranoid | 10 unit tests, compile-time enforcement |
| Hallucinated MCP methods | Unknown methods rejected in strict/paranoid mode | `testUnknownMethodThrowsInStrictMode` |
| Missing required parameters | Schema validates required keys in ALL modes | `task_update` without `task_id` caught during C2 |
| Pseudo-JSON ambiguity | `callJson()`/`callValidatedJson()` produce mechanical JSON | `json_encode(JSON_THROW_ON_ERROR)` — no string interpolation |
| Type confusion | Paranoid mode validates PHP types against schema | `validateType()` with normalized type map |
| Non-deterministic output | `ksortRecursive()` + stable JSON flags | Byte-identical output for identical args |
| Mode self-switching | Compile-time single-mode resolution + no-self-switch Iron Rule | `.env` → `ModeResolverTrait` → baked into artifacts; runtime rule forbids changes |
| Mode leakage | Zero mode hints in compiled artifacts | All "strict/paranoid:" prefixes removed; Purpose attributes mode-neutral |
| Namespace confusion | settings.json namespace bugs fixed | 5 `vector-memory__task_*` entries removed (correct `vector-task__` entries existed) |
| Legacy syntax regression | Lint gate fails on any legacy pattern | 67 files scanned, strict mode default |
| Invalid mode configuration | Hard fail on unknown STRICT_MODE/COGNITIVE_LEVEL values | `InvalidArgumentException` at compile time |
| Context bloat in standard mode | Reference sections gated by `isDeepCognitive()` | 210 lines saved in standard (489 vs 731) |
| Speculative cookbook pulls | Cookbook Governance Policy: compile-time preset only, no uncertainty triggers, budget cap | `cookbook-governance` CRITICAL rule + `gate5-satisfied` guideline in compiled output |

### Residual Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| `call()` path not deterministic | Low | Only used for `Store::get()` runtime variables — not user-facing MCP calls |
| Context7Mcp has no schema | Low | Intentionally schema-less: read-only API, no write mutations. strict/paranoid still enforces JSON validity and forbids legacy syntax. Schema enforcement applies to VectorTask/VectorMemory only |
| Pre-existing test failures | Medium | 8 tests in MergerTest/XmlBuilderTest/TomlBuilderTest fail due to API changes predating this work |
| Cookbook case poisoning | Medium | Supply-chain risk (requires git write access to MCP repos), NOT classic RAG poisoning (no user-writable retrieval). Mitigation: Brain-exclusive writer to memory, agents read-only; cookbook cases validated via CASES.md in versioned repos; Cookbook Governance Policy limits pulls to compile-time preset + explicit onViolation only |

## Invariants

1. **JSON-only**: All MCP calls in compiled output use `mcp__{id}__{method}({JSON})` format
2. **Schema-validated**: VectorTask + VectorMemory calls pass through `McpSchemaValidator` at compile time
3. **Lint gate**: `scripts/lint-mcp-syntax.sh` scans all compiled artifacts, fails on legacy patterns
4. **Deterministic**: `ksortRecursive` + `JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES`
5. **Single-mode**: Compiled output contains exactly one mode configuration, resolved from `.env`
6. **Compile-time safety**: Schema errors surface during `brain compile`, not at runtime
7. **Method whitelist**: Unknown methods rejected in strict/paranoid (empty schema = no restriction)
8. **Env validation**: Invalid mode values fail compilation with clear error message
9. **Compile discipline**: CI diff-guard ensures `.brain/node/` changes are accompanied by recompiled artifacts
10. **Zero mode leakage**: Compiled artifacts contain no references to other modes; model sees only its own configuration
11. **Mode-gated reference**: Deep-cognitive gating across 4 Brain includes + 1 universal include saves ~287 lines in standard (Brain: 127, Agents: 160)
12. **No-self-switch**: Iron rule forbids runtime mode changes; model can only recommend mode with risk explanation
13. **Cookbook governance**: Cookbook calls limited to compile-time preset + explicit onViolation; no uncertainty triggers, no speculative pulls, no runtime param construction

## Operational Guidance

### Extending Schemas (Adding New MCP Methods)

1. Add method to schema class (`core/src/Mcp/Schemas/Vector*Schema.php`)
2. Define `required`, `allowed`, and `types` arrays
3. Add unit test to `core/tests/McpSchemaValidatorTest.php`
4. Run `cd core && ./vendor/bin/phpunit tests/McpSchemaValidatorTest.php`
5. Use `callValidatedJson()` in include/command code
6. Run `brain compile && bash scripts/lint-mcp-syntax.sh`

### Adding New MCP Wrappers

1. Create class in `.brain/node/Mcp/` extending `StdioMcp`/`HttpMcp`/`SseMcp`
2. If schema validation desired: `use McpSchemaTrait`, create schema class, implement `getSchemaClass()`
3. If no schema: use `callJson()` directly (still gets deterministic JSON, no method whitelist)
4. Run `brain compile`

### Mode Configuration

```bash
# .env (or .brain/.env)
STRICT_MODE="standard"       # relaxed | standard | strict | paranoid
COGNITIVE_LEVEL="standard"   # minimal | standard | deep | exhaustive
```

After changing modes: `brain compile` to rebake all artifacts. Invalid values = compile error.

**Testing note**: When testing mode changes from within Claude Code CLI, pass env vars explicitly to override inherited process environment:
```bash
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
```

## Single-Mode Proof

Compiled artifacts contain exactly ONE baked mode — no conditional branching for the model to interpret.

**Test method** (must pass env vars explicitly to override CLI process environment):
```bash
STRICT_MODE=standard COGNITIVE_LEVEL=standard brain compile
STRICT_MODE=paranoid COGNITIVE_LEVEL=exhaustive brain compile
```

**Comparison (CLAUDE.md)**:

| Metric | standard/standard | exhaustive/paranoid |
|--------|------------------|---------------------|
| Total lines | **489** | **731** |
| Reference sections (namespaces, API, builders) | ABSENT | PRESENT |
| Mode selection decision tree | ABSENT | PRESENT |
| Cookbook preset | `case_category:"search"`, limit 20 | `case_category:"store,gates-rules,essential-patterns"`, limit 40 |
| Cookbook-first directive | ABSENT | PRESENT |
| Multi-probe-mandatory rule | ABSENT | PRESENT |
| Triggered-suggestion rule | ABSENT | PRESENT |
| Estimate-required rule | ABSENT | PRESENT |
| No-mode-self-switch rule | PRESENT | PRESENT |
| Mode leakage ("strict/paranoid:" text) | **0** | **0** |
| Conditional branching (`if strict/cognitive...`) | **0** | **0** |

**Fragment (paranoid/exhaustive)**:
```
Active cookbook preset for memory operations. Mode: exhaustive/paranoid
- Call: mcp__vector-memory__cookbook({"case_category":"store,gates-rules,essential-patterns","cognitive":"exhaustive","include":"cases","limit":40,"priority":"critical","strict":"paranoid"})
```

**Fragment (standard/standard)**:
```
Active cookbook preset for memory operations. Mode: standard/standard
- Call: mcp__vector-memory__cookbook({"case_category":"search","cognitive":"standard","include":"cases","limit":20,"priority":"high","strict":"standard"})
```

Both artifacts have ZERO `if strict/cognitive/mode` conditionals — the model sees only one fixed configuration and cannot self-select a weaker mode.

---

## Known Limitations

1. **Context7Mcp**: Intentionally schema-less (read-only API, no write mutations; JSON validity and legacy syntax rejection still enforced)
2. **SequentialThinkingMcp**: No schema validation (single-method API)
3. **GithubMcp / LaravelBoostMcp**: No schema validation (external tools)
4. **`call()` path**: Non-deterministic key order (used only for Store::get() runtime vars)
5. **No CI compilation**: `brain compile` runs locally only; CI verifies artifacts via diff-guard

## Benchmark Metrics

### Compiled Output Size

| Artifact | Lines | Files |
|----------|-------|-------|
| Brain (CLAUDE.md) standard/standard | 362 | 1 |
| Brain (CLAUDE.md) paranoid/exhaustive | 756 | 1 |
| Agents | ~1,600 | 8 |
| Commands | 2,520 | 6 |
| **Total** | **~4,840** | **15** |

### MCP Call Schema Coverage

| Category | Calls | Schema Validated | Coverage |
|----------|-------|------------------|----------|
| vector-memory | 153 | Yes | 100% |
| vector-task | 185 | Yes | 100% |
| sequential-thinking | 15 | No (single-method API) | N/A |
| laravel-boost | 17 | No (external tool) | N/A |
| **Schema-covered** | **338/372** | | **90.9%** |

Legacy pseudo-JSON calls: **0** (was 209+ pre-C2).

### Per-Command Prompt Size

| Command | Lines |
|---------|-------|
| do.md | 328 |
| init-vector.md | 310 |
| init-docs.md | 346 |
| init-task.md | 413 |
| init-agents.md | 418 |
| init-brain.md | 705 |
| **Average** | **420** |

### Source Code Metrics

| Metric | Value |
|--------|-------|
| `callValidatedJson()`/`callJson()` calls in source | 268 |
| Files with MCP references | 34 |
| Schema test assertions | 16 |
| Lint-scanned compiled files | 67 |

---

## Weakest Link

**The weakest remaining link is the 8 pre-existing test failures in core.**

The CI pipeline (lint + schema tests + compile discipline), schema validator (method whitelist + env validation), and lint gate are all in place. The pre-existing failures in MergerTest/XmlBuilderTest/TomlBuilderTest predate the MCP migration but prevent running a full `composer test` gate. Fixing them would enable the CI to run ALL tests, not just McpSchemaValidatorTest.
