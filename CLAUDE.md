# Jarvis Brain Node/Core Overview

## Purpose
The repository contains two closely coupled packages:
- `jarvis-brain/core` – a PHP library that models "brain" directives as DTO-based blueprints and provides tools to compose, merge, and export them.
- `jarvis-brain/node` – an executable node that assembles the core archetypes (e.g., `BrainNode\Brain`) for downstream consumption.

The system formalises behavioural policy for agents as structured data which can then be transformed into deterministic XML without superfluous whitespace. It is intended for orchestrating AI agent behaviour through declarative configuration rather than imperative logic.

## System Architecture

This is a **self-development documentation** for the Brain compilation system itself. This document is used when developing, extending, or debugging the Brain Node/Core architecture.

### Two-Package Design

**jarvis-brain/core** (`./core/`)
- DTO-based archetype system (Archetypes, Blueprints)
- Merger: flattens DTO include chains into single associative array
- XmlBuilder/JsonBuilder/YamlBuilder/TomlBuilder: format-specific output generators
- PHPUnit test suite for merge logic and output validation
- Provides `brain-core` CLI for low-level file operations

**jarvis-brain/node** (`./.brain/node/` aliased as `./node/`)
- Source files: Brain.php, Agents/, Skills/, Commands/, Includes/, Mcp/
- Defines actual agent instructions, skills, commands, and MCP server configurations
- Consumed by `jarvis-brain/cli` during compilation

### Compilation Workflow

```
Source files (.brain/node/*.php)
    ↓
brain compile [target] (default: claude)
    ↓
Scans .brain/node/ directory
    ↓
For each file: brain-core get:file {file} --xml|--json|--yaml|--toml
    ↓
Core transforms PHP DTO → selected format
    ↓
CLI compiler generates target-specific files:
    - .claude/CLAUDE.md (Brain instructions)
    - .claude/agents/*.md (Agent instructions)
    - .claude/skills/*.md (Skill instructions)
    - .claude/commands/*.sh (Slash commands)
    - .mcp.json (MCP server configurations)
```

### Compilation Variables

The compilation system supports platform-agnostic variables that are replaced during compilation. These variables enable cross-platform compatibility by avoiding hardcoded platform-specific paths.

**Available Variables:**

| Variable | Description | Example Value (claude target) |
|----------|-------------|-------------------------------|
| `{{ PROJECT_DIRECTORY }}` | Root project directory path | `/Users/xsaven/PhpstormProjects/jarvis-brain-node` |
| `{{ BRAIN_DIRECTORY }}` | Brain directory | `.brain/` |
| `{{ NODE_DIRECTORY }}` | Brain source directory | `.brain/node/` |
| `{{ BRAIN_FILE }}` | Compiled brain instructions file | `.claude/CLAUDE.md` |
| `{{ BRAIN_FOLDER }}` | Compiled brain output folder | `.claude/` |
| `{{ AGENTS_FOLDER }}` | Compiled agents output folder | `.claude/agents/` |
| `{{ COMMANDS_FOLDER }}` | Compiled commands output folder | `.claude/commands/` |
| `{{ SKILLS_FOLDER }}` | Compiled skills output folder | `.claude/skills/` |
| `{{ MCP_FILE }}` | MCP configuration file path | `.mcp.json` |
| `{{ AGENT }}` | Current compilation target | `claude` / `codex` / `qwen` / `gemini` |
| `{{ DATE }}` | Current date | `2025-11-03` |
| `{{ DATE_TIME }}` | Current date and time | `2025-11-03 15:45:30` |
| `{{ TIME }}` | Current time | `15:45:30` |
| `{{ YEAR }}` | Current year | `2025` |
| `{{ MONTH }}` | Current month | `11` |
| `{{ DAY }}` | Current day | `03` |
| `{{ TIMESTAMP }}` | Unix timestamp | `1730654730` |
| `{{ UNIQUE_ID }}` | Unique compilation session ID | `6727d3fa2b4c8` |

**Usage Examples:**

```php
// In any archetype file (.brain/node/**/*.php)

// Reference brain instructions file (platform-agnostic)
$this->guideline('documentation')
    ->text('Review {{ BRAIN_FILE }} for architecture standards');

// Reference source directories
$this->guideline('agents-location')
    ->text('Agent source files located in {{ NODE_DIRECTORY }}/Agents/');

// Reference compiled output directories
$this->guideline('output-location')
    ->text('Compiled agents will be in {{ AGENTS_FOLDER }}');

// Use temporal variables
$this->guideline('version-info')
    ->text('Compiled on {{ DATE }} at {{ TIME }}');

// Platform-specific logic
$this->guideline('platform-check')
    ->text('Current target platform: {{ AGENT }}');
```

