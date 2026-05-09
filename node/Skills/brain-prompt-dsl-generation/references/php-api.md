---
name: "Brain Prompt DSL PHP API"
description: "Compact reference for Brain PHP DSL helper APIs"
---

# PHP API

Use `Runtime` for paths, never hardcoded compiled paths.

Use `Operator` for workflow terms: `if`, `forEach`, `task`, `validate`, `verify`, `check`, `goal`, `scenario`, `report`, `skip`, `note`, `context`, `output`, `input`, `do`, `delegate`.

Use `Store::as()` and `Store::get()` for pseudo-variable storage.

Use `BrainCLI` constants and methods for CLI command text.

Use `BrainCore\Compilation\Tools\*Tool::call()` and `::describe()` for generated tool syntax.

Use MCP node classes with validated JSON helpers where available.
