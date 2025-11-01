# Jarvis Brain Node/Core Overview

## Purpose
The repository contains two closely coupled packages:
- `jarvis-brain/core` – a PHP library that models "brain" directives as DTO-based blueprints and provides tools to compose, merge, and export them.
- `jarvis-brain/node` – an executable node that assembles the core archetypes (e.g., `BrainNode\Brain`) for downstream consumption.

The system formalises behavioural policy for agents as structured data which can then be transformed into deterministic XML without superfluous whitespace. It is intended for orchestrating AI agent behaviour through declarative configuration rather than imperative logic.

## Brain Architecture Files
Located in `core/src/Includes/Brain/`, these files define the complete cognitive and operational framework:

### Core Structure Files (11 total):
1. **BrainCore.php** - Base rules, meta-data, style, response contract, determinism settings
2. **PreActionValidation.php** - Validation protocol before any action/tool invocation
3. **AgentDelegation.php** - Lightweight delegation reference stub
4. **AgentResponseValidation.php** - Protocol for evaluating agent responses post-execution
5. **CognitiveArchitecture.php** - Unified cognitive framework integrating reasoning, validation, correction subsystems
6. **CollectiveIntelligencePhilosophy.php** - Philosophical foundation of multi-agent intelligence
7. **CompactionRecovery.php** - Context compaction and recovery when approaching token limits
8. **ContextAnalysis.php** - Contextual awareness and readiness evaluation protocol
9. **CorrectionProtocolEnforcement.php** - Error handling, correction, and rollback procedures
10. **DelegationProtocols.php** - Task assignment, authority transfer, responsibility flow framework
11. **EdgeCases.php** - Handling abnormal/boundary scenarios and graceful degradation

### Recommended Include Order (Logical Dependency Flow):
```php
BrainCore                          // Foundation & meta
→ CollectiveIntelligencePhilosophy // Philosophy
→ ContextAnalysis                   // Context awareness
→ PreActionValidation              // Pre-action checks
→ DelegationProtocols              // Delegation rules
→ AgentDelegation                  // Delegation stub
→ CognitiveArchitecture            // Main cognitive flow
→ AgentResponseValidation          // Post-execution validation
→ CorrectionProtocolEnforcement    // Error correction
→ CompactionRecovery               // Context management
→ EdgeCases                        // Edge case handling
```

### File Characteristics:
- **No Meta Attributes**: Only `BrainCore.php` has `#[Meta()]` attribute; all others use only `#[Purpose()]`
- **No XML References**: All cross-references use descriptive names (e.g., "context analysis" not "context-analysis.xml")
- **English Only**: All Purpose attributes and content in English
- **Consistent Structure**: All extend `BrainArchetype`, implement `handle()` method
- **Standalone Design**: Each file is self-contained but designed to merge into unified XML structure

## Universal Architecture Files
Located in `core/src/Includes/Universal/`, these files define shared instructions for both Brain and all agents:

### Universal Structure Files (9 total):
1. **AgentLifecycleFramework.php** - Standardized 4-phase lifecycle (creation, validation, optimization, maintenance)
2. **CoreConstraints.php** - System-wide non-negotiable constraints and safety limits
3. **ErrorRecovery.php** - Standardized error detection, reaction, and fallback mechanisms
4. **InstructionWritingStandards.php** - Unified standard for authoring and validating instructions
5. **LaravelBoostGuidelines.php** - Optional Laravel optimization practices and MCP integration
6. **QualityGates.php** - Quality control checkpoints for code, agents, and instruction artifacts
7. **ResponseFormatting.php** - CI validator for response format structure
8. **SequentialReasoningCapability.php** - Multi-phase logical reasoning framework
9. **VectorMasterStorageStrategy.php** - Centralized vector memory architecture

### Recommended Include Order (Universal):
```php
CoreConstraints                  // System constraints first
→ QualityGates                   // Quality requirements
→ InstructionWritingStandards    // Documentation standards
→ ErrorRecovery                  // Error handling
→ AgentLifecycleFramework        // Agent lifecycle
→ SequentialReasoningCapability  // Reasoning framework
→ VectorMasterStorageStrategy    // Memory architecture
→ ResponseFormatting             // Response validation
→ LaravelBoostGuidelines         // Optional Laravel tools
```

### Universal File Characteristics:
- **No Meta Attributes**: All use only `#[Purpose()]` attribute
- **Shared Instructions**: Apply to both Brain orchestrator and all agents
- **No XML References**: All cross-references use descriptive names
- **English Only**: All Purpose attributes and content in English
- **Consistent Structure**: All extend `BrainArchetype`, implement `handle()` method
- **Framework Agnostic**: Universal rules except LaravelBoostGuidelines (optional, framework-specific)

