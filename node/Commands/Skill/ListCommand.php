<?php

declare(strict_types=1);

namespace BrainNode\Commands\Skill;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Skill\SkillListInclude;

#[Meta('id', 'skill:list')]
#[Meta('description', 'List pending skill proposals')]
#[Purpose('Enumerate all pending skill proposals under node/Skills/*/pending-proposals/ and node/Skills/.new-proposals/, sorted by created_at DESC.')]
#[Includes(SkillListInclude::class)]
class ListCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}