<?php

declare(strict_types=1);

namespace BrainNode\Commands;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;

#[Meta('id', 'init')]
#[Meta('description', 'Incremental Agent Gap Analyzer - Auto-generates missing domain agents')]
#[Purpose('Auto-analyze CLAUDE.md and existing agents → identify gaps → generate missing agents via brain make:master → safe for repeated runs.')]
class InitCommand extends CommandArchetype
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
            ->text('Temporal context FIRST (Bash date)')
            ->why('Ensures up-to-date best practices in generated artifacts')
            ->onViolation('Missing temporal context leads to outdated patterns');

        $this->rule('brain-make-master-only')->critical()
            ->text('MUST use brain make:master for agent creation - NOT Write() or Edit()')
            ->why('brain make:master ensures proper PHP archetype structure and compilation compatibility')
            ->onViolation('Manually created agents may have structural issues and compilation errors');

        $this->rule('preserve-existing')->critical()
            ->text('Preserve all existing agents in .brain/node/Agents/')
            ->why('Incremental approach prevents destructive overwrites')
            ->onViolation('Data loss and broken references');

        $this->rule('no-regeneration')->critical()
            ->text('No regeneration of existing agents')
            ->why('Idempotent operation safe for repeated execution')
            ->onViolation('Wasted computation and potential conflicts');

        // Usage
        $this->guideline('when-to-use')
            ->text('Run repeatedly: new stack added OR .docs/ updated OR periodic audit. Format: /init (no arguments needed)');

        // Workflow Overview
        $this->guideline('workflow-overview')
            ->text('Critical flow: Delegate context analysis → Inventory agents → Gap analysis → Generate missing via brain make:master → Compile')
            ->example()
                ->phase('step-1', 'Bash: Get current date/year for temporal context')
                ->phase('step-2', 'Bash: brain master:list → Parse existing agents from {{ NODE_DIRECTORY }}Agents/')
                ->phase('step-3', 'Task(@agent-agent-master, "Analyze Brain architecture from context. Return requirements.")')
                ->phase('step-4', 'Task(@agent-explore, "Explore .docs/ directory. Return tech stack and domain requirements.")')
                ->phase('step-5', 'Task(@agent-agent-master, "Gap analysis: Compare requirements vs existing agents. Return missing agents list.")')
                ->phase('step-6', 'FOR EACH missing agent: Bash: brain make:master {AgentName} → Create in {{ NODE_DIRECTORY }}Agents/')
                ->phase('step-7', 'Bash: brain compile → Compile all agents to {{ AGENTS_FOLDER }}')
                ->phase('step-8', 'Report: agents_generated + coverage + next_steps');

        // Phase 1: Get Temporal Context
        $this->guideline('phase1-temporal-context')
            ->text('Goal: Get current date/year for temporal context in agent generation')
            ->example()
                ->phase('action-1', 'Bash: date +"%Y-%m-%d" → Store as $CURRENT_DATE')
                ->phase('action-2', 'Bash: date +"%Y" → Store as $CURRENT_YEAR');

        // Phase 2: Inventory Existing Agents
        $this->guideline('phase2-inventory-agents')
            ->text('Goal: List all existing agents via brain master:list')
            ->example()
                ->phase('action-1', 'Bash: brain master:list → Parse output')
                ->phase('store-1', 'Store as $EXISTING_AGENTS = [{id, name, description}, ...]')
                ->phase('note-1', 'Agents located in {{ NODE_DIRECTORY }}Agents/*.php');

        // Phase 3: Extract Brain Requirements (from context)
        $this->guideline('phase3-extract-brain-requirements')
            ->text('Goal: Extract Brain architecture requirements via @agent-agent-master')
            ->example()
                ->phase('action-1', 'Task(@agent-agent-master, "Analyze Brain architecture from loaded context. Extract: orchestration model, delegation hierarchy, validation requirements, agent types. Return $BRAIN_REQUIREMENTS.")')
                ->phase('store-1', 'Store as $BRAIN_REQUIREMENTS = {orchestration, delegation, validation, agent_types}');

        // Phase 4: Extract Project Stack (DELEGATED)
        $this->guideline('phase4-read-project-stack')
            ->text('Goal: Extract project technology stack via @agent-explore (DELEGATE exploration, never Glob/Read directly)')
            ->example()
                ->phase('action-1', 'Task(@agent-explore, "Explore .docs/ directory. Find all *.md files. Extract: technologies, frameworks, services, domain requirements. Return structured $PROJECT_STACK.")')
                ->phase('store-1', 'Store as $PROJECT_STACK = {technologies: [...], frameworks: [...], services: [...], domain_requirements: [...]}')
                ->phase('fallback-1', 'If no .docs/ found → Use Brain context requirements only')
                ->phase('note-1', 'NEVER use Glob/Read directly - delegate to Explore agent');

        // Phase 5: Gap Analysis
        $this->guideline('phase5-gap-analysis')
            ->text('Goal: Identify missing domain agents via @agent-agent-master')
            ->example()
                ->phase('delegation-1', 'Task(@agent-agent-master, "Gap Analysis:\n\nINPUT:\n- Existing agents: $EXISTING_AGENTS\n- Brain requirements: $BRAIN_REQUIREMENTS\n- Project stack: $PROJECT_STACK\n- Current year: $CURRENT_YEAR\n\nTASK:\n1. Analyze what domain expertise is needed based on Brain + Project requirements\n2. Compare with existing agents\n3. Identify missing critical agents\n4. Research: \'{tech} {current_year} best practices\' for each missing domain\n\nOUTPUT:\n{covered_domains: [...], missing_agents: [{name: \'AgentName\', purpose: \'...\', capabilities: [...]}]}\n\nNOTE: Focus on critical domain gaps, not exhaustive coverage")')
                ->phase('store-1', 'Store analysis result as $GAP_ANALYSIS');

        // Phase 6: Generate Missing Agents
        $this->guideline('phase6-generate-agents')
            ->text('Goal: Create missing agents via brain make:master (sequential, 1 by 1)')
            ->example()
                ->phase('strategy-1', 'SEQUENTIAL execution (NOT parallel) - brain make:master cannot run in parallel')
                ->phase('loop-1', 'FOR EACH agent in $GAP_ANALYSIS.missing_agents:')
                ->phase('check-1', 'IF agent already exists in $EXISTING_AGENTS → SKIP (idempotent)')
                ->phase('generate-1', 'Bash: brain make:master {AgentName} → Creates {{ NODE_DIRECTORY }}Agents/{AgentName}.php')
                ->phase('edit-1', 'Task(@agent-agent-master, "Edit {{ NODE_DIRECTORY }}Agents/{AgentName}.php:\n\n1. Update Purpose attribute based on gap analysis\n2. Add appropriate includes (Universal + custom if needed)\n3. Define agent-specific guidelines and capabilities\n4. Follow existing agent structure (AgentMaster, CommitMaster, etc.)\n\nContext: {agent_purpose}, {agent_capabilities} from gap analysis")')
                ->phase('progress-1', 'Report progress: {completed}/{total} agents generated')
                ->phase('note-1', 'Created files must be valid PHP archetypes extending AgentArchetype');

        // Phase 7: Compile Agents
        $this->guideline('phase7-compile')
            ->text('Goal: Compile all agents to {{ AGENTS_FOLDER }}')
            ->example()
                ->phase('action-1', 'Bash: brain compile → Compiles {{ NODE_DIRECTORY }}Agents/*.php to {{ AGENTS_FOLDER }}')
                ->phase('verify-1', 'Verify compilation success → Check {{ AGENTS_FOLDER }} for new agent files');

        // Phase 8: Report
        $this->guideline('phase8-report')
            ->text('Goal: Report generation results and next steps')
            ->example()
                ->phase('condition-1', 'IF agents_generated > 0:')
                ->phase('action-1', 'mcp__vector-memory__store_memory({content: "Init Gap Analysis: technologies={$PROJECT_STACK.technologies}, agents_generated={agents_count}, coverage=improved, date={$CURRENT_DATE}", category: "architecture", tags: ["init", "gap-analysis", "agents"]})')
                ->phase('response-1', 'Output: Generation summary with agent details')
                ->phase('condition-2', 'IF agents_generated === 0:')
                ->phase('response-2', 'Output: Full coverage confirmation with existing agent list');

        // Response Format - Option A: Agents Generated
        $this->guideline('response-format-a')
            ->text('Response when Agents Generated')
            ->example('✅ Init Gap Analysis Complete')
            ->example('')
            ->example('Agents Generated: {agents_count}')
            ->example('├─ Created in: {{ NODE_DIRECTORY }}Agents/')
            ->example('├─ Compiled to: {{ AGENTS_FOLDER }}')
            ->example('└─ New domains: {list_of_new_agent_names}')
            ->example('')
            ->example('Coverage Improved:')
            ->example('├─ Technologies: {technologies_list}')
            ->example('└─ Total agents: {total_agents_count}')
            ->example('')
            ->example('Preserved: {existing_agents_count} existing agents')
            ->example('')
            ->example('Next Steps:')
            ->example('1. Review generated agents in {{ NODE_DIRECTORY }}Agents/')
            ->example('2. Customize agent capabilities if needed')
            ->example('3. Recompile: brain compile (if customized)')
            ->example('4. Agents are ready to use via Task(@agent-{name}, "...")');

        // Response Format - Option B: Full Coverage
        $this->guideline('response-format-b')
            ->text('Response when Full Coverage (no gaps detected)')
            ->example('✅ Init Gap Analysis Complete')
            ->example('')
            ->example('Status: Full domain coverage')
            ->example('')
            ->example('Existing Agents: {agents_count}')
            ->example('{list_existing_agents_with_descriptions}')
            ->example('')
            ->example('Stack Coverage:')
            ->example('├─ Brain requirements: COVERED')
            ->example('├─ Project stack: {technologies_list}')
            ->example('└─ Domain expertise: COMPLETE')
            ->example('')
            ->example('No new agents needed → System ready');

        // Error Recovery
        $this->guideline('error-recovery')
            ->text('Error handling scenarios')
            ->example()
                ->phase('no-docs', 'IF no .docs/ found → Use Brain context only → Continue with gap analysis')
                ->phase('agent-exists', 'IF agent already exists → SKIP generation → LOG as preserved → Continue with next agent')
                ->phase('brain-make-fails', 'IF brain make:master fails → LOG error → Skip this agent → Continue with remaining agents')
                ->phase('compilation-fails', 'IF brain compile fails → Report compilation errors → Manual intervention required')
                ->phase('gap-analysis-fails', 'IF @agent-agent-master fails → Report error → Suggest manual agent creation')
                ->phase('final-report', 'Always report: {successful_count}/{total_count} agents generated');

        // Quality Gates
        $this->guideline('quality-gates')
            ->text('Quality validation checkpoints')
            ->example('Gate 1: Temporal context retrieved (date/year)')
            ->example('Gate 2: brain master:list executed successfully')
            ->example('Gate 3: Gap analysis completed with valid output structure')
            ->example('Gate 4: brain make:master creates valid PHP archetype')
            ->example('Gate 5: brain compile completes without errors')
            ->example('Gate 6: Generated agents appear in {{ AGENTS_FOLDER }}');

        // Examples
        $this->guideline('example-1')
            ->text('Scenario: .docs/ has Laravel, no Laravel-specific agent exists')
            ->example()
                ->phase('input', 'Existing: AgentMaster, CommitMaster, PmMaster')
                ->phase('analysis', 'Gap detected: Laravel expertise missing')
                ->phase('action', 'brain make:master LaravelMaster → Edit Purpose + Guidelines → Compile')
                ->phase('result', 'LaravelMaster agent available for Laravel tasks');

        $this->guideline('example-2')
            ->text('Scenario: Project uses React, no React agent exists')
            ->example()
                ->phase('input', 'Existing: 7 agents from brain master:list')
                ->phase('analysis', 'Gap detected: React/Frontend expertise missing')
                ->phase('action', 'brain make:master ReactMaster → Compile')
                ->phase('result', 'ReactMaster agent available via Task(@agent-react-master, "...")');

        $this->guideline('example-3')
            ->text('Scenario: Full coverage, all required agents exist')
            ->example()
                ->phase('input', 'Brain context + .docs/ requirements')
                ->phase('analysis', 'All domains covered by existing agents')
                ->phase('result', 'Report: "No gaps detected → System ready" with agent list');

        // Directive
        $this->guideline('directive')
            ->text('Generate ONLY missing agents! Preserve existing! Use brain make:master ONLY! Compile after generation! Report coverage!');
    }
}
