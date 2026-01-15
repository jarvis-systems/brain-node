<?php

declare(strict_types=1);

namespace BrainNode\Commands\Task;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Task\TaskCreateInclude;

#[Meta('id', 'task:create')]
#[Meta('description', 'Create task from description with analysis and estimation')]
#[Purpose('Create vector task(s) from user description.')]
#[Includes(TaskCreateInclude::class)]
class CreateCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}
