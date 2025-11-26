<?php

declare(strict_types=1);

namespace BrainNode\Commands\Do;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Includes\Commands\Do\DoTestValidateInclude;

#[Meta('id', 'do:test-validate')]
#[Meta('description', 'Comprehensive test validation with parallel agent orchestration')]
#[Purpose('Validates test coverage against documentation requirements, test quality (no bloat, real workflows), test consistency, and completeness. Uses 6 parallel agents for thorough validation. Creates follow-up tasks for missing tests, failing tests, and refactoring needs. For vector tasks: requires status "completed", sets to "in_progress" during validation, returns to "completed" with findings. Idempotent - can be run multiple times safely. Accepts $ARGUMENTS: vector task reference (task N, task:N, #N) or plain description.')]
#[Includes(DoTestValidateInclude::class)]
class TestValidateCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {

    }
}