# Jarvis Brain Node

Compile-time instruction compiler for AI agents. Eliminates MCP hallucination vectors through mechanical enforcement.

## Invariants

1. **JSON-only** — all MCP calls use `json_encode(JSON_THROW_ON_ERROR)`, not string interpolation
2. **Schema-validated** — required keys enforced in all modes; unknown keys/methods rejected in strict/paranoid
3. **Deterministic** — `ksortRecursive()` guarantees byte-identical output for identical inputs
4. **Single-mode** — mode resolved at compile time from `.env`; AI cannot self-select a weaker mode
5. **Lint-gated** — 67 compiled files scanned on every build; legacy pseudo-JSON is a hard failure
6. **CI-enforced** — schema tests + lint + compile discipline on every push

## Extending Schemas

```
1. Add method to schema class   → core/src/Mcp/Schemas/Vector*Schema.php
2. Define required/allowed/types → ['required' => [...], 'allowed' => [...], 'types' => [...]]
3. Add unit test                 → core/tests/McpSchemaValidatorTest.php
4. Run tests                     → cd core && ./vendor/bin/phpunit tests/McpSchemaValidatorTest.php
5. Use in code                   → callValidatedJson('method', [...])
6. Compile + lint                → brain compile && bash scripts/lint-mcp-syntax.sh
```

## Mode Configuration

```bash
# .brain/.env
STRICT_MODE="paranoid"        # relaxed | standard | strict | paranoid
COGNITIVE_LEVEL="exhaustive"  # minimal | standard | deep | exhaustive
```

After changing: `brain compile` to rebake all artifacts. Invalid values = compile error.

## Init Commands

> For proper Brain initialization, execute in order as needed:

1. `/init-vector` — Vector memory verification
2. `/init-brain` — Brain instructions verification
3. `/init-agents` — Brain agents verification
4. `/init-task` — Current project tasks verification (if needed)
