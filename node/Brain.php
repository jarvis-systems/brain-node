<?php

declare(strict_types=1);

namespace BrainNode;

use BrainCore\Archetypes\BrainArchetype;
use BrainCore\Attributes\Includes;
use BrainCore\Includes\Brain\AgentDelegation;
use BrainCore\Includes\Brain\AgentResponseValidation;
use BrainCore\Includes\Brain\BrainCore;
use BrainCore\Includes\Brain\CognitiveArchitecture;
use BrainCore\Includes\Brain\CollectiveIntelligencePhilosophy;
use BrainCore\Includes\Brain\CompactionRecovery;
use BrainCore\Includes\Brain\ContextAnalysis;
use BrainCore\Includes\Brain\CorrectionProtocolEnforcement;
use BrainCore\Includes\Brain\DelegationProtocols;
use BrainCore\Includes\Brain\EdgeCases;
use BrainCore\Includes\Brain\PreActionValidation;
use BrainCore\Includes\Universal\AgentLifecycleFramework;
use BrainCore\Includes\Universal\CoreConstraints;
use BrainCore\Includes\Universal\ErrorRecovery;
use BrainCore\Includes\Universal\InstructionWritingStandards;
use BrainCore\Includes\Universal\QualityGates;
use BrainCore\Includes\Universal\ResponseFormatting;
use BrainCore\Includes\Universal\SequentialReasoningCapability;
use BrainCore\Includes\Universal\VectorMasterStorageStrategy;


// === UNIVERSAL (спільні для всіх) ===
#[Includes(CoreConstraints::class)]                     // Системні обмеження (фундамент)
#[Includes(QualityGates::class)]                        // Якісні вимоги
#[Includes(InstructionWritingStandards::class)]         // Стандарти документації
#[Includes(ErrorRecovery::class)]                       // Обробка помилок
#[Includes(AgentLifecycleFramework::class)]             // Життєвий цикл агентів
#[Includes(SequentialReasoningCapability::class)]       // Фреймворк міркування
#[Includes(VectorMasterStorageStrategy::class)]         // Архітектура пам'яті
#[Includes(ResponseFormatting::class)]                  // Валідація відповідей

// === BRAIN SPECIFIC (тільки для Brain) ===
#[Includes(BrainCore::class)]                           // Базові правила та мета-дані
#[Includes(CollectiveIntelligencePhilosophy::class)]    // Філософські принципи системи
#[Includes(ContextAnalysis::class)]                     // Аналіз контексту та готовності
#[Includes(PreActionValidation::class)]                 // Валідація перед діями
#[Includes(DelegationProtocols::class)]                 // Протоколи делегування
#[Includes(AgentDelegation::class)]                     // Легкий референс делегування
#[Includes(CognitiveArchitecture::class)]               // Когнітивна архітектура (використовує всі попередні)
#[Includes(AgentResponseValidation::class)]             // Валідація відповідей агентів
#[Includes(CorrectionProtocolEnforcement::class)]       // Корекція помилок
#[Includes(CompactionRecovery::class)]                  // Компакція та відновлення контексту
#[Includes(EdgeCases::class)]                           // Обробка граничних випадків
class Brain extends BrainArchetype
{
    /**
     * Handle the architecture logic.
     *
     * @return void
     */
    protected function handle(): void
    {
        // Architecture logic goes here
    }
}
