<?php

declare(strict_types=1);

namespace BrainNode\Commands\Skill;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Skill\SkillApplyInclude;

#[Meta('id', 'skill:apply')]
#[Meta('description', 'Apply an approved skill proposal to canonical SKILL.md')]
#[Purpose('Validate the proposal, merge diff or write new SKILL.md, record history-references/{date}-applied-{slug}.md, then remove the pending folder.')]
#[Includes(SkillApplyInclude::class)]
class ApplyCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}