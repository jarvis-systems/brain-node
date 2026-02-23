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
| Codex | `.agents/skills/*/SKILL.md` | Subdirectory | name, description |

### Compilation

Skills are compiled from `.brain/node/Skills/*.php` source files using SkillArchetype. Each client generates the appropriate output format automatically.

## Troubleshooting

### Skill Not Appearing

1. Check source file exists: `.brain/node/Skills/XxxSkill.php`
2. Verify class extends SkillArchetype
3. Check #[Meta('id', 'skill-name')] is set
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
- Codex uses subdirectory format (SKILL.md)
