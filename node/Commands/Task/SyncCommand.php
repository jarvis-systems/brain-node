<?php

declare(strict_types=1);

namespace BrainNode\Commands\Task;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Task\TaskSyncInclude;

#[Meta('id', 'task:sync')]
#[Meta('description', 'Sync task execution command')]
#[Purpose('Execute tasks synchronously')]
#[Includes(TaskSyncInclude::class)]
class SyncCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}