**Multi-Target Example:**

When compiling for different targets, variables automatically adjust:

```bash
# Compile for Claude
brain compile claude
# {{ BRAIN_FILE }} → .claude/CLAUDE.md
# {{ AGENTS_FOLDER }} → .claude/agents/

# Compile for Codex
brain compile codex
# {{ BRAIN_FILE }} → .codex/CODEX.json
# {{ AGENTS_FOLDER }} → .codex/agents/

# Compile for Qwen
brain compile qwen
# {{ BRAIN_FILE }} → .qwen/QWEN.yaml
# {{ AGENTS_FOLDER }} → .qwen/agents/
```

**Best Practices:**

1. **Always use variables** instead of hardcoded paths for platform-agnostic code
2. **Avoid platform-specific names** like `.claude/` or `CLAUDE.md` in agent instructions
3. **Use `{{ BRAIN_FILE }}`** when referencing brain documentation
4. **Use `{{ NODE_DIRECTORY }}`** when referencing source files
5. **Use `{{ AGENTS_FOLDER }}`** when referencing compiled agent output
6. **Use temporal variables** (`{{ DATE }}`, `{{ YEAR }}`) for version tracking or temporal context

### Directory Structure

```
./
├── .brain/               # Hidden source directory (development mode)
│   ├── node/            # Aliased as ./node/ in composer autoload
│   │   ├── Brain.php    # Main orchestrator
│   │   ├── Agents/      # Agent definitions
│   │   ├── Skills/      # Reusable skill modules
│   │   ├── Commands/    # User slash commands
│   │   ├── Includes/    # Compile-time instruction fragments
│   │   └── Mcp/         # MCP server configurations
│   ├── vendor/          # Core package dependencies
│   │   └── bin/
│   │       └── brain-core  # Low-level DTO compiler
│   └── composer.json    # Node package definition
├── core/                # Core package (symlinked in .brain/vendor/)
│   ├── src/
│   │   ├── Archetypes/  # Base DTO classes
│   │   ├── Blueprints/  # Builder API implementations
│   │   ├── Includes/    # Standard instruction libraries
│   │   │   ├── Brain/   # Brain-specific modules
│   │   │   └── Universal/ # Shared across Brain + Agents
│   │   ├── Merger.php   # Include chain flattener
│   │   └── XmlBuilder.php # XML output generator
│   └── tests/           # PHPUnit test suite
├── .claude/             # Compiled output (generated, do not edit)
│   ├── CLAUDE.md        # Compiled Brain instructions
│   ├── agents/          # Compiled agent instructions
│   ├── skills/          # Compiled skill instructions
│   └── commands/        # Generated slash commands
├── .mcp.json            # Compiled MCP server configs
├── memory/              # Vector storage (MCP-only access)
├── CLAUDE.md            # This file (self-dev documentation)
└── composer.json        # Global dev dependencies
```

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

## Development Workflow

### CLI Commands

**Global CLI: `brain` (jarvis-brain/cli)**
```bash
# Compile all source files to default target (claude)
brain compile

# Compile to specific target
brain compile codex
brain compile qwen
brain compile gemini

# Initialize new Brain project
brain init

# Generate new components
brain make:master     # Create new agent in .brain/node/Agents/
brain make:skill      # Create new skill in .brain/node/Skills/
brain make:command    # Create new command in .brain/node/Commands/
brain make:include    # Create new include in .brain/node/Includes/
brain make:mcp        # Create new MCP config in .brain/node/Mcp/

# Show available commands
brain list
```

**Core CLI: `brain-core` (.brain/vendor/bin/brain-core)**
```bash
# Low-level file compilation (used internally by brain compile)
brain-core get:file .brain/node/Brain.php --xml
brain-core get:file .brain/node/Agents/AgentMaster.php --json
brain-core get:file .brain/node/Skills/TestSkill.php --yaml
brain-core get:file .brain/node/Mcp/VectorMemoryMcp.php --json

# Show available commands
brain-core list
```

### Development Setup

