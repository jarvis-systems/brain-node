<?php

declare(strict_types=1);

namespace BrainNode\Commands\Skill;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Skill\SkillNewInclude;

#[Meta('id', 'skill:new')]
#[Meta('description', 'Create a new skill (interactive)')]
#[Purpose('One-arg interactive command. Takes a kebab-case skill name, asks the user for purpose, enriches body sections from session signals, auto-suggests docs_topics, drafts a full SKILL.md.new with YAML frontmatter, then writes the pending proposal via the shared triage + write pipeline.')]
#[Includes(SkillNewInclude::class)]
class NewCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}