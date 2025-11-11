<?php

declare(strict_types=1);

namespace BrainNode;

use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Includes;
use BrainCore\Archetypes\BrainArchetype;
use BrainCore\Includes\Brain\BrainBasicErrorHandling;
use BrainCore\Includes\Brain\BrainCore;
use BrainCore\Includes\Brain\BrainDelegationWorkflow;
use BrainCore\Includes\Brain\BrainResponseValidation;
use BrainCore\Includes\Brain\DelegationProtocols;
use BrainCore\Includes\Brain\PreActionValidation;
use BrainCore\Includes\Universal\BrainCoreConstraints;

#[Meta('id', 'brain-core')]

// === UNIVERSAL (Brain runtime essentials) ===
#[Includes(BrainCoreConstraints::class)]                // Simplified constraints for Brain orchestration

// === BRAIN ORCHESTRATION (Brain-specific) ===
#[Includes(BrainCore::class)]                           // Foundation + meta
#[Includes(PreActionValidation::class)]                 // Pre-action safety gate
#[Includes(DelegationProtocols::class)]                 // Delegation protocols
#[Includes(BrainDelegationWorkflow::class)]             // Simplified delegation workflow
#[Includes(BrainResponseValidation::class)]             // Agent response validation
#[Includes(BrainBasicErrorHandling::class)]             // Basic error handling
class Brain extends BrainArchetype
{
    /**
     * Handle the architecture logic.
     *
     * @return void
     */
    protected function handle(): void
    {
        $this->purpose('<enter-brain-purpose-here>');
    }
}