**Install jarvis-brain/cli globally (dev mode with symlink):**
```bash
# Add local CLI repository to global composer
composer global config repositories.jarvis-brain-cli path /path/to/jarvis-brain-cli

# Install globally with symlink
composer global require jarvis-brain/cli:^v0.0.1
```

**Core package setup (already configured in .brain/composer.json):**
```json
{
  "repositories": [{
    "type": "path",
    "url": "core"
  }],
  "require": {
    "jarvis-brain/core": "^v0.0.1"
  }
}
```

### Testing

**Core package tests:**
```bash
cd core
composer install
./vendor/bin/phpunit

# Specific test suites
./vendor/bin/phpunit tests/MergerTest.php
./vendor/bin/phpunit tests/XmlBuilderTest.php
./vendor/bin/phpunit tests/LegacyParityTest.php
```

## Node Architecture Types

### Brain (.brain/node/Brain.php)

**Purpose:** Main orchestrator that delegates tasks to specialized agents.

**Compilation output:** `.claude/CLAUDE.md`

**Key characteristics:**
- Includes Universal includes (CoreConstraints, QualityGates, etc.)
- Includes Brain-specific includes (BrainCore, DelegationProtocols, etc.)
- Defines orchestration rules and response contract
- NEVER executes tasks directly (delegation only)

**Builder API example:**
```php
namespace BrainNode;

use Core\Archetypes\BrainArchetype;

class Brain extends BrainArchetype
{
    public function handle(): void
    {
        // Include universal constraints
        $this->include(CoreConstraints::class);
        $this->include(QualityGates::class);

        // Include brain-specific modules
        $this->include(BrainCore::class);
        $this->include(DelegationProtocols::class);

        // Define brain-specific rules
        $this->rule('delegation-only')->critical()
            ->text('Brain must delegate, never execute directly')
            ->why('Maintains separation between orchestration and execution')
            ->onViolation('Trigger correction protocol');
    }
}
```

### Agents (.brain/node/Agents/*.php)

**Purpose:** Specialized autonomous units that execute delegated tasks.

**Compilation output:** `.claude/agents/{agent-name}.md`

**Key characteristics:**
- Can include Universal includes (ErrorRecovery, SequentialReasoning, etc.)
- Can include custom Includes for shared logic
- Define agent-specific capabilities and constraints
- Invoked by Brain via Task tool with compiled instructions

**Builder API example:**
```php
namespace BrainNode\Agents;

use Core\Archetypes\AgentArchetype;

class LaravelMaster extends AgentArchetype
{
    public function handle(): void
    {
        // Include universal frameworks
        $this->include(ErrorRecovery::class);
        $this->include(SequentialReasoningCapability::class);

        // Include Laravel-specific helpers
        $this->include(LaravelBoostGuidelines::class);

        // Define agent capabilities
        $this->guideline('laravel-expertise')
            ->text('Expert in Laravel best practices and architecture')
            ->example('Uses service containers and dependency injection')
            ->example('Follows repository pattern for data access');
    }
}
```

### Skills (.brain/node/Skills/*.php)

**Purpose:** Reusable capability modules invoked by agents or Brain.

**Compilation output:** `.claude/skills/{skill-name}.md`

**Key characteristics:**
- Smaller, focused instruction sets
- Can be shared across multiple agents
- Avoid duplication of common procedures
- Used when same logic needed in multiple contexts

**Builder API example:**
```php
namespace BrainNode\Skills;

use Core\Archetypes\SkillArchetype;

class DtoHandling extends SkillArchetype
{
    public function handle(): void
    {
        $this->guideline('dto-validation')
            ->text('Validate DTO structure before processing')
            ->example('Check required properties exist')
            ->example('Validate property types match schema');

        $this->guideline('dto-transformation')
            ->text('Transform DTOs using builder API')
            ->example('Use ->toArray() for array conversion')
            ->example('Use ->toJson() for JSON serialization');
    }
}
```

**Usage pattern:**
```
Brain delegates to LaravelMaster agent
  → Agent needs DTO handling logic
  → Agent invokes DtoHandling skill
  → Skill provides standardized procedures
```

### Commands (.brain/node/Commands/*.php)

**Purpose:** User-facing slash commands for Claude Code interface.

**Compilation output:** `.claude/commands/{command-name}.sh` or `.claude/commands/{command-name}.md`

