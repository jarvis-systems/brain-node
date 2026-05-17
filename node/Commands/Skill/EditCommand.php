<?php

declare(strict_types=1);

namespace BrainNode\Commands\Skill;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Skill\SkillEditInclude;

#[Meta('id', 'skill:edit')]
#[Meta('description', 'Modify an existing skill (interactive diff)')]
#[Purpose('One-arg interactive command. Reads node/Skills/{name}/SKILL.md plus session signals (git history, recent corrections, related tasks), suggests a unified diff for user accept/edit/abort, then writes the pending proposal via the shared triage + write pipeline as a modify-skill proposal.')]
#[Includes(SkillEditInclude::class)]
class EditCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}