## Key Concepts
- **Archetypes & Blueprints**: Classes under `core/src/Archetypes` and `core/src/Blueprints` extend `Bfg\Dto\Dto`. They provide builder-style APIs (`rule()`, `guideline()`, `style()`, etc.) that populate DTO collections with nested structures.
- **Includes**: Archetypes can include other archetypes via the `include()` method in `BrainNode\Brain`, creating include chains that may nest arbitrarily deep.
- **Merger (`core/src/Merger.php`)**: Flattens the DTO output into a single associative array by recursively following the include chain. It keeps logical ordering (e.g., consecutive `purpose` blocks), merges children using identifiers (`id`, `name`, `order`, `key`), and if an include introduces an intermediate `system` wrapper, that wrapper's children are merged directly into the parent from the bottom up.
- **XML Builder (`core/src/XmlBuilder.php`)**: Converts the merged array into compact XML. It
  - emits no tabs or indentation, only newline separators;
  - self-closes nodes flagged with `single` when empty;
  - escapes text and attribute values (including enums/bools);
  - inserts blank lines between top-level `<system>` children for readability.
- **Testing**: PHPUnit-based tests under `core/tests` cover merge heuristics (`MergerTest`), XML emission constraints (`XmlBuilderTest`), and legacy parity (`LegacyParityTest`).

## Builder API Syntax

### Rules
```php
$this->rule('rule-id')->severity()
    ->text('Rule description')
    ->why('Reason for this rule')
    ->onViolation('Action to take on violation');
```
Severity levels: `->critical()`, `->high()`, `->medium()`, `->low()`

### Guidelines
```php
$this->guideline('guideline-id')
    ->text('Guideline description')
    ->example('Example text');
```

### Guidelines with Phases (for complex workflows)
```php
$this->guideline('phase-name')
    ->text('Goal: Description of phase')
    ->example()
        ->phase('logic-1', 'First logic step')
        ->phase('logic-2', 'Second logic step')
        ->phase('validation-1', 'Validation criterion')
        ->phase('fallback-1', 'Fallback action');
```

### Guidelines with Key-Value Examples
```php
$this->guideline('name')
    ->text('Description')
    ->example('value')->key('key-name')
    ->example('another value')->key('another-key');
```
**IMPORTANT**: Always use `->example('value')->key('key')` format, NOT `->example('key', 'value')`

### Metrics and Integration Lists
```php
$metrics = $this->guideline('metrics-name');
$metrics->example('metric-name >= 0.95');
$metrics->example('another-metric <= 0.05');
```

### Style Configuration
```php
$this->style()
    ->language('English')
    ->tone('Analytical, methodical')
    ->brevity('Medium')
    ->formatting('Strict XML formatting')
    ->forbiddenPhrases()
        ->phrase('sorry')
        ->phrase('unfortunately');
```

### Response Contract
```php
$this->response()->sections()
    ->section('section-name', 'Brief description', true);  // true = required

$this->response()
    ->codeBlocks('Policy for code blocks')
    ->patches('Policy for patches');
```

### Determinism
```php
$this->determinism()
    ->ordering('stable')
    ->randomness('off');
```

## Typical Flow
1. Construct archetype instances (e.g., `BrainNode\Brain`) that include other blueprints in recommended order
2. Call `Merger::from($dto)->handle()` to produce a flattened associative array without `includes` (nested includes are folded recursively)
3. Use `XmlBuilder::from($merged)->build()` to emit final XML aligned with policy formatting requirements

## XML Output Format
- **No tabs/indentation**: Only newline separators (`\n`)
- **Double newlines**: Between top-level `<system>` children for readability
- **Self-closing tags**: Empty nodes flagged with `single` self-close
- **Escaped content**: All text and attribute values properly escaped
- **Enum serialization**: Enumerations (e.g., `IronRuleSeverityEnum`) converted to scalar values
- **Stable ordering**: Maintains semantic grouping (`purpose`, `iron_rules`, `guidelines`, `style`, `response_contract`, `determinism`)

## Notable Requirements
- XML output must avoid tabs and indentation; only newline separators are permitted, with double newlines between top-level system blocks
- Merged structures must maintain stable ordering for semantically grouped nodes (`purpose`, `style`, `response_contract`, etc.), even across nested include chains
- Enumerations (like `IronRuleSeverityEnum`) are serialised to their scalar values when used as attributes
- All cross-references between Brain files use descriptive names (no `.xml` extensions)
- Only `BrainCore.php` contains `#[Meta('id', 'brain-core')]` attribute
- All other Brain files use only `#[Purpose('...')]` attribute

## Legacy XML Files
Original XML policy files located in `core/src/Includes/Brain/Old/*.xml` have been converted to PHP classes. These XML files serve as reference but are no longer actively used - all logic is now in PHP archetype classes.

## Commands
- Install dev tools & dump autoload within `core/`: `composer install`, `composer dump-autoload`
- Run tests: `cd core && ./vendor/bin/phpunit`

Use this document as a quick mental model when extending the agent orchestration logic or integrating additional archetypes.