**Key characteristics:**
- Define user-invocable workflows
- May trigger agent delegation or Brain orchestration
- Provide structured interfaces for common tasks
- NOT for internal agent-to-agent communication

**Builder API example:**
```php
namespace BrainNode\Commands;

use Core\Archetypes\CommandArchetype;

class AnalyzeArchitecture extends CommandArchetype
{
    public function handle(): void
    {
        $this->description('Analyze codebase architecture and generate report');

        $this->guideline('execution-flow')
            ->text('Delegate to Explore agent for discovery')
            ->example()
                ->phase('step-1', 'Scan project structure')
                ->phase('step-2', 'Identify patterns and violations')
                ->phase('step-3', 'Generate architectural report');
    }
}
```

**User invocation:** `/analyze-architecture`

### Includes (.brain/node/Includes/*.php)

**Purpose:** Compile-time instruction fragments merged into target archetypes.

**Compilation output:** NONE (merged into Brain/Agents/Skills during compilation)

**Key characteristics:**
- Avoid duplication across multiple targets
- Support recursive includes (max depth: 255)
- Disappear after compilation (zero runtime footprint)
- Used via `$this->include(IncludeName::class)` in other archetypes

**Builder API example:**
```php
namespace BrainNode\Includes;

use Core\Archetypes\IncludeArchetype;

class ContextAwareness extends IncludeArchetype
{
    public function handle(): void
    {
        $this->guideline('temporal-context')
            ->text('Always consider current date and technology evolution')
            ->example('Check if libraries are deprecated')
            ->example('Verify compatibility with current PHP version');

        $this->guideline('project-context')
            ->text('Understand project structure before making changes')
            ->example('Read composer.json for dependencies')
            ->example('Scan directory structure for conventions');
    }
}
```

**Compile-time transformation:**
```php
// Source: Brain.php
$this->include(ContextAwareness::class);

// After compilation: .claude/CLAUDE.md
<guidelines>
  <guideline id="temporal-context">
    <text>Always consider current date and technology evolution</text>
    <example>Check if libraries are deprecated</example>
    <example>Verify compatibility with current PHP version</example>
  </guideline>
  <guideline id="project-context">
    <text>Understand project structure before making changes</text>
    <example>Read composer.json for dependencies</example>
    <example>Scan directory structure for conventions</example>
  </guideline>
</guidelines>
```

### Mcp (.brain/node/Mcp/*.php)

**Purpose:** MCP server configuration definitions.

**Compilation output:** `.mcp.json` (merged all MCP configs)

**Key characteristics:**
- NOT archetypes (different architecture)
- Define MCP server connection parameters
- Transformed to JSON structure for `.mcp.json`
- Accessed via `brain-core get:file --json`

**Builder API example:**
```php
namespace BrainNode\Mcp;

use Core\Blueprints\McpBlueprint;

class VectorMemoryMcp extends McpBlueprint
{
    public function handle(): void
    {
        $this->id('vector-memory-mcp');
        $this->type('stdio');
        $this->command('uvx');
        $this->args([
            'vector-memory-mcp',
            '--working-dir',
            '/Users/xsaven/PhpstormProjects/jarvis-brain-node'
        ]);
    }
}
```

**Compilation output in .mcp.json:**
```json
{
  "mcpServers": {
    "vector-memory-mcp": {
      "type": "stdio",
      "command": "uvx",
      "args": [
        "vector-memory-mcp",
        "--working-dir",
        "/Users/xsaven/PhpstormProjects/jarvis-brain-node"
      ]
    }
  }
}
```

## Include System

### Compile-Time Merging

Includes are **NOT runtime entities**. They are instruction fragments that merge into target archetypes during compilation.

