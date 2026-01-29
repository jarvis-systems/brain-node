<?php

declare(strict_types=1);

namespace BrainNode\Commands\Task;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Task\TaskListInclude;

#[Meta('id', 'task:list')]
#[Meta('description', 'List tasks with optional filters (status, parent, tags, priority)')]
#[Purpose('List vector tasks with optional filters and hierarchy display.')]
#[Includes(TaskListInclude::class)]
class ListCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}
