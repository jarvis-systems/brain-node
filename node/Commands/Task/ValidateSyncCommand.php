<?php

declare(strict_types=1);

namespace BrainNode\Commands\Task;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Task\TaskValidateSyncInclude;

#[Meta('id', 'task:validate-sync')]
#[Meta('description', 'Direct sync validation of vector task without agent delegation')]
#[Purpose('Validate completed vector task synchronously without agent delegation.')]
#[Includes(TaskValidateSyncInclude::class)]
class ValidateSyncCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}