**Mental model:**
```
┌─────────────────────────────────────────────────────┐
│ SOURCE TIME (before compilation)                    │
├─────────────────────────────────────────────────────┤
│ Brain.php:                                          │
│   ->include(CoreConstraints)                        │
│   ->include(BrainCore)                              │
│   ->rule('delegation-only')                         │
│                                                     │
│ LaravelMaster.php:                                  │
│   ->include(CoreConstraints)  # Same include!      │
│   ->include(ErrorRecovery)                          │
│   ->guideline('laravel-expertise')                  │
└─────────────────────────────────────────────────────┘
                    ↓
            brain compile claude
                    ↓
┌─────────────────────────────────────────────────────┐
│ COMPILE TIME (merger flattens includes)            │
├─────────────────────────────────────────────────────┤
│ Merger processes Brain.php:                         │
│   1. Read CoreConstraints content                   │
│   2. Read BrainCore content                         │
│   3. Merge all content into single structure        │
│   4. Add Brain's own rules                          │
│   5. Output flattened array                         │
│                                                     │
│ Merger processes LaravelMaster.php:                 │
│   1. Read CoreConstraints content (again)           │
│   2. Read ErrorRecovery content                     │
│   3. Merge all content into single structure        │
│   4. Add LaravelMaster's own guidelines             │
│   5. Output flattened array                         │
└─────────────────────────────────────────────────────┘
                    ↓
            XmlBuilder/JsonBuilder
                    ↓
┌─────────────────────────────────────────────────────┐
│ RUNTIME (compiled output)                           │
├─────────────────────────────────────────────────────┤
│ .claude/CLAUDE.md:                                  │
│   <system>                                          │
│     <iron_rules>                                    │
│       <!-- CoreConstraints rules -->                │
│       <!-- BrainCore rules -->                      │
│       <!-- Brain's own rules -->                    │
│     </iron_rules>                                   │
│   </system>                                         │
│                                                     │
│ .claude/agents/laravel-master.md:                   │
│   <system>                                          │
│     <iron_rules>                                    │
│       <!-- CoreConstraints rules -->                │
│       <!-- ErrorRecovery rules -->                  │
│     </iron_rules>                                   │
│     <guidelines>                                    │
│       <!-- LaravelMaster's guidelines -->           │
│     </guidelines>                                   │
│   </system>                                         │
│                                                     │
│ NOTE: "Include" as concept does NOT exist here!     │
└─────────────────────────────────────────────────────┘
```

### Recursive Includes

Includes can include other includes up to 255 levels deep.

**Example:**
```php
// CoreConstraints.php includes QualityGates.php
class CoreConstraints extends IncludeArchetype
{
    public function handle(): void
    {
        $this->include(QualityGates::class);  // Recursive include
        $this->rule('token-limit')->high()->text('...');
    }
}

// Brain.php includes CoreConstraints
class Brain extends BrainArchetype
{
    public function handle(): void
    {
        $this->include(CoreConstraints::class);  // Will also pull QualityGates
    }
}
```

**Merger resolves recursively:**
```
Brain.php
  ├─ CoreConstraints
  │   └─ QualityGates
  └─ Brain's own content

Flattened output:
  1. QualityGates content
  2. CoreConstraints content
  3. Brain content
```

### DRY Principle

Includes exist to avoid duplication of common instruction blocks.

**Without Includes (duplication):**
```php
// Brain.php
$this->rule('token-limit')->high()->text('Max 1200 tokens');

// LaravelMaster.php
$this->rule('token-limit')->high()->text('Max 1200 tokens');  // Duplicate!

// TestMaster.php
$this->rule('token-limit')->high()->text('Max 1200 tokens');  // Duplicate!
```

**With Includes (DRY):**
```php
// CoreConstraints.php (Include)
$this->rule('token-limit')->high()->text('Max 1200 tokens');

// Brain.php
$this->include(CoreConstraints::class);  // Reuse

// LaravelMaster.php
$this->include(CoreConstraints::class);  // Reuse

// TestMaster.php
$this->include(CoreConstraints::class);  // Reuse
```

**Update propagation:**
Change CoreConstraints once → recompile → all targets updated automatically.

## Multi-Target Support

### Target-Specific Compilation

Different AI platforms require different instruction formats and styles.

**Supported targets:**
- `claude` (default) – Claude Code / Sonnet / Opus
- `codex` – OpenAI Codex / GPT-4
- `qwen` – Alibaba Qwen models
- `gemini` – Google Gemini models

**Target-specific transformations:**

| Aspect | Claude | Codex | Qwen | Gemini |
|--------|--------|-------|------|--------|
| Format | XML (compact) | JSON | YAML | JSON |
| Tone | Analytical, methodical | Direct, imperative | Conversational | Structured |
| Brevity | Medium | High | Low | Medium |
| Examples | Extensive | Minimal | Contextual | Structured |

### Compilation Command

```bash
# Default target (claude)
brain compile

# Specific target
brain compile codex
brain compile qwen
brain compile gemini
```

### Target Detection

