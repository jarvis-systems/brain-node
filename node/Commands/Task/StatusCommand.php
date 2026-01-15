<?php

declare(strict_types=1);

namespace BrainNode\Commands\Task;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Task\TaskStatusInclude;

#[Meta('id', 'task:status')]
#[Meta('description', 'Show task statistics with optional custom query ($ARGUMENTS)')]
#[Purpose('Show task stats and progress.')]
#[Includes(TaskStatusInclude::class)]
class StatusCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}
