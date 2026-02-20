# Enterprise Prompt Architecture Audit

Reproducible verification of compile-time deep-cognitive gating and cookbook governance policy.

## Quick Verification

```bash
# Full automated check (15 checks, both modes, restores standard)
bash scripts/verify-compile-metrics.sh

# MCP syntax lint (67 compiled files)
bash scripts/lint-mcp-syntax.sh

# Schema validator tests
cd core && ./vendor/bin/phpunit tests/McpSchemaValidatorTest.php
```

## Audit Documents

- `SUMMARY.md` — Baseline metrics, changes, rationale
- `DIFFS.md` — Modified files with change intent
- `VERIFICATION.md` — Full manual verification commands with expected outputs
- `RISKS.md` — Residual risk registry with mitigations

## Metrics Snapshot (2026-02-20)

| Artifact | standard | exhaustive |
|----------|----------|------------|
| CLAUDE.md | 362 | 756 |
| Agents total | 1490 | 1790 |