Compiler determines output format based on target:
- `claude` → XmlBuilder → `.claude/CLAUDE.md`
- `codex` → JsonBuilder → `.codex/CODEX.json`
- `qwen` → YamlBuilder → `.qwen/QWEN.yaml`
- `gemini` → JsonBuilder → `.gemini/GEMINI.json`

### Format Transformation

**Source (same PHP DTO for all targets):**
```php
$this->rule('delegation-only')->critical()
    ->text('Brain must delegate, never execute')
    ->why('Separation of concerns')
    ->onViolation('Trigger correction protocol');
```

**Claude output (XML):**
```xml
<rule id="delegation-only" severity="critical">
  <text>Brain must delegate, never execute</text>
  <why>Separation of concerns</why>
  <on_violation>Trigger correction protocol</on_violation>
</rule>
```

**Codex output (JSON):**
```json
{
  "rules": [{
    "id": "delegation-only",
    "severity": "critical",
    "text": "Brain must delegate, never execute",
    "why": "Separation of concerns",
    "onViolation": "Trigger correction protocol"
  }]
}
```

**Qwen output (YAML):**
```yaml
rules:
  - id: delegation-only
    severity: critical
    text: Brain must delegate, never execute
    why: Separation of concerns
    onViolation: Trigger correction protocol
```

## Memory Architecture

### Vector Storage

**Physical location:** `./memory/` (SQLite database)

**Access policy:** MCP-only (NEVER direct file access)

**Critical rule:** ALL memory operations MUST go through MCP tool `vector-memory`.

### MCP-Only Access

**Correct usage:**
```
Brain/Agent needs to store knowledge
  ↓
Invoke MCP tool: mcp__vector-memory__store_memory(content, category, tags)
  ↓
MCP server handles SQLite operations
  ↓
Vector embedded and stored in ./memory/
```

**Prohibited usage:**
```
❌ Direct SQLite access
❌ File system operations on ./memory/
❌ Manual database queries
```

### Vector Memory MCP Tools

**Available operations:**
- `store_memory(content, category, tags)` – Store new knowledge
- `search_memories(query, limit, category)` – Semantic search
- `list_recent_memories(limit)` – Chronological list
- `get_memory_stats()` – Database statistics
- `clear_old_memories(days_old, max_to_keep)` – Cleanup
- `get_by_memory_id(memory_id)` – Retrieve specific memory
- `delete_by_memory_id(memory_id)` – Delete specific memory

### Master-Replica Topology

**Architecture:**
- **Master node:** Exclusive write access (Brain orchestrator)
- **Replica nodes:** Read-only access with caching (Agents)

**Synchronization:**
- Async replication every 5 minutes
- Eventual consistency window ≤ 10 minutes
- Conflict resolution via version and timestamp

**Access pattern:**
```
Brain (master write)
  ↓
Store critical reasoning output
  ↓
MCP vector-memory master
  ↓
./memory/ (SQLite)
  ↓
Async replication
  ↓
Agent (replica read)
  ↓
Query for relevant context
  ↓
MCP vector-memory replica (cached)
```

### Memory Categories

- `code-solution` – Implementation patterns and solutions
- `bug-fix` – Debugging procedures and fixes
- `architecture` – System design decisions
- `learning` – Acquired knowledge and insights
- `tool-usage` – Tool invocation patterns
- `debugging` – Diagnostic procedures
- `performance` – Optimization strategies
- `security` – Security patterns and checks
- `other` – Uncategorized knowledge

## Self-Dev Guidelines

### When Developing Brain System

This document (./CLAUDE.md) is for developing the Brain compilation system itself, NOT for developing user applications with Brain.

**Use cases:**
- Adding new archetype types
- Modifying compilation pipeline
- Extending multi-target support
- Debugging merge logic
- Writing tests for core functionality
- Updating Builder API

### Key Principles

1. **DTO-First Design:** All archetypes extend `Bfg\Dto\Dto` for type safety
2. **Compile-Time Optimization:** Includes merge at compile time for zero runtime overhead
3. **Format Agnostic:** Same source compiles to XML/JSON/YAML/TOML
4. **Testable Architecture:** PHPUnit tests validate all transformations
5. **Separation of Concerns:**
   - Core: DTO system, merger, builders
   - Node: Instruction definitions
   - CLI: Compilation orchestration

### Development Workflow

