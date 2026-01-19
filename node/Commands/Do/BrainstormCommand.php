<?php

declare(strict_types=1);

namespace BrainNode\Commands\Do;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Do\DoBrainstormInclude;

#[Meta('id', 'do:brainstorm')]
#[Meta('description', 'Freeform brainstorming session on any topic with research delegation and optional task creation.')]
#[Purpose('Facilitates structured brainstorming on any topic. Accepts topic directly as argument, provides collaborative ideation with agent delegation for research (web, code, docs) and ability to create tasks from brainstorm outcomes.')]
#[Includes(DoBrainstormInclude::class)]
class BrainstormCommand extends CommandArchetype
{
    protected function handle(): void
    {
        // Logic defined in DoBrainstormInclude
    }
}
