<?php

declare(strict_types=1);

namespace BrainNode\Commands;

use BrainCore\Archetypes\AgentArchetype;
use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Compilation\BrainCLI;
use BrainCore\Compilation\Operator;
use BrainCore\Compilation\Runtime;
use BrainCore\Compilation\Store;
use BrainCore\Compilation\Tools\BashTool;
use BrainCore\Compilation\Tools\ReadTool;
use BrainCore\Compilation\Tools\TaskTool;
use BrainCore\Compilation\Tools\WebSearchTool;
use BrainNode\Agents\AgentMaster;
use BrainNode\Agents\ExploreMaster;
use BrainNode\Agents\WebResearchMaster;
use BrainNode\Mcp\VectorMemoryMcp;

#[Meta('id', 'init-agents')]
#[Meta('description', 'Incremental Agent Gap Analyzer - Auto-generates missing domain agents')]
#[Purpose(['Auto-analyze', Runtime::BRAIN_FILE, 'and existing agents → identify gaps → generate missing agents via', BrainCLI::MAKE_MASTER, '→ safe for repeated runs.'])]
class InitAgentsCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {
        // Iron Rules
        $this->rule('no-interactive-questions')->critical()
            ->text('NO interactive questions')
            ->why('Automated workflow for gap analysis and generation')
            ->onViolation('Execute fully automated without user prompts');

        $this->rule('temporal-context-first')->critical()
            ->text(['Temporal context FIRST:', BashTool::call('date')])
            ->why('Ensures up-to-date best practices in generated artifacts')
            ->onViolation('Missing temporal context leads to outdated patterns');

        $this->rule('brain-make-master-only')->critical()
            ->text(['MUST use', BashTool::call(BrainCLI::MASTER_LIST), 'for agent creation - NOT Write() or Edit()'])
            ->why([BrainCLI::MASTER_LIST, 'ensures proper PHP archetype structure and compilation compatibility'])
            ->onViolation('Manually created agents may have structural issues and compilation errors');

        $this->rule('no-regeneration')->critical()
            ->text('No regeneration of existing agents')
            ->why('Idempotent operation safe for repeated execution')
            ->onViolation('Wasted computation and potential conflicts');

        // Phase 1: Get Temporal Context
        $this->guideline('phase1-temporal-context')
            ->goal('Get current date/year for temporal context in agent generation')
            ->example()
            ->phase(BashTool::describe('date +"%Y-%m-%d"', Store::as('CURRENT_DATE')))
            ->phase(BashTool::describe('date +"%Y"', Store::as('CURRENT_YEAR')));

        // Phase 2: Inventory Existing Agents
        $this->guideline('phase2-inventory-agents')
            ->goal('List all existing agents via', BrainCLI::MASTER_LIST)
            ->example()
            ->phase([BashTool::call(BrainCLI::MASTER_LIST), 'Parse output'])
            ->phase(Store::as('EXISTING_AGENTS', '[{id, name, description}, ...]'))
            ->phase(['Agents located in', Runtime::NODE_DIRECTORY('Agents/*.php')]);

        // Phase 3: Extract Project Stack (DELEGATED)
        $this->guideline('phase3-read-project-stack')
            ->goal('Extract project technology stack')
            ->example(
                ExploreMaster::call(Operator::task([
                    Operator::if('no .docs/ found', 'Use Brain context requirements only', 'Explore .docs/ directory. Find all *.md files. Extract: technologies, frameworks, services, domain requirements.'),
                    'Explore existing project files in ./ for tech stack clues (e.g., composer.json, package.json, etc.)',
                    Store::as('PROJECT_STACK', '{technologies: [...], frameworks: [...], services: [...], domain_requirements: [...]}'),
                ]))
            );