**Adding new archetype type:**
```bash
# 1. Create archetype class in core
cd core/src/Archetypes
# Add NewArchetype.php extending BrainArchetype

# 2. Create blueprint helpers if needed
cd ../Blueprints
# Add NewBlueprint.php with builder methods

# 3. Write tests
cd ../../tests
# Add NewArchetypeTest.php

# 4. Run tests
./vendor/bin/phpunit

# 5. Use in node
cd ../../.brain/node
# Create instances using NewArchetype
```

**Modifying compilation output:**
```bash
# 1. Modify builder in core
cd core/src
# Edit XmlBuilder.php or add new builder

# 2. Update tests
cd ../tests
# Update XmlBuilderTest.php

# 3. Run tests
./vendor/bin/phpunit

# 4. Update CLI compiler
cd ~/PhpstormProjects/jarvis-brain-cli
# Modify compile command to use new builder

# 5. Test compilation
cd ~/PhpstormProjects/jarvis-brain-node
brain compile
```

### Testing Strategy

**Core package tests:**
- `MergerTest` – Include chain resolution, recursive merging
- `XmlBuilderTest` – XML formatting, escaping, structure
- `JsonBuilderTest` – JSON structure and validity
- `LegacyParityTest` – Compatibility with old XML files

**Node integration tests:**
```bash
# Compile and verify output
brain compile
diff .claude/CLAUDE.md expected-output.md

# Test specific file
brain-core get:file .brain/node/Brain.php --xml
```

### Common Patterns

**Adding new Universal include:**
```php
// 1. Create in core/src/Includes/Universal/
namespace Core\Includes\Universal;

use Core\Archetypes\BrainArchetype;
use Core\Attributes\Purpose;

#[Purpose('Description of new universal include')]
class NewUniversalInclude extends BrainArchetype
{
    public function handle(): void
    {
        $this->guideline('new-guideline')
            ->text('Guideline text')
            ->example('Example usage');
    }
}

// 2. Include in Brain and/or Agents
namespace BrainNode;

class Brain extends BrainArchetype
{
    public function handle(): void
    {
        $this->include(NewUniversalInclude::class);
        // ... rest of Brain definition
    }
}
```

**Adding new Brain-specific include:**
```php
// 1. Create in core/src/Includes/Brain/
namespace Core\Includes\Brain;

use Core\Archetypes\BrainArchetype;
use Core\Attributes\Purpose;

#[Purpose('Description of brain-specific include')]
class NewBrainInclude extends BrainArchetype
{
    public function handle(): void
    {
        $this->rule('new-rule')->high()
            ->text('Rule text')
            ->why('Reason')
            ->onViolation('Action');
    }
}

// 2. Include only in Brain (not agents)
namespace BrainNode;

class Brain extends BrainArchetype
{
    public function handle(): void
    {
        $this->include(NewBrainInclude::class);
        // ... rest of Brain definition
    }
}
```

## Commands Reference

### Development Commands
```bash
# Core package
cd core
composer install              # Install dependencies
composer dump-autoload        # Regenerate autoloader
./vendor/bin/phpunit          # Run all tests
./vendor/bin/phpunit --filter MergerTest  # Run specific test

# Node package
cd .brain
composer install              # Install dependencies (includes core)
composer dump-autoload        # Regenerate autoloader

# Brain CLI
brain init                    # Initialize new Brain project
brain compile                 # Compile to default target (claude)
brain compile codex           # Compile to specific target
brain list                    # List available commands

# Brain Core
brain-core get:file {file} --xml   # Get file as XML
brain-core get:file {file} --json  # Get file as JSON
brain-core list               # List available commands

# Generators
brain make:skill SkillName    # Create new skill
brain make:command CmdName    # Create new command
brain make:include IncludeName # Create new include
brain make:mcp McpName        # Create new MCP config
brain make:master MasterName  # Create new agent master
```

### File Structure
- `./core/` – Core DTO system and builders
- `./.brain/node/` – Source files for compilation
- `./.brain/vendor/` – Core package and dependencies
- `./.claude/` – Compiled Claude Code output
- `./memory/` – Vector storage (MCP-only access)
- `./CLAUDE.md` – This self-dev documentation
- `./.brain/CLAUDE.md` – Duplicate for IDE discoverability

Use this document as a comprehensive reference when developing, extending, or debugging the Jarvis Brain Node/Core compilation system.
