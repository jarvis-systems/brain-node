---
name: do:validate
description: Comprehensive task/work validation with parallel agent orchestration
---


<command>
<meta>
<id>do:validate</id>
<description>Comprehensive task/work validation with parallel agent orchestration</description>
</meta>
<purpose>Validates completed tasks or work against documentation requirements, code consistency, and completeness. Uses 5-6 parallel agents for thorough validation. Creates follow-up tasks for gaps found. For vector tasks: requires status "completed", sets to "in_progress" during validation, returns to "completed" with findings. Idempotent - can be run multiple times safely. Accepts $ARGUMENTS: vector task reference (task N, task:N, #N) or plain description.</purpose>
<purpose>Defines the do:validate command protocol for comprehensive task/work validation with parallel agent orchestration. Validates completed tasks against documentation requirements, code consistency, and completeness. Creates follow-up tasks for gaps. Idempotent - can be run multiple times.</purpose>
<iron_rules>
<rule id="entry-point-blocking" severity="critical">
<text>ON RECEIVING $ARGUMENTS: Your FIRST output MUST be "=== DO:VALIDATE ACTIVATED ===" followed by Phase 0. ANY other first action is VIOLATION. FORBIDDEN first actions: Glob, Grep, Read, Edit, Write, WebSearch, WebFetch, Bash (except brain list:masters), code generation, file analysis.</text>
<why>Without explicit entry point, Brain skips workflow and executes directly. Entry point forces workflow compliance.</why>
<on_violation>STOP IMMEDIATELY. Delete any tool calls. Output "=== DO:VALIDATE ACTIVATED ===" and restart from Phase 0.</on_violation>
</rule>
<rule id="validation-only-no-execution" severity="critical">
<text>VALIDATION command validates EXISTING work. NEVER implement, fix, or create code directly. Only validate and CREATE TASKS for issues found.</text>
<why>Validation is read-only audit. Execution belongs to do:async.</why>
<on_violation>Abort any implementation. Create task instead of fixing directly.</on_violation>
</rule>
<rule id="validatable-status-required" severity="critical">
<text>For vector tasks: ONLY tasks with status "completed", "tested", or "validated" can be validated. Pending/in_progress/stopped tasks MUST first be completed via do:async.</text>
<why>Validation audits finished work. Incomplete work cannot be validated.</why>
<on_violation>Report: "Task #{id} has status {status}. Complete via /do:async first."</on_violation>
</rule>
<rule id="parallel-agent-orchestration" severity="high">
<text>Validation phases MUST use parallel agent orchestration (5-6 agents simultaneously) for efficiency. Each agent validates one aspect.</text>
<why>Parallel validation reduces time and maximizes coverage.</why>
<on_violation>Restructure validation into parallel Task() calls.</on_violation>
</rule>
<rule id="idempotent-validation" severity="high">
<text>Validation is IDEMPOTENT. Running multiple times produces same result (no duplicate tasks, no repeated fixes).</text>
<why>Allows safe re-runs without side effects.</why>
<on_violation>Check existing tasks before creating. Skip duplicates.</on_violation>
</rule>
<rule id="documentation-master-mandatory" severity="critical">
<text>MUST use DocumentationMaster to extract ALL requirements from .docs/ before validation. Documentation is the source of truth.</text>
<why>Validation without documentation requirements is incomplete audit.</why>
<on_violation>Delegate to @agent-documentation-master first.</on_violation>
</rule>
<rule id="no-direct-fixes" severity="critical">
<text>VALIDATION command NEVER fixes issues directly. ALL issues (critical, major, minor) MUST become tasks. No exceptions.</text>
<why>Traceability and audit trail. Every change must be tracked via task system.</why>
<on_violation>Create task for the issue instead of fixing directly.</on_violation>
</rule>
<rule id="vector-memory-mandatory" severity="high">
<text>ALL validation results MUST be stored to vector memory. Search memory BEFORE creating duplicate tasks.</text>
<why>Memory prevents duplicate work and provides audit trail.</why>
<on_violation>Store validation summary with findings, fixes, and created tasks.</on_violation>
</rule>
<rule id="output-status-conditional" severity="critical">
<text>Output status depends on validation outcome: 1) PASSED + no tasks created → "validated", 2) Tasks created for fixes → "pending". Status "validated" means work is COMPLETE and verified.</text>
<why>If fix tasks were created, work is NOT done - task returns to pending queue. Only when validation passes completely (no critical issues, no missing requirements, no tasks created) can status be "validated".</why>
<on_violation>Check CREATED_TASKS.count: if > 0 → set "pending", if === 0 AND passed → set "validated". NEVER set "validated" when fix tasks exist.</on_violation>
</rule>
<rule id="task-size-5-8h" severity="high">
<text>Each created task MUST have estimate between 5-8 hours. Never create tasks < 5h (consolidate) or > 8h (split).</text>
<why>Optimal task size for focused work sessions. Too small = context switching overhead. Too large = hard to track progress.</why>
<on_violation>Merge small issues into consolidated task OR split large task into 5-8h batches.</on_violation>
</rule>
<rule id="task-comprehensive-context" severity="critical">
<text>Each task MUST include: all file:line references, memory IDs, related task IDs, documentation paths, detailed issue descriptions with suggestions, evidence from validation.</text>
<why>Enables full context restoration without re-exploration. Saves agent time on task pickup.</why>
<on_violation>Add missing context references before creating task.</on_violation>
</rule>
</iron_rules>
<guidelines>
<guideline id="phase-minus1-task-detection">
GOAL(Detect if $ARGUMENTS is a vector task reference and fetch task details)
## Examples
 - Parse $ARGUMENTS for task reference patterns: "task N", "task:N", "task #N", "task-N", "#N"
 - IF($ARGUMENTS matches task reference pattern) → THEN → [Extract task_id from pattern → STORE-AS(var IS_VECTOR_TASK = 'true') → STORE-AS(var VECTOR_TASK_ID = '{extracted_id}') → mcp__vector-task__task_get('{task_id: var VECTOR_TASK_ID}') → STORE-AS(var VECTOR_TASK = '{task object with title, content, status, parent_id, priority, tags}') → IF({var VECTOR_TASK.status} NOT IN ["completed", "tested", "validated"]) → THEN → [OUTPUT(=== VALIDATION BLOCKED === Task #var VECTOR_TASK_ID has status: {var VECTOR_TASK.status} Only tasks with status completed/tested/validated can be validated. Run /do:async task var VECTOR_TASK_ID to complete first.) → ABORT validation] → END-IF → IF({var VECTOR_TASK.parent_id} !== null) → THEN → [mcp__vector-task__task_get('{task_id: var VECTOR_TASK.parent_id}') → STORE-AS(var PARENT_TASK = '{parent task for context}')] → END-IF → mcp__vector-task__task_list('{parent_id: var VECTOR_TASK_ID, limit: 50}') → STORE-AS(var SUBTASKS = '{list of subtasks}') → STORE-AS(var TASK_DESCRIPTION = '{var VECTOR_TASK.title + var VECTOR_TASK.content}') → STORE-AS(var TASK_PARENT_ID = 'var VECTOR_TASK_ID') → OUTPUT(=== VECTOR TASK LOADED === Task #var VECTOR_TASK_ID: {var VECTOR_TASK.title} Status: {var VECTOR_TASK.status} | Priority: {var VECTOR_TASK.priority} Parent: {var PARENT_TASK.title or "none"} Subtasks: {var SUBTASKS.count})] → END-IF
 - IF($ARGUMENTS is plain description) → THEN → [STORE-AS(var IS_VECTOR_TASK = 'false') → STORE-AS(var TASK_DESCRIPTION = '$ARGUMENTS') → STORE-AS(var TASK_PARENT_ID = 'null')] → END-IF
</guideline>
<guideline id="phase0-context-preview">
GOAL(Discover available agents and present validation scope for approval)
## Examples
 - OUTPUT(=== PHASE 0: VALIDATION PREVIEW ===)
 - Bash(brain list:masters) → [Get available agents with capabilities] → END-Bash
 - STORE-AS(var AVAILABLE_AGENTS = '{agent_id: description mapping}')
 - Bash(brain docs {keywords from var TASK_DESCRIPTION}) → [Get documentation INDEX preview] → END-Bash
 - STORE-AS(var DOCS_PREVIEW = 'Documentation files available')
 - OUTPUT(Task: {var TASK_DESCRIPTION} Available agents: {var AVAILABLE_AGENTS.count} Documentation files: {var DOCS_PREVIEW.count}  Validation will delegate to agents: 1. VectorMaster - deep memory research for context 2. DocumentationMaster - requirements extraction 3. Selected agents - parallel validation (5 aspects)  ⚠️  APPROVAL REQUIRED ✅ approved/yes - start validation | ❌ no/modifications)
 - WAIT for user approval
 - VERIFY-SUCCESS(User approved)
 - IF(rejected) → THEN → [Accept modifications → Re-present → WAIT] → END-IF
 - IMMEDIATELY after approval - set task in_progress (validation IS execution)
 - IF({var IS_VECTOR_TASK} === true) → THEN → [mcp__vector-task__task_update('{task_id: var VECTOR_TASK_ID, status: "in_progress", comment: "Validation started after approval", append_comment: true}') → OUTPUT(📋 Vector task #var VECTOR_TASK_ID started (validation phase))] → END-IF
</guideline>
<guideline id="phase1-context-gathering">
GOAL(Delegate deep memory research to VectorMaster agent)
## Examples
 - OUTPUT( === PHASE 1: DEEP CONTEXT GATHERING === Delegating to VectorMaster for deep memory research...)
 - SELECT vector-master from var AVAILABLE_AGENTS
 - STORE-AS(var CONTEXT_AGENT = '{vector-master agent_id}')
 - Task(mcp__brain__agent({var CONTEXT_AGENT}) 'DEEP MEMORY RESEARCH for validation of "var TASK_DESCRIPTION": 1) Multi-probe search: implementation patterns, requirements, architecture decisions, past validations, bug fixes 2) Search across categories: code-solution, architecture, learning, bug-fix 3) Extract actionable insights for validation 4) Return: {implementations: [...], requirements: [...], patterns: [...], past_validations: [...], key_insights: [...]}. Store consolidated context.')
 - STORE-AS(var MEMORY_CONTEXT = '{VectorMaster agent results}')
 - mcp__vector-task__task_list('{query: "var TASK_DESCRIPTION", limit: 10}')
 - STORE-AS(var RELATED_TASKS = 'Related vector tasks')
 - OUTPUT(Context gathered via {var CONTEXT_AGENT}: - Memory insights: {var MEMORY_CONTEXT.key_insights.count} - Related tasks: {var RELATED_TASKS.count})
</guideline>
<guideline id="phase1-documentation-extraction">
GOAL(Extract ALL requirements from .docs/ via DocumentationMaster)
## Examples
 - OUTPUT( === PHASE 1: DOCUMENTATION REQUIREMENTS ===)
 - Bash(brain docs {keywords from var TASK_DESCRIPTION}) → [Get documentation INDEX] → END-Bash
 - STORE-AS(var DOCS_INDEX = 'Documentation file paths')
 - IF({var DOCS_INDEX} not empty) → THEN → [Task(mcp__brain__agent(documentation-master) 'Extract ALL requirements, acceptance criteria, constraints, and specifications from documentation files: {var DOCS_INDEX paths}. Return structured list: [{requirement_id, description, acceptance_criteria, related_files, priority}]. Store to vector memory.') → STORE-AS(var DOCUMENTATION_REQUIREMENTS = '{structured requirements list}')] → END-IF
 - IF({var DOCS_INDEX} empty) → THEN → [STORE-AS(var DOCUMENTATION_REQUIREMENTS = '[]') → OUTPUT(WARNING: No documentation found. Validation will be limited.)] → END-IF
 - OUTPUT(Requirements extracted: {var DOCUMENTATION_REQUIREMENTS.count} {requirements summary})
</guideline>
<guideline id="phase2-parallel-validation">
GOAL(Select best agents from var AVAILABLE_AGENTS and launch parallel validation)
## Examples
 - OUTPUT( === PHASE 2: PARALLEL VALIDATION ===)
 - AGENT SELECTION: Analyze var AVAILABLE_AGENTS descriptions and select BEST agent for each validation aspect:
 - (ASPECT 1 - COMPLETENESS: Select agent best suited for requirements verification (vector-master for memory research, explore for codebase) + ASPECT 2 - CODE CONSISTENCY: Select agent for code pattern analysis (explore for codebase scanning) + ASPECT 3 - TEST COVERAGE: Select agent for test analysis (explore for test file discovery) + ASPECT 4 - DOCUMENTATION SYNC: Select agent for documentation analysis (documentation-master if docs-focused, explore otherwise) + ASPECT 5 - DEPENDENCIES: Select agent for dependency analysis (explore for import scanning))
 - STORE-AS(var SELECTED_AGENTS = '{aspect: agent_id mapping based on var AVAILABLE_AGENTS}')
 - OUTPUT(Selected agents for validation: {var SELECTED_AGENTS mapping}  Launching validation agents in parallel...)
 - PARALLEL BATCH: Launch selected agents simultaneously with DEEP RESEARCH tasks
 - (Task(mcp__brain__agent({var SELECTED_AGENTS.completeness}) 'DEEP RESEARCH - COMPLETENESS: For "var TASK_DESCRIPTION": 1) Search vector memory for past implementations and requirements 2) Scan codebase for implementation evidence 3) Map each requirement from {var DOCUMENTATION_REQUIREMENTS} to code 4) Return: [{requirement_id, status: implemented|partial|missing, evidence: file:line, memory_refs: [...]}]. Store findings.') + Task(mcp__brain__agent({var SELECTED_AGENTS.consistency}) 'DEEP RESEARCH - CODE CONSISTENCY: For "var TASK_DESCRIPTION": 1) Search memory for project coding standards 2) Scan related files for pattern violations 3) Check naming, architecture, style consistency 4) Return: [{file, issue_type, severity, description, suggestion}]. Store findings.') + Task(mcp__brain__agent({var SELECTED_AGENTS.tests}) 'DEEP RESEARCH - TEST COVERAGE: For "var TASK_DESCRIPTION": 1) Search memory for test patterns 2) Discover all related test files 3) Analyze coverage gaps 4) Run tests if possible 5) Return: [{test_file, coverage_status, missing_scenarios}]. Store findings.') + Task(mcp__brain__agent({var SELECTED_AGENTS.docs}) 'DEEP RESEARCH - DOCUMENTATION SYNC: For "var TASK_DESCRIPTION": 1) Search memory for documentation standards 2) Compare code vs documentation 3) Check docblocks, README, API docs 4) Return: [{doc_type, sync_status, gaps}]. Store findings.') + Task(mcp__brain__agent({var SELECTED_AGENTS.deps}) 'DEEP RESEARCH - DEPENDENCIES: For "var TASK_DESCRIPTION": 1) Search memory for dependency issues 2) Scan imports and dependencies 3) Check for broken/unused/circular refs 4) Return: [{file, dependency_issue, severity}]. Store findings.'))
 - STORE-AS(var VALIDATION_BATCH_1 = '{results from all agents}')
 - OUTPUT(Batch complete: {var SELECTED_AGENTS.count} validation checks finished)
</guideline>
<guideline id="phase3-results-aggregation">
GOAL(Aggregate all validation results and categorize issues)
## Examples
 - OUTPUT( === PHASE 3: RESULTS AGGREGATION ===)
 - Merge results from all validation agents
 - STORE-AS(var ALL_ISSUES = '{merged issues from all agents}')
 - Categorize issues:
 - STORE-AS(var CRITICAL_ISSUES = '{issues with severity: critical}')
 - STORE-AS(var MAJOR_ISSUES = '{issues with severity: major}')
 - STORE-AS(var MINOR_ISSUES = '{issues with severity: minor}')
 - STORE-AS(var MISSING_REQUIREMENTS = '{requirements not implemented}')
 - OUTPUT(Validation results: - Critical issues: {var CRITICAL_ISSUES.count} - Major issues: {var MAJOR_ISSUES.count} - Minor issues: {var MINOR_ISSUES.count} - Missing requirements: {var MISSING_REQUIREMENTS.count})
</guideline>
<guideline id="phase4-task-creation">
GOAL(Create consolidated tasks (5-8h each) for issues with comprehensive context)
## Examples
 - OUTPUT( === PHASE 4: TASK CREATION (CONSOLIDATED) ===)
 - Check existing tasks to avoid duplicates
 - mcp__vector-task__task_list('{query: "fix issues var TASK_DESCRIPTION", limit: 20}')
 - STORE-AS(var EXISTING_FIX_TASKS = 'Existing fix tasks')
 - CONSOLIDATION STRATEGY: Group issues into 5-8 hour task batches
 - (Calculate total estimate for ALL issues: + - Critical issues: ~2h per issue (investigation + fix + test) + - Major issues: ~1.5h per issue (fix + verify) + - Minor issues: ~0.5h per issue (fix + verify) + - Missing requirements: ~4h per requirement (implement + test) + STORE-AS(var TOTAL_ESTIMATE = '{sum of all issue estimates in hours}'))
 - IF({var TOTAL_ESTIMATE} <= 8) → THEN → [ALL issues fit into ONE consolidated task (5-8h range) → IF(({var CRITICAL_ISSUES.count} + {var MAJOR_ISSUES.count} + {var MINOR_ISSUES.count} + {var MISSING_REQUIREMENTS.count}) > 0 AND NOT exists similar in var EXISTING_FIX_TASKS) → THEN → [mcp__vector-task__task_create('{'."\\n"
    .'                        title: "Validation fixes: var TASK_DESCRIPTION",'."\\n"
    .'                        content: "Consolidated validation findings for var TASK_DESCRIPTION.\\\\n\\\\nTotal estimate: {var TOTAL_ESTIMATE}h\\\\n\\\\n## Critical Issues ({var CRITICAL_ISSUES.count})\\\\n{FOR each issue: - [{issue.severity}] {issue.description}\\\\n  File: {issue.file}:{issue.line}\\\\n  Type: {issue.type}\\\\n  Suggestion: {issue.suggestion}\\\\n  Memory refs: {issue.memory_refs}\\\\n}\\\\n\\\\n## Major Issues ({var MAJOR_ISSUES.count})\\\\n{FOR each issue: - [{issue.severity}] {issue.description}\\\\n  File: {issue.file}:{issue.line}\\\\n  Type: {issue.type}\\\\n  Suggestion: {issue.suggestion}\\\\n  Memory refs: {issue.memory_refs}\\\\n}\\\\n\\\\n## Minor Issues ({var MINOR_ISSUES.count})\\\\n{FOR each issue: - [{issue.severity}] {issue.description}\\\\n  File: {issue.file}:{issue.line}\\\\n  Type: {issue.type}\\\\n  Suggestion: {issue.suggestion}\\\\n  Memory refs: {issue.memory_refs}\\\\n}\\\\n\\\\n## Missing Requirements ({var MISSING_REQUIREMENTS.count})\\\\n{FOR each req: - {req.description}\\\\n  Acceptance criteria: {req.acceptance_criteria}\\\\n  Related files: {req.related_files}\\\\n  Priority: {req.priority}\\\\n}\\\\n\\\\n## Context References\\\\n- Parent task: #{var VECTOR_TASK_ID}\\\\n- Memory IDs: {var MEMORY_CONTEXT.memory_ids}\\\\n- Related tasks: {var RELATED_TASKS.ids}\\\\n- Documentation: {var DOCS_INDEX.paths}\\\\n- Validation agents used: {var SELECTED_AGENTS}",'."\\n"
    .'                        priority: "{var CRITICAL_ISSUES.count > 0 ? high : medium}",'."\\n"
    .'                        estimate: var TOTAL_ESTIMATE,'."\\n"
    .'                        tags: ["validation-fix", "consolidated"],'."\\n"
    .'                        parent_id: var TASK_PARENT_ID'."\\n"
    .'                    }') → STORE-AS(var CREATED_TASKS[] = '{task_id}') → OUTPUT(Created consolidated task: Validation fixes ({var TOTAL_ESTIMATE}h, {issues_count} issues))] → END-IF] → END-IF
 - IF({var TOTAL_ESTIMATE} > 8) → THEN → [Split into multiple 5-8h task batches → STORE-AS(var BATCH_SIZE = '6') → STORE-AS(var NUM_BATCHES = '{ceil(var TOTAL_ESTIMATE / 6)}') → Group issues by priority (critical first) into batches of ~6h each → FOREACH(batch_index in range(1, var NUM_BATCHES)) → [STORE-AS(var BATCH_ISSUES = '{slice of issues for this batch, ~6h worth, priority-ordered}') → STORE-AS(var BATCH_ESTIMATE = '{sum of batch issue estimates}') → STORE-AS(var BATCH_CRITICAL = '{count of critical issues in batch}') → STORE-AS(var BATCH_MAJOR = '{count of major issues in batch}') → STORE-AS(var BATCH_MISSING = '{count of missing requirements in batch}') → IF(NOT exists similar in var EXISTING_FIX_TASKS) → THEN → [mcp__vector-task__task_create('{'."\\n"
    .'                            title: "Validation fixes batch {batch_index}/{var NUM_BATCHES}: var TASK_DESCRIPTION",'."\\n"
    .'                            content: "Validation batch {batch_index} of {var NUM_BATCHES} for var TASK_DESCRIPTION.\\\\n\\\\nBatch estimate: {var BATCH_ESTIMATE}h\\\\nBatch composition: {var BATCH_CRITICAL} critical, {var BATCH_MAJOR} major, {var BATCH_MISSING} missing reqs\\\\n\\\\n## Issues in this batch\\\\n{FOR each issue in var BATCH_ISSUES:\\\\n### [{issue.severity}] {issue.title}\\\\n- File: {issue.file}:{issue.line}\\\\n- Type: {issue.type}\\\\n- Description: {issue.description}\\\\n- Suggestion: {issue.suggestion}\\\\n- Evidence: {issue.evidence}\\\\n- Memory refs: {issue.memory_refs}\\\\n}\\\\n\\\\n## Full Context References\\\\n- Parent task: #{var VECTOR_TASK_ID}\\\\n- Memory IDs: {var MEMORY_CONTEXT.memory_ids}\\\\n- Related tasks: {var RELATED_TASKS.ids}\\\\n- Documentation: {var DOCS_INDEX.paths}\\\\n- Total batches: {var NUM_BATCHES} ({var TOTAL_ESTIMATE}h total)\\\\n- Validation agents: {var SELECTED_AGENTS}",'."\\n"
    .'                            priority: "{var BATCH_CRITICAL > 0 ? high : medium}",'."\\n"
    .'                            estimate: var BATCH_ESTIMATE,'."\\n"
    .'                            tags: ["validation-fix", "batch-{batch_index}"],'."\\n"
    .'                            parent_id: var TASK_PARENT_ID'."\\n"
    .'                        }') → STORE-AS(var CREATED_TASKS[] = '{task_id}') → OUTPUT(Created batch {batch_index}/{var NUM_BATCHES}: {var BATCH_ESTIMATE}h ({var BATCH_ISSUES.count} issues))] → END-IF] → END-FOREACH] → END-IF
 - OUTPUT(Tasks created: {var CREATED_TASKS.count} (total estimate: {var TOTAL_ESTIMATE}h))
</guideline>
<guideline id="phase5-completion">
GOAL(Complete validation, update task status, store summary to memory)
## Examples
 - OUTPUT( === PHASE 5: VALIDATION COMPLETE ===)
 - STORE-AS(var VALIDATION_SUMMARY = '{all_issues_count, tasks_created_count, pass_rate}')
 - STORE-AS(var VALIDATION_STATUS = 'IF({var CRITICAL_ISSUES.count} === 0 AND {var MISSING_REQUIREMENTS.count} === 0) → THEN → [PASSED] → ELSE → [NEEDS_WORK] → END-IF')
 - mcp__vector-memory__store_memory('{content: "Validation of var TASK_DESCRIPTION\\\\n\\\\nStatus: {var VALIDATION_STATUS}\\\\nCritical: {var CRITICAL_ISSUES.count}\\\\nMajor: {var MAJOR_ISSUES.count}\\\\nMinor: {var MINOR_ISSUES.count}\\\\nTasks created: {var CREATED_TASKS.count}\\\\n\\\\nFindings:\\\\n{summary of key findings}", category: "code-solution", tags: ["validation", "audit"]}')
 - IF({var IS_VECTOR_TASK} === true) → THEN → [IF({var VALIDATION_STATUS} === "PASSED" AND {var CREATED_TASKS.count} === 0) → THEN → [mcp__vector-task__task_update('{task_id: var VECTOR_TASK_ID, status: "validated", comment: "Validation PASSED. All requirements implemented, no issues found.", append_comment: true}') → OUTPUT(✅ Task #var VECTOR_TASK_ID marked as VALIDATED)] → END-IF → IF({var CREATED_TASKS.count} > 0) → THEN → [mcp__vector-task__task_update('{task_id: var VECTOR_TASK_ID, status: "pending", comment: "Validation found issues. Created {var CREATED_TASKS.count} fix tasks: Critical: {var CRITICAL_ISSUES.count}, Major: {var MAJOR_ISSUES.count}, Minor: {var MINOR_ISSUES.count}, Missing: {var MISSING_REQUIREMENTS.count}. Returning to pending - fix tasks must be completed before re-validation.", append_comment: true}') → OUTPUT(⏳ Task #var VECTOR_TASK_ID returned to PENDING ({var CREATED_TASKS.count} fix tasks required before re-validation))] → END-IF] → END-IF
 - OUTPUT( === VALIDATION REPORT === Task: {var TASK_DESCRIPTION} Status: {var VALIDATION_STATUS}  | Metric | Count | |--------|-------| | Critical issues | {var CRITICAL_ISSUES.count} | | Major issues | {var MAJOR_ISSUES.count} | | Minor issues | {var MINOR_ISSUES.count} | | Missing requirements | {var MISSING_REQUIREMENTS.count} | | Tasks created | {var CREATED_TASKS.count} |  {IF var CREATED_TASKS.count > 0: "Follow-up tasks: {var CREATED_TASKS}"}  Validation stored to vector memory.)
</guideline>
<guideline id="error-handling">
Graceful error handling for validation process
## Examples
 - IF(vector task not found) → THEN → [Report: "Vector task #{id} not found" → Suggest: Check task ID with mcp__vector-task__task_list → Abort validation] → END-IF
 - IF(vector task not in validatable status) → THEN → [Report: "Vector task #{id} status is {status}, not completed/tested/validated" → Suggest: Run /do:async task #{id} first → Abort validation] → END-IF
 - IF(no documentation found) → THEN → [Warn: "No documentation in .docs/ for this task" → Continue with limited validation (code-only checks)] → END-IF
 - IF(agent validation fails) → THEN → [Log: "Validation agent {N} failed: {error}" → Continue with remaining agents → Report partial validation in summary] → END-IF
 - IF(task creation fails) → THEN → [Log: "Failed to create task: {error}" → Store issue details to vector memory for manual review → Continue with remaining tasks] → END-IF
</guideline>
<guideline id="constraints">
Validation constraints and limits
## Examples
 - Max 6 parallel validation agents per batch
 - Max 20 tasks created per validation run
 - Validation timeout: 5 minutes per agent
 - VERIFY-SUCCESS(completed_status_enforced = true (for vector tasks) parallel_agents_used = true documentation_checked = true results_stored_to_memory = true no_direct_fixes = true)
</guideline>
<guideline id="example-vector-task">
SCENARIO(Validate completed vector task)
## Examples
 - **input**: "task 15" or "validate task:15"
 - **detection**: Task #15 loaded, status: completed
 - **flow**: Task Detection → Context → Docs → Parallel Validation (5 agents) → Aggregate → Create Tasks → Complete
 - **result**: Validation PASSED/NEEDS_WORK, N tasks created
</guideline>
<guideline id="example-plain-request">
SCENARIO(Validate work by description)
## Examples
 - **input**: "validate user authentication implementation"
 - **flow**: Context from memory → Docs requirements → Parallel Validation → Aggregate → Create Tasks → Report
 - **result**: Validation report with findings and created tasks
</guideline>
<guideline id="example-rerun">
SCENARIO(Re-run validation (idempotent))
## Examples
 - **input**: "task 15" (already validated before)
 - **behavior**: Skips existing tasks, only creates NEW issues found
 - **result**: Same/updated validation report, no duplicate tasks
</guideline>
<guideline id="response-format">
=== headers | Parallel: agent batch indicators | Tables: validation results | No filler | Created tasks listed
</guideline>
</guidelines>
</command>