<?php

declare(strict_types=1);

namespace BrainNode\Commands\Task;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Task\TaskAsyncInclude;

#[Meta('id', 'task:async')]
#[Meta('description', 'Async task execution command')]
#[Purpose('Run task execution asynchronously.')]
#[Includes(TaskAsyncInclude::class)]
class AsyncCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}
