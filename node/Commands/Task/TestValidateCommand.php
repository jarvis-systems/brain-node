<?php

declare(strict_types=1);

namespace BrainNode\Commands\Task;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Task\TaskTestValidateInclude;

#[Meta('id', 'task:test-validate')]
#[Meta('description', 'Test validate task execution command')]
#[Purpose('Test validate tasks')]
#[Includes(TaskTestValidateInclude::class)]
class TestValidateCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}
