---
name: "Brain Prompt DSL Source Scan"
description: "Required source scanning sequence before Brain PHP DSL generation"
---

# Source Scan

Before generating Brain component code, inspect current PHP source files. Documentation can lag behind implementation.

Required scan:

1. `core/src/Compilation/**/*.php`
2. `core/src/Compilation/Runtime.php`
3. `core/src/Compilation/Operator.php`
4. `core/src/Compilation/Store.php`
5. `core/src/Compilation/BrainCLI.php`
6. `core/src/Compilation/Tools/*.php`
7. `core/src/Abstracts/ToolAbstract.php`
8. `node/Mcp/*.php`

Extract signatures and usage patterns from source before writing code.
