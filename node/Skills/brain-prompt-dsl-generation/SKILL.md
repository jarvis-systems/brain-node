---
name: "brain-prompt-dsl-generation"
description: "Author Brain PHP DSL components and prompts using source-scanned APIs and deterministic compile workflow"
---

# Brain Prompt DSL Generation

Use this skill when creating or editing Brain components: Brain, Agents, Commands, Includes, Skills, MCP classes, or prompt artifacts generated from them.

## Workflow

1. Scan the current PHP source before generating code. Do not rely on memory for API signatures.
2. Edit only source files under `node/` or `core/src/`; never edit compiled client artifacts directly.
3. Use `BrainCore\Compilation` helpers for pseudo-syntax, tool calls, paths, and storage.
4. Keep prompt rules atomic, testable, and operational. Prefer short rules plus detailed references.
5. Run `brain compile` after source changes and verify generated surfaces.

## References

- `references/source-scan.md`: mandatory source-scan sequence.
- `references/php-api.md`: current Runtime, Operator, Store, BrainCLI, Tools usage.
- `references/archetypes.md`: component structure and source/output boundaries.
