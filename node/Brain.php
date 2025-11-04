<?php

declare(strict_types=1);

namespace BrainNode;

use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Includes;
use BrainCore\Archetypes\BrainArchetype;
use BrainCore\Includes\Brain\BrainCore;
use BrainCore\Includes\Brain\CognitiveArchitecture;
use BrainCore\Includes\Brain\DelegationProtocols;
use BrainCore\Includes\Brain\PreActionValidation;
use BrainCore\Includes\Universal\AgentLifecycleFramework;
use BrainCore\Includes\Universal\CoreConstraints;
use BrainCore\Includes\Universal\ErrorHandling;
use BrainCore\Includes\Universal\QualityGates;
use BrainCore\Includes\Universal\SequentialReasoningCapability;

#[Meta('id', 'brain-core')]

// === UNIVERSAL (shared across Brain + Agents) ===
#[Includes(CoreConstraints::class)]                     // System constraints + MCP policy + compaction
#[Includes(QualityGates::class)]                        // Quality gates + agent response validation
#[Includes(AgentLifecycleFramework::class)]             // Agent lifecycle phases
#[Includes(SequentialReasoningCapability::class)]       // Reasoning framework
#[Includes(ErrorHandling::class)]                       // Unified error handling

// === BRAIN ORCHESTRATION (Brain-specific) ===
#[Includes(BrainCore::class)]                           // Foundation + meta
#[Includes(PreActionValidation::class)]                 // Pre-action safety gate
#[Includes(DelegationProtocols::class)]                 // Delegation protocols
#[Includes(CognitiveArchitecture::class)]               // Cognitive orchestration

class Brain extends BrainArchetype
{
    /**
     * Handle the architecture logic.
     *
     * @return void
     */
    protected function handle(): void
    {
        // Orchestration logic
    }
}
