<?php

declare(strict_types=1);

namespace BrainNode\Commands\Do;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Do\DoValidateInclude;

#[Meta('id', 'do:validate')]
#[Meta('description', 'Comprehensive task/work validation with parallel agent orchestration')]
#[Purpose('Validates completed tasks or work against documentation requirements, code consistency, and completeness. Uses 5-6 parallel agents for thorough validation. Creates follow-up tasks for gaps found. For vector tasks: requires status "completed", sets to "in_progress" during validation, returns to "completed" with findings. Idempotent - can be run multiple times safely. Accepts $ARGUMENTS: vector task reference (task N, task:N, #N) or plain description.')]
#[Includes(DoValidateInclude::class)]
class ValidateCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}