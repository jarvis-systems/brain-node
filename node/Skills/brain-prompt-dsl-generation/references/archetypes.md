---
name: "Brain Prompt DSL Archetypes"
description: "Compact Brain component structure and source boundary reference"
---

# Archetypes

Source components live in `node/`; compiled client artifacts are generated and read-only.

Common bases:

- `BrainArchetype`: root system prompt.
- `AgentArchetype`: delegated execution surface.
- `CommandArchetype`: slash/prompt command surface.
- `IncludeArchetype`: reusable compile-time fragment.
- `SkillArchetype`: PHP-generated skill.
- Native skill folder: `node/Skills/<id>/SKILL.md` plus optional bundled resources.

Commands may include command-specific includes. Do not attach Brain or Universal includes to commands unless the command has unique workflow logic requiring them.