        // Phase 4: Gap Analysis
        $this->guideline('phase4-gap-analysis')
            ->goal('Identify missing domain agents')
            ->example()
            ->phase(
                WebResearchMaster::call(
                    Operator::input(
                        Store::get('EXISTING_AGENTS'),
                        Store::get('PROJECT_STACK'),
                        Store::get('CURRENT_YEAR'),
                    ),
                    Operator::task('Gather best practices for agent coverage for the given project stack'),
                    Operator::output('{covered_domains: [...], missing_agents: [{name: \'AgentName\', purpose: \'...\', capabilities: [...]}]}'),
                )
            )
            ->phase(
                AgentMaster::call(
                    Operator::input(
                        Store::get('EXISTING_AGENTS'),
                        Store::get('PROJECT_STACK'),
                        Store::get('CURRENT_YEAR'),
                    ),
                    Operator::task(
                        'Analyze what domain expertise is needed based on Project requirements',
                        'Compare with existing agents',
                        'Identify missing critical agents',
                        Operator::forEach('missing domain', WebSearchTool::describe('{tech} {current_year} best practices')),
                    ),
                    Operator::output('{covered_domains: [...], missing_agents: [{name: \'AgentName\', purpose: \'...\', capabilities: [...]}]}'),
                    Operator::note('Focus on critical domain gaps, not exhaustive coverage'),
                )
            )
            ->phase(Store::as('GAP_ANALYSIS'));

        // Phase 5: Generate Missing Agents
        $this->guideline('phase5-generate-agents')
            ->goal('Create missing agents (sequential, 1 by 1)')
            ->example()
            ->note('Created files must be valid PHP archetypes extending', AgentArchetype::class)
            ->forEach('agent in $GAP_ANALYSIS.missing_agents', [
                Operator::if('agent already exists in $EXISTING_AGENTS', Operator::skip('idempotent')),
                BashTool::describe(BrainCLI::MAKE_MASTER('{AgentName}'), ['Creates', Runtime::NODE_DIRECTORY('Agents/{AgentName}.php')]),
                AgentMaster::call(
                    Operator::task(
                        ReadTool::call(Runtime::NODE_DIRECTORY('Agents/{AgentName}.php')),
                        'Update Purpose attribute based on gap analysis',
                        'Add appropriate includes (Universal + custom if needed)',
                        'Define agent-specific guidelines and capabilities',
                        'Follow existing agent structure (AgentMaster, CommitMaster, etc.)',
                    ),
                    Operator::context('{agent_purpose}, {agent_capabilities} from gap analysis')
                ),
                Operator::report('{completed}/{total} agents generated'),
            ]);

        // Phase 6: Compile Agents
        $this->guideline('phase6-compile')
            ->goal('Compile all agents to', Runtime::AGENTS_FOLDER)
            ->example()
            ->phase(BashTool::describe(BrainCLI::COMPILE, ['Compiles', Runtime::NODE_DIRECTORY('Agents/*.php'), 'to', Runtime::AGENTS_FOLDER]))
            ->phase(Operator::verify(
                Operator::check(Runtime::AGENTS_FOLDER, 'for new agent files')
            ));

        // Phase 7: Report
        $this->guideline('phase7-report')
            ->goal('Report generation results and next steps')
            ->example()
            ->phase()->if('agents_generated > 0', [
                VectorMemoryMcp::call('store_memory', '{content: "Init Gap Analysis: technologies={$PROJECT_STACK.technologies}, agents_generated={agents_count}, coverage=improved, date={$CURRENT_DATE}", category: "architecture", tags: ["init", "gap-analysis", "agents"]}'),
                Operator::output('Generation summary with agent details')
            ])
            ->phase()->if('agents_generated === 0', [
                Operator::output('Full coverage confirmation with existing agent list')
            ]);

