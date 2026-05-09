---
name: "Skills Runbook"
description: "Operating guide for Brain skills: invocation, troubleshooting, and cross-client compatibility"
type: "runbook"
date: "2026-02-23"
---

# Skills Runbook

## Overview

Skills are on-demand instruction packs loaded via the `skill` tool. Each skill provides specialized knowledge for specific workflows without bloating the base context.

## Available Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| health-check | Run project quality gates | Before/after changes, CI validation |
| evidence-pack-builder | Format EVIDENCE-ONLY reports | Snapshot reports, verification tasks |
| repo-boundary-preflight | Prevent cross-repo commits | Before any commit in monorepo |
| docs-truth-sync | Classify and validate documentation | After doc changes, before releases |
| client-format-triage | Diagnose client format issues | When verify-client-formats.sh fails |
| brain-prompt-dsl-generation | Brain PHP DSL/API reference workflow | When generating Brain components |
| vector-memory | Vector memory safety and workflow | Before memory search/store operations |
| vector-task | Vector task lifecycle workflow | Before task CRUD/status operations |
| laravel-boost | Laravel Boost execution guidance | Laravel projects with Boost tooling |
| structured-reasoning | Compact reasoning workflow | Complex analysis that needs explicit structure |

## Skill Invocation

Skills are loaded on-demand via the native `skill` tool:

```
skill({ name: "health-check" })
```

The skill content is injected into context, providing guidelines without permanent context bloat.

## Cross-Client Compatibility

### Format Matrix

| Client | Skills Path | File Format | Required Frontmatter |
|--------|-------------|-------------|---------------------|
| OpenCode | `.opencode/skills/*.md` | Flat markdown | name, description |
| Claude | `.claude/skills/*.md` | Flat markdown | name, description |
| Gemini | `.gemini/skills/*.md` | Flat markdown | name, description |
| Qwen | `.qwen/skills/*.md` | Flat markdown | name, description |
| Codex | `.codex/skills/*/SKILL.md` | Subdirectory | name, description |

### Compilation

Skills have two source formats:

- PHP skills: `.brain/node/Skills/*Skill.php` using `SkillArchetype`.
- Native skills: `.brain/node/Skills/<skill-id>/SKILL.md` with optional sibling `references/`, `scripts/`, `assets/`, or other bundled files.

PHP and native skills share one namespace of skill names. Duplicate `name` values are a compile error. Native bundled files are copied beside the compiled skill for Codex, and into `.*/skills/<id>/...` for flat clients.

## Troubleshooting

### Skill Not Appearing

1. Check source file exists: `.brain/node/Skills/XxxSkill.php`
2. For PHP skills, verify class extends SkillArchetype
3. For native skills, verify `.brain/node/Skills/<id>/SKILL.md` exists
4. Run `brain compile` to regenerate

### Format Drift

Run verification:
```bash
bash scripts/verify-client-formats.sh
```

If skills checks fail, use `/client-format-triage` skill for remediation guidance.

### Empty Skills Directory

Each client with agents MUST have at least 1 skill. If the skills directory is empty:
1. Create skill source in `.brain/node/Skills/`
2. Run `brain compile`
3. Re-verify with `verify-client-formats.sh`

## Best Practices

1. **Minimal Skills**: Each skill should be focused and concise
2. **Clear Contracts**: Define input/output/stop conditions explicitly
3. **Evidence Required**: Specify what evidence the skill must provide
4. **No Code Bloat**: Skills are instructions, not codebases

## Source Structure

Native scaffold:

```bash
brain make:skill brain-prompt-dsl-generation --native --description="Generate Brain PHP DSL prompts"
```

Native source layout:

```text
.brain/node/Skills/example-skill/
  SKILL.md
  references/workflow.md
  scripts/helper.sh
  assets/template.txt
```

PHP source layout:

```php
<?php
namespace BrainNode\Skills;

use BrainCore\Archetypes\SkillArchetype;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;

#[Meta('id', 'skill-name')]
#[Meta('description', 'Brief description for skill tool listing')]
#[Purpose('Detailed purpose of the skill')]
class SkillNameSkill extends SkillArchetype
{
    protected function handle(): void
    {
        $this->guideline('section-id')
            ->text('Section description')
            ->example()->do(['Step 1', 'Step 2']);
    }
}
```

## Guards

The `verify-client-formats.sh` script enforces:
- Skills directory exists if agents exist
- Skills directory is not empty
- All skill files have valid YAML frontmatter
- Codex uses `.codex/skills/<id>/SKILL.md`
