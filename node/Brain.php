<?php

declare(strict_types=1);

namespace BrainNode;

use BrainCore\Archetypes\BrainArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Variations\Brain\Scrutinizer;

#[Meta('id', 'brain-core')]
#[Purpose('<!-- Specify the primary project purpose of this Brain here -->')]

#[Includes(Scrutinizer::class)]         // Include the Scrutinizer brain variation
class Brain extends BrainArchetype
{
    /**
     * Handle the architecture logic.
     *
     * @return void
     */
    protected function handle(): void
    {
        // Brain orchestration logic can be added here if needed
    }
}
