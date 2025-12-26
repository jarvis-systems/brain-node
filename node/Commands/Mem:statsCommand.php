<?php

declare(strict_types=1);

namespace BrainNode\Commands;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Purpose;
use BrainCore\Attributes\Meta;

#[Meta('id', 'mem:stats')]
#[Meta('description', '<description here>')]
#[Purpose('Command for mem:stats')]
class Mem:statsCommand extends CommandArchetype
{
    /**
     * Handle the architecture logic.
     */
    protected function handle(): void
    {
        //
    }
}
