<?php

declare(strict_types=1);

namespace BrainNode\Commands\Mem;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Mem\Get;

#[Meta('id', 'mem:get')]
#[Meta('description', 'Get specific memory by ID')]
#[Purpose('Retrieves and displays full content of a specific memory by ID from $ARGUMENTS. Shows all metadata, full content, and suggested actions.')]
#[Includes(Get::class)]
class GetCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}