<?php

declare(strict_types=1);

namespace BrainNode\Commands;

use BrainCore\Archetypes\CommandArchetype;
use BrainCore\Attributes\Meta;
use BrainCore\Attributes\Purpose;
use BrainCore\Compilation\BrainCLI;
use BrainCore\Compilation\Operator;
use BrainCore\Compilation\Store;
use BrainCore\Compilation\Tools\BashTool;
use BrainCore\Compilation\Tools\TaskTool;

#[Meta('id', 'do')]
#[Meta('description', 'Multi-agent orchestration command for sequential task execution with user approval gates')]
#[Purpose('Coordinates sequential agent execution with approval checkpoints. Accepts $ARGUMENTS task description. Zero distractions, atomic tasks only, strict plan adherence.')]
class DoCommand extends CommandArchetype
{
    /**
     * Handle the command logic.
     */
    protected function handle(): void
    {
        // Iron Rules - Zero Tolerance
        $this->rule('zero-distractions')->critical()
            ->text('ZERO distractions - implement ONLY specified task from $ARGUMENTS. NO creative additions, NO unapproved features, NO scope creep.')
            ->why('Ensures focused execution and prevents feature drift')
            ->onViolation('Abort immediately. Return to approved plan.');

        $this->rule('approval-gates-mandatory')->critical()
            ->text('User approval REQUIRED at Requirements Analysis gate and Execution Planning gate. NEVER proceed without explicit confirmation.')
            ->why('Maintains user control and prevents unauthorized execution')
            ->onViolation('STOP. Wait for user approval before continuing.');

        $this->rule('atomic-tasks-only')->critical()
            ->text('Each agent task MUST be small and focused: maximum 1-2 files per agent invocation. NO large multi-file changes.')
            ->why('Prevents complexity, improves reliability, enables precise tracking')
            ->onViolation('Break task into smaller pieces. Re-plan with atomic steps.');

        $this->rule('no-improvisation')->critical()
            ->text('Execute ONLY approved plan steps. NO improvisation, NO "while we\'re here" additions, NO proactive suggestions during execution.')
            ->why('Maintains plan integrity and predictability')
            ->onViolation('Revert to last approved checkpoint. Resume approved steps only.');

        $this->rule('sequential-execution-only')->high()
            ->text('Execute agents sequentially one-by-one. NO parallel execution, NO batching, NO optimization attempts.')
            ->why('Ensures clear progress tracking and error isolation')
            ->onViolation('Queue remaining tasks. Execute current task to completion first.');

        // Phase 1: Agent Discovery
        $this->guideline('phase1-agent-discovery')
            ->goal('Discover available agents and select relevant ones for task')
            ->example()
            ->phase('Parse $ARGUMENTS to understand task domain and requirements')
            ->phase(Store::as('TASK_DESCRIPTION', 'User task from $ARGUMENTS'))
            ->phase(BashTool::describe(BrainCLI::MASTER_LIST, 'Execute brain master:list'))
            ->phase(Store::as('AVAILABLE_AGENTS', 'List of all agents with capabilities'))
            ->phase('Analyze: Which agents are relevant for $TASK_DESCRIPTION?')
            ->phase('Match task domain to agent expertise areas')
            ->phase(Store::as('RELEVANT_AGENTS', '[{agent_name, capability_match, rationale}, ...]'))
            ->phase(Operator::output([
                '=== PHASE 1: AGENT DISCOVERY ===',
                'Task: {$TASK_DESCRIPTION}',
                'Available Agents: {count}',
                'Relevant Agents Selected:',
                '  - {agent_name}: {rationale}',
                '  - ...',
            ]))
            ->phase('Present agent selection to user (informational, no approval needed at this stage)');

        // Phase 2: Requirements Analysis with Approval Gate
        $this->guideline('phase2-requirements-analysis-approval')
            ->goal('Create detailed requirements analysis plan and GET USER APPROVAL before proceeding')
            ->example()
            ->phase('Analyze $TASK_DESCRIPTION deeply')
            ->phase('Identify what information/context each selected agent will need')
            ->phase('Determine if web research would improve solution quality')
            ->phase(Operator::if('task is non-trivial AND external knowledge beneficial', [
                'Recommend web-research-master for industry best practices',
                Store::as('WEB_RESEARCH_NEEDED', 'true'),
            ]))
            ->phase('Create detailed scanning plan: what to look for, where to look, why')
            ->phase(Store::as('REQUIREMENTS_PLAN', '{scan_targets: [...], context_needed: [...], web_research: boolean, rationale: "..."}'))
            ->phase(Operator::output([
                '',
                '=== PHASE 2: REQUIREMENTS ANALYSIS PLAN ===',
                'Scanning Strategy:',
                '  1. {scan_target}: {what_to_extract}',
                '  2. ...',
                'Context Requirements:',
                '  - {context_type}: {why_needed}',
                'Web Research: {recommended/not_needed} - {rationale}',
                '',
                '⚠️  APPROVAL CHECKPOINT #1',
                '📋 Please review the requirements analysis plan above.',
                '✅ Type "approved" or "yes" to proceed with material gathering.',
                '❌ Type "no" or provide modifications to adjust the plan.',
            ]))
            ->phase('WAIT for user approval')
            ->phase(Operator::verify('User confirmed approval'))
            ->phase(Operator::if('user rejected or requested changes', [
                'Log: "Requirements plan rejected - awaiting modifications"',
                'Accept user modifications',
                'Update $REQUIREMENTS_PLAN',
                'Re-present plan for approval',
                'WAIT for approval again',
            ]));

        // Phase 3: Material Gathering
        $this->guideline('phase3-material-gathering')
            ->goal('Collect necessary materials and context according to approved requirements plan')
            ->example()
            ->phase('Execute approved $REQUIREMENTS_PLAN')
            ->phase(Operator::forEach('scan_target in $REQUIREMENTS_PLAN.scan_targets', [
                'Gather materials from {scan_target}',
                TaskTool::describe('Delegate to appropriate agent for context extraction'),
                Store::as('GATHERED_MATERIALS[{target}]', 'Extracted context'),
            ]))
            ->phase(Operator::if('$WEB_RESEARCH_NEEDED === true', [
                'Delegate to @agent-web-research-master',
                'Task: Research industry best practices for {$TASK_DESCRIPTION}',
                Store::as('WEB_RESEARCH_FINDINGS', 'External knowledge and patterns'),
            ]))
            ->phase('Package agent-specific context')
            ->phase(Store::as('CONTEXT_PACKAGES', '{agent_name: {context: ..., materials: ...}, ...}'))
            ->phase(Operator::output([
                '',
                '=== PHASE 3: MATERIAL GATHERING COMPLETE ===',
                'Gathered Materials:',
                '  ✓ {material_type}: {count} items',
                '  ✓ ...',
                'Web Research: {completed/skipped}',
                'Context Packages Ready: {count} agents',
            ]));

        // Phase 4: Execution Planning with Approval Gate
        $this->guideline('phase4-execution-planning-approval')
            ->goal('Create granular atomic execution plan and GET USER APPROVAL before execution')
            ->example()
            ->phase('Create granular execution plan with agent assignments')
            ->phase('Each step MUST be atomic: 1-2 files maximum per agent task')
            ->phase('Define specific file scope for each step')
            ->phase('Sequence steps in logical dependency order')
            ->phase(Store::as('EXECUTION_PLAN', '{steps: [{step_number, agent_name, task_description, file_scope: [file1.php, file2.php], dependencies: [...], expected_outcome}, ...], total_steps: N, estimated_duration: "..."}'))
            ->phase(Operator::verify('Each step has maximum 2 files in file_scope'))
            ->phase(Operator::output([
                '',
                '=== PHASE 4: EXECUTION PLAN ===',
                'Task: {$TASK_DESCRIPTION}',
                'Total Steps: {$EXECUTION_PLAN.total_steps}',
                '',
                'Sequential Execution Steps:',
                '  Step 1: @agent-{name}',
                '    Task: {task_description}',
                '    Files: {file1.php}, {file2.php}',
                '    Expected: {expected_outcome}',
                '',
                '  Step 2: @agent-{name}',
                '    Task: {task_description}',
                '    Files: {file1.php}',
                '    Expected: {expected_outcome}',
                '',
                '  ...',
                '',
                '⚠️  APPROVAL CHECKPOINT #2',
                '📋 Please review the execution plan above.',
                '✅ Type "approved" or "yes" to begin sequential execution.',
                '❌ Type "no" or provide modifications to adjust the plan.',
            ]))
            ->phase('WAIT for user approval')
            ->phase(Operator::verify('User confirmed approval'))
            ->phase(Operator::if('user rejected or requested changes', [
                'Log: "Execution plan rejected - awaiting modifications"',
                'Accept user modifications',
                'Update $EXECUTION_PLAN',
                'Re-verify atomic task constraints',
                'Re-present plan for approval',
                'WAIT for approval again',
            ]));

        // Phase 5: Sequential Execution
        $this->guideline('phase5-sequential-execution')
            ->goal('Execute approved plan sequentially - ONE agent at a time, NO improvisation')
            ->example()
            ->phase('Initialize: current_step = 1, total_steps = {$EXECUTION_PLAN.total_steps}')
            ->phase(Operator::forEach('step in $EXECUTION_PLAN.steps (sequential, one by one)', [
                'Log: "Executing Step {current_step}/{total_steps}: {step.agent_name}"',
                Operator::output([
                    '',
                    '▶️  Step {current_step}/{total_steps}: @agent-{step.agent_name}',
                    '📝 Task: {step.task_description}',
                    '📁 Files: {step.file_scope}',
                ]),
                'Delegate to {step.agent_name} with:',
                '  - Task: {step.task_description}',
                '  - Context: {$CONTEXT_PACKAGES[step.agent_name]}',
                '  - File scope: {step.file_scope}',
                '  - Expected outcome: {step.expected_outcome}',
                TaskTool::describe('Task(@agent-{name}, {task_with_context})'),
                Store::as('STEP_RESULTS[{current_step}]', 'Agent execution result'),
                Operator::verify('Step completed successfully'),
                Operator::output([
                    '✅ Step {current_step} complete',
                    '   Result: {outcome_summary}',
                ]),
                'Increment: current_step++',
                Operator::if('current_step < total_steps', [
                    'Continue to next step immediately',
                ]),
            ]))
            ->phase(Operator::if('any step fails', [
                'Log: "Execution stopped at Step {current_step} - failure detected"',
                'Report: {error_details}',
                'Offer: retry current step OR abort remaining steps',
                'WAIT for user decision',
            ]))
            ->phase('All steps completed successfully');

        // Phase 6: Completion Report
        $this->guideline('phase6-completion-report')
            ->goal('Report execution results and final status')
            ->example()
            ->phase('Aggregate results from all steps')
            ->phase(Store::as('COMPLETION_SUMMARY', '{completed_steps, failed_steps, files_modified, outcomes: [...]}'))
            ->phase(Operator::output([
                '',
                '=== EXECUTION COMPLETE ===',
                'Task: {$TASK_DESCRIPTION}',
                'Status: {SUCCESS/PARTIAL/FAILED}',
                '',
                'Execution Summary:',
                '  ✓ Steps Completed: {completed_steps}/{total_steps}',
                '  📁 Files Modified: {files_modified_count}',
                '  ⏱️  Duration: {execution_duration}',
                '',
                'Step-by-Step Results:',
                '  Step 1: {agent_name} - {outcome} ✓',
                '  Step 2: {agent_name} - {outcome} ✓',
                '  ...',
                '',
                'Final Outcome:',
                '  {final_status_description}',
            ]))
            ->phase(Operator::if('all steps succeeded', [
                'Log: "Task completed successfully - all objectives met"',
                'Store task completion in vector memory',
            ]))
            ->phase(Operator::if('partial completion', [
                'Log: "Task partially completed - {completed}/{total} steps"',
                'List remaining steps',
                'Suggest: /do to resume or manual intervention',
            ]));

        // Error Handling
        $this->guideline('error-handling')
            ->text('Graceful error handling with recovery options')
            ->example()
            ->phase()->if('no agents available', [
                'Report: "No agents found via brain master:list"',
                'Suggest: Run /init-agents first',
                'Abort command',
            ])
            ->phase()->if('user rejects requirements plan', [
                'Accept modifications',
                'Rebuild requirements plan',
                'Re-submit for approval',
            ])
            ->phase()->if('user rejects execution plan', [
                'Accept modifications',
                'Rebuild execution plan',
                'Verify atomic task constraints',
                'Re-submit for approval',
            ])
            ->phase()->if('agent execution fails', [
                'Log: "Step {N} failed: {error}"',
                'Offer options:',
                '  1. Retry current step',
                '  2. Skip and continue',
                '  3. Abort remaining steps',
                'WAIT for user decision',
            ])
            ->phase()->if('web research timeout', [
                'Log: "Web research timed out - continuing without external knowledge"',
                'Proceed with local context only',
            ])
            ->phase()->if('context gathering fails', [
                'Log: "Failed to gather {context_type}"',
                'Proceed with available context',
                'Warn: "Limited context may affect quality"',
            ]);

        // Constraints and Validation
        $this->guideline('constraints-validation')
            ->text('Enforcement of critical constraints throughout execution')
            ->example()
            ->phase('Before Requirements Analysis: Verify $ARGUMENTS is not empty')
            ->phase('Before Phase 2 → Phase 3 transition: Verify user approval received')
            ->phase('Before Phase 4 → Phase 5 transition: Verify user approval received')
            ->phase('During Execution Planning: Verify each step has ≤ 2 files in scope')
            ->phase('During Sequential Execution: Verify previous step completed before starting next')
            ->phase('Throughout: NO unapproved steps allowed')
            ->phase(Operator::verify([
                'approval_checkpoints_passed = 2',
                'all_tasks_atomic = true (≤ 2 files each)',
                'execution_mode = sequential',
                'improvisation_count = 0',
            ]));

        // Examples
        $this->guideline('example-1-simple-task')
            ->scenario('Simple single-agent task')
            ->example()
            ->phase('input', '$ARGUMENTS = "Fix authentication bug in LoginController.php"')
            ->phase('phase1', 'Agent Discovery: Selected @agent-code-master')
            ->phase('phase2', 'Requirements Plan: Scan LoginController.php, related auth files')
            ->phase('approval1', 'User approves requirements plan')
            ->phase('phase3', 'Gather context: LoginController.php, AuthService.php')
            ->phase('phase4', 'Execution Plan: 1 step, @agent-code-master, files: [LoginController.php]')
            ->phase('approval2', 'User approves execution plan')
            ->phase('phase5', 'Execute: Fix authentication bug')
            ->phase('phase6', 'Report: Step 1/1 complete - bug fixed ✓');

        $this->guideline('example-2-multi-step-task')
            ->scenario('Complex multi-agent task with web research')
            ->example()
            ->phase('input', '$ARGUMENTS = "Add Laravel rate limiting to API endpoints"')
            ->phase('phase1', 'Agents: @agent-web-research-master, @agent-code-master, @agent-documentation-master')
            ->phase('phase2', 'Requirements Plan: Research Laravel rate limiting, scan API routes, identify endpoints')
            ->phase('approval1', 'User approves (including web research)')
            ->phase('phase3', 'Gather: Web research findings, routes/api.php, middleware list')
            ->phase('phase4', 'Execution Plan:')
            ->do([
                'Step 1: @agent-code-master - Create RateLimitMiddleware.php',
                'Step 2: @agent-code-master - Update app/Http/Kernel.php',
                'Step 3: @agent-code-master - Apply middleware to routes/api.php',
                'Step 4: @agent-documentation-master - Update API docs',
            ])
            ->phase('approval2', 'User approves execution plan')
            ->phase('phase5', 'Sequential execution: Steps 1→2→3→4')
            ->phase('phase6', 'Report: 4/4 steps complete - rate limiting implemented ✓');

        $this->guideline('example-3-approval-rejection')
            ->scenario('User rejects execution plan, requests modifications')
            ->example()
            ->phase('input', '$ARGUMENTS = "Refactor UserService to use repository pattern"')
            ->phase('phase1-4', 'Standard flow through execution planning')
            ->phase('approval2', 'User responds: "No, split Step 3 into smaller pieces"')
            ->phase('revision', 'Rebuild execution plan with Step 3 split into 3a, 3b, 3c')
            ->phase('re-approval', 'Re-present plan → User approves')
            ->phase('phase5', 'Execute revised plan')
            ->phase('phase6', 'Report: Completed with revised plan ✓');

        // Response Format
        $this->guideline('response-format')
            ->text('Structured output format for each phase')
            ->example()
            ->phase('Phase headers with === markers')
            ->phase('Bullet-point plans with clear structure')
            ->phase('Approval checkpoints with ⚠️  and clear instructions')
            ->phase('Progress indicators: ▶️ ✅ ❌ 📋 📁 ⏱️')
            ->phase('File scope explicitly listed for each step')
            ->phase('No extraneous commentary during execution')
            ->phase('Clear status indicators for completion');

        // Directive
        $this->guideline('directive')
            ->text('Execute ONLY specified task! Get approvals at checkpoints! Atomic tasks ONLY! Sequential execution! NO improvisation! Zero distractions! Strict plan adherence!');
    }
}