        // Response Format - Option A: Agents Generated
        $this->guideline('response-format-a')
            ->text('Response when Agents Generated')
            ->example('Init Gap Analysis Complete')
            ->example('Agents Generated: {agents_count}')
            ->phase('Created in', Runtime::NODE_DIRECTORY('Agents/'))
            ->phase('Compiled to', Runtime::AGENTS_FOLDER)
            ->phase('New domains', '{list_of_new_agent_names}')
            ->example('Coverage Improved:')
            ->phase('Technologies', '{technologies_list}')
            ->phase('Total agents', '{total_agents_count}')
            ->example('Preserved: {existing_agents_count} existing agents')
            ->example('Next Steps:')
            ->phase(['Review generated agents in', Runtime::NODE_DIRECTORY('Agents/')])
            ->phase('Customize agent capabilities if needed')
            ->phase('Recompile: brain compile (if customized)')
            ->phase(['Agents are ready to use via', TaskTool::agent('{name}', '...')]);

        // Response Format - Option B: Full Coverage
        $this->guideline('response-format-b')
            ->text('Response when Full Coverage (no gaps detected)')
            ->example('Init Gap Analysis Complete')
            ->example('Status: Full domain coverage')
            ->example('Existing Agents: {agents_count}')
            ->example('{list_existing_agents_with_descriptions}')
            ->example('Stack Coverage:')
            ->phase('Brain requirements', 'COVERED')
            ->phase('Project stack', '{technologies_list}')
            ->phase('Domain expertise', 'COMPLETE')
            ->example()
            ->do('No new agents needed', 'System ready');

        // Error Recovery
        $this->guideline('error-recovery')
            ->text('Error handling scenarios')
            ->example()
            ->phase()->if('no .docs/ found', ['Use Brain context only', 'Continue with gap analysis'])
            ->phase()->if('agent already exists', [Operator::skip('generation'), 'LOG as preserved', 'Continue with next agent'])
            ->phase()->if([BrainCLI::MAKE_MASTER, 'fails'], ['LOG error', Operator::skip('this agent'), 'Continue with remaining agents'])
            ->phase()->if([BrainCLI::COMPILE, 'fails'], ['Report compilation errors', 'Manual intervention required'])
            ->phase()->if([AgentMaster::id(), 'fails'], ['Report error', 'Suggest manual agent creation'])
            ->phase()->report('{successful_count}/{total_count} agents generated');

        // Quality Gates
        $this->guideline('quality-gates')
            ->text('Quality validation checkpoints')
            ->example('Gate 1: Temporal context retrieved (date/year)')
            ->example('Gate 2: brain master:list executed successfully')
            ->example('Gate 3: Gap analysis completed with valid output structure')
            ->example('Gate 4: brain make:master creates valid PHP archetype')
            ->example('Gate 5: brain compile completes without errors')
            ->example(['Gate 6: Generated agents appear in', Runtime::AGENTS_FOLDER]);

        // Examples
        $this->guideline('example-1')
            ->scenario('.docs/ has Laravel, no Laravel-specific agent exists')
            ->example()
            ->phase('input', 'Existing: AgentMaster, CommitMaster, PmMaster')
            ->phase('analysis', 'Gap detected: Laravel expertise missing')
            ->phase()->name('action')
            ->do(BrainCLI::MAKE_MASTER('LaravelMaster'), ['Edit Purpose', 'Guidelines'], 'Compile')
            ->phase('result', 'LaravelMaster agent available for Laravel tasks');

        $this->guideline('example-2')
            ->scenario('Project uses React, no React agent exists')
            ->example()
            ->phase('input', 'Existing: 7 agents from brain master:list')
            ->phase('analysis', 'Gap detected: React/Frontend expertise missing')
            ->phase('action', Operator::do(BrainCLI::MAKE_MASTER('ReactMaster'), 'Compile'))
            ->phase('result', ['ReactMaster agent available via', TaskTool::agent('react-master', '...')]);

        $this->guideline('example-3')
            ->scenario('Full coverage, all required agents exist')
            ->example()
            ->phase()
            ->name('input')
            ->do(['Brain context', '.docs/ requirements'])
            ->phase('analysis', 'All domains covered by existing agents')
            ->phase()
            ->name('result')
            ->report('"No gaps detected → System ready" with agent list');

        // Directive
        $this->guideline('directive')
            ->text('Generate ONLY missing agents! Preserve existing! Use brain make:master ONLY! Compile after generation! Report coverage!');
    }
}
