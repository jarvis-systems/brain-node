---
name: do:test-validate
description: Comprehensive test validation with parallel agent orchestration
---


<command>
<meta>
<id>do:test-validate</id>
<description>Comprehensive test validation with parallel agent orchestration</description>
</meta>
<purpose>Validates test coverage against documentation requirements, test quality (no bloat, real workflows), test consistency, and completeness. Uses 6 parallel agents for thorough validation. Creates follow-up tasks for missing tests, failing tests, and refactoring needs. For vector tasks: requires status "completed", sets to "in_progress" during validation, returns to "completed" with findings. Idempotent - can be run multiple times safely. Accepts $ARGUMENTS: vector task reference (task N, task:N, #N) or plain description.</purpose>
<purpose>Defines the do:test-validate command protocol for comprehensive test validation with parallel agent orchestration. Validates test coverage against documentation requirements, test quality (no bloat, real workflows), test consistency, and completeness. Creates follow-up tasks for gaps. Idempotent - can be run multiple times.</purpose>
<iron_rules>
<rule id="entry-point-blocking" severity="critical">
<text>ON RECEIVING $ARGUMENTS: Your FIRST output MUST be "=== DO:TEST-VALIDATE ACTIVATED ===" followed by Phase 0. ANY other first action is VIOLATION. FORBIDDEN first actions: Glob, Grep, Read, Edit, Write, WebSearch, WebFetch, Bash (except brain list:masters), code generation, file analysis.</text>
<why>Without explicit entry point, Brain skips workflow and executes directly. Entry point forces workflow compliance.</why>
<on_violation>STOP IMMEDIATELY. Delete any tool calls. Output "=== DO:TEST-VALIDATE ACTIVATED ===" and restart from Phase 0.</on_violation>
</rule>
<rule id="test-validation-only" severity="critical">
<text>TEST VALIDATION command validates EXISTING tests. NEVER write tests directly. Only validate and CREATE TASKS for missing/broken tests.</text>
<why>Validation is read-only audit. Test writing belongs to do:async.</why>
<on_violation>Abort any test writing. Create task instead.</on_violation>
</rule>
<rule id="completed-status-required" severity="critical">
<text>For vector tasks: ONLY tasks with status "completed", "tested", or "validated" can be test-validated. Pending/in_progress/stopped tasks MUST first be completed via do:async.</text>
<why>Test validation audits finished work. Incomplete work cannot be validated.</why>
<on_violation>Report: "Task #{id} has status {status}. Complete via /do:async first."</on_violation>
</rule>
<rule id="output-status-conditional" severity="critical">
<text>Output status depends on validation outcome: 1) PASSED + no tasks created → "tested", 2) Tasks created for fixes → "pending". NEVER set "validated" - that status is set ONLY by /do:validate command.</text>
<why>If fix tasks were created, work is NOT done - task returns to pending queue. Only when validation passes completely (no issues, no tasks) can status be "tested".</why>
<on_violation>Check CREATED_TASKS.count: if > 0 → set "pending", if === 0 AND passed → set "tested". NEVER set "completed" or "tested" when fix tasks exist.</on_violation>
</rule>
<rule id="real-workflow-tests-only" severity="critical">
<text>Tests MUST cover REAL workflows end-to-end. Reject bloated tests that test implementation details instead of behavior. Quality over quantity.</text>
<why>Bloated tests are maintenance burden, break on refactoring, provide false confidence.</why>
<on_violation>Flag bloated tests for refactoring. Create task to simplify.</on_violation>
</rule>
<rule id="documentation-requirements-coverage" severity="critical">
<text>EVERY requirement in .docs/ MUST have corresponding test coverage. Missing coverage = immediate task creation.</text>
<why>Documentation defines expected behavior. Untested requirements are unverified.</why>
<on_violation>Create task for each uncovered requirement.</on_violation>
</rule>
<rule id="parallel-agent-orchestration" severity="high">
<text>Test validation phases MUST use parallel agent orchestration (5-6 agents simultaneously) for efficiency. Each agent validates one aspect.</text>
<why>Parallel validation reduces time and maximizes coverage.</why>
<on_violation>Restructure validation into parallel Task() calls.</on_violation>
</rule>
<rule id="idempotent-validation" severity="high">
<text>Test validation is IDEMPOTENT. Running multiple times produces same result (no duplicate tasks, no repeated analysis).</text>
<why>Allows safe re-runs without side effects.</why>
<on_violation>Check existing tasks before creating. Skip duplicates.</on_violation>
</rule>
<rule id="vector-memory-mandatory" severity="high">
<text>ALL test validation results MUST be stored to vector memory. Search memory BEFORE creating duplicate tasks.</text>
<why>Memory prevents duplicate work and provides audit trail.</why>
<on_violation>Store validation summary with findings and created tasks.</on_violation>
</rule>
<rule id="task-size-5-8h" severity="high">
<text>Each created task MUST have estimate between 5-8 hours. Never create tasks < 5h (consolidate) or > 8h (split).</text>
<why>Optimal task size for focused work sessions. Too small = context switching overhead. Too large = hard to track progress.</why>
<on_violation>Merge small issues into consolidated task OR split large task into 5-8h batches.</on_violation>
</rule>
<rule id="task-comprehensive-context" severity="critical">
<text>Each task MUST include: all file:line references, memory IDs, related task IDs, documentation paths, detailed issue descriptions with suggestions.</text>
<why>Enables full context restoration without re-exploration. Saves agent time on task pickup.</why>
<on_violation>Add missing context references before creating task.</on_violation>
</rule>
</iron_rules>
<guidelines>
<guideline id="phase-minus1-task-detection">
GOAL(Detect if $ARGUMENTS is a vector task reference and fetch task details)
## Examples
 - Parse $ARGUMENTS for task reference patterns: "task N", "task:N", "task #N", "task-N", "#N"
 - IF($ARGUMENTS matches task reference pattern) → THEN → [Extract task_id from pattern → STORE-AS(var IS_VECTOR_TASK = 'true') → STORE-AS(var VECTOR_TASK_ID = '{extracted_id}') → mcp__vector-task__task_get('{task_id: var VECTOR_TASK_ID}') → STORE-AS(var VECTOR_TASK = '{task object with title, content, status, parent_id, priority, tags}') → IF({var VECTOR_TASK.status} NOT IN (completed, tested, validated)) → THEN → [OUTPUT(=== TEST VALIDATION BLOCKED === Task #{var VECTOR_TASK_ID} has status: {var VECTOR_TASK.status} Only COMPLETED/TESTED/VALIDATED tasks can be test-validated. Run /do:async task {var VECTOR_TASK_ID} to complete first.) → ABORT validation] → END-IF → IF({var VECTOR_TASK.parent_id} !== null) → THEN → [mcp__vector-task__task_get('{task_id: var VECTOR_TASK.parent_id}') → STORE-AS(var PARENT_TASK = '{parent task for context}')] → END-IF → mcp__vector-task__task_list('{parent_id: var VECTOR_TASK_ID, limit: 50}') → STORE-AS(var SUBTASKS = '{list of subtasks}') → STORE-AS(var TASK_DESCRIPTION = '{var VECTOR_TASK.title + var VECTOR_TASK.content}') → STORE-AS(var TASK_PARENT_ID = 'var VECTOR_TASK_ID') → OUTPUT(=== VECTOR TASK LOADED === Task #var VECTOR_TASK_ID: {var VECTOR_TASK.title} Status: {var VECTOR_TASK.status} | Priority: {var VECTOR_TASK.priority} Parent: {var PARENT_TASK.title or "none"} Subtasks: {var SUBTASKS.count})] → END-IF
 - IF($ARGUMENTS is plain description) → THEN → [STORE-AS(var IS_VECTOR_TASK = 'false') → STORE-AS(var TASK_DESCRIPTION = '$ARGUMENTS') → STORE-AS(var TASK_PARENT_ID = 'null')] → END-IF
</guideline>
<guideline id="phase0-validation-preview">
GOAL(Discover available agents and present test validation scope for approval)
## Examples
 - OUTPUT(=== PHASE 0: TEST VALIDATION PREVIEW ===)
 - Bash(brain list:masters) → [Get available agents with capabilities] → END-Bash
 - STORE-AS(var AVAILABLE_AGENTS = '{agent_id: description mapping}')
 - Bash(brain docs {keywords from var TASK_DESCRIPTION}) → [Get documentation INDEX preview] → END-Bash
 - STORE-AS(var DOCS_PREVIEW = 'Documentation files available')
 - OUTPUT(Task: {var TASK_DESCRIPTION} Available agents: {var AVAILABLE_AGENTS.count} Documentation files: {var DOCS_PREVIEW.count}  Test validation will delegate to agents: 1. VectorMaster - deep memory research for test context 2. DocumentationMaster - testable requirements extraction 3. Selected agents - test discovery + parallel validation (6 aspects)  ⚠️  APPROVAL REQUIRED ✅ approved/yes - start test validation | ❌ no/modifications)
 - WAIT for user approval
 - VERIFY-SUCCESS(User approved)
 - IF(rejected) → THEN → [Accept modifications → Re-present → WAIT] → END-IF
 - IMMEDIATELY after approval - set task in_progress (test validation IS execution)
 - IF({var IS_VECTOR_TASK} === true) → THEN → [mcp__vector-task__task_update('{task_id: var VECTOR_TASK_ID, status: "in_progress", comment: "Test validation started after approval", append_comment: true}') → OUTPUT(📋 Vector task #var VECTOR_TASK_ID started (test validation phase))] → END-IF
</guideline>
<guideline id="phase1-context-gathering">
GOAL(Delegate deep test context research to VectorMaster agent)
## Examples
 - OUTPUT( === PHASE 1: DEEP TEST CONTEXT === Delegating to VectorMaster for deep memory research...)
 - SELECT vector-master from var AVAILABLE_AGENTS
 - STORE-AS(var CONTEXT_AGENT = '{vector-master agent_id}')
 - Task(mcp__brain__agent({var CONTEXT_AGENT}) 'DEEP MEMORY RESEARCH for test validation of "var TASK_DESCRIPTION": 1) Multi-probe search: past test implementations, test patterns, testing best practices, test failures, coverage gaps 2) Search across categories: code-solution, learning, bug-fix 3) Extract test-specific insights: what worked, what failed, patterns used 4) Return: {test_history: [...], test_patterns: [...], past_failures: [...], quality_standards: [...], key_insights: [...]}. Store consolidated test context.')
 - STORE-AS(var TEST_MEMORY_CONTEXT = '{VectorMaster agent results}')
 - mcp__vector-task__task_list('{query: "test var TASK_DESCRIPTION", limit: 10}')
 - STORE-AS(var RELATED_TEST_TASKS = 'Related test tasks')
 - OUTPUT(Context gathered via {var CONTEXT_AGENT}: - Test insights: {var TEST_MEMORY_CONTEXT.key_insights.count} - Related test tasks: {var RELATED_TEST_TASKS.count})
</guideline>
<guideline id="phase1-documentation-extraction">
GOAL(Extract ALL testable requirements from .docs/ via DocumentationMaster)
## Examples
 - OUTPUT( === PHASE 1: DOCUMENTATION REQUIREMENTS ===)
 - Bash(brain docs {keywords from var TASK_DESCRIPTION}) → [Get documentation INDEX] → END-Bash
 - STORE-AS(var DOCS_INDEX = 'Documentation file paths')
 - IF({var DOCS_INDEX} not empty) → THEN → [Task(mcp__brain__agent(documentation-master) 'Extract ALL TESTABLE requirements from documentation files: {var DOCS_INDEX paths}. For each requirement identify: [{requirement_id, description, testable_scenarios: [...], acceptance_criteria, expected_test_type: unit|feature|integration|e2e, priority}]. Focus on BEHAVIOR not implementation. Store to vector memory.') → STORE-AS(var DOCUMENTATION_REQUIREMENTS = '{structured testable requirements list}')] → END-IF
 - IF({var DOCS_INDEX} empty) → THEN → [STORE-AS(var DOCUMENTATION_REQUIREMENTS = '[]') → OUTPUT(WARNING: No documentation found. Test validation will be limited to existing tests only.)] → END-IF
 - OUTPUT(Testable requirements extracted: {var DOCUMENTATION_REQUIREMENTS.count} {requirements summary with test types})
</guideline>
<guideline id="phase2-test-discovery">
GOAL(Select best agent from var AVAILABLE_AGENTS and discover all existing tests)
## Examples
 - OUTPUT( === PHASE 2: TEST DISCOVERY ===)
 - SELECT AGENT for test discovery from {var AVAILABLE_AGENTS} (prefer explore for codebase scanning)
 - STORE-AS(var DISCOVERY_AGENT = '{selected agent_id based on descriptions}')
 - Task(mcp__brain__agent({var DISCOVERY_AGENT}) 'DEEP RESEARCH - TEST DISCOVERY for "var TASK_DESCRIPTION": 1) Search vector memory for past test patterns and locations 2) Scan codebase for test directories (tests/, spec/, __tests__) 3) Find ALL related test files: unit, feature, integration, e2e 4) Analyze test structure and coverage 5) Return: [{test_file, test_type, test_classes, test_methods, related_source_files}]. Store findings to vector memory.')
 - STORE-AS(var DISCOVERED_TESTS = '{list of test files with metadata}')
 - OUTPUT(Tests discovered via {var DISCOVERY_AGENT}: {var DISCOVERED_TESTS.count} files {test files summary by type})
</guideline>
<guideline id="phase3-parallel-validation">
GOAL(Select best agents from var AVAILABLE_AGENTS and launch parallel test validation)
## Examples
 - OUTPUT( === PHASE 3: PARALLEL TEST VALIDATION ===)
 - AGENT SELECTION: Analyze var AVAILABLE_AGENTS descriptions and select BEST agent for each test validation aspect:
 - (ASPECT 1 - REQUIREMENTS COVERAGE: Select agent for requirements-to-test mapping (vector-master for memory, explore for codebase) + ASPECT 2 - TEST QUALITY: Select agent for code quality analysis (explore for pattern detection) + ASPECT 3 - WORKFLOW COVERAGE: Select agent for workflow analysis (explore for flow tracing) + ASPECT 4 - TEST CONSISTENCY: Select agent for consistency analysis (explore for pattern matching) + ASPECT 5 - TEST ISOLATION: Select agent for isolation analysis (explore for dependency scanning) + ASPECT 6 - TEST EXECUTION: Select agent capable of running tests (explore with bash access))
 - STORE-AS(var SELECTED_AGENTS = '{aspect: agent_id mapping based on var AVAILABLE_AGENTS}')
 - OUTPUT(Selected agents for test validation: {var SELECTED_AGENTS mapping}  Launching test validation agents in parallel...)
 - PARALLEL BATCH: Launch selected agents simultaneously with DEEP RESEARCH tasks
 - (Task(mcp__brain__agent({var SELECTED_AGENTS.coverage}) 'DEEP RESEARCH - REQUIREMENTS COVERAGE for "var TASK_DESCRIPTION": 1) Search vector memory for past requirement-test mappings 2) Compare {var DOCUMENTATION_REQUIREMENTS} against {var DISCOVERED_TESTS} 3) For each requirement verify test exists 4) Return: [{requirement_id, coverage_status: covered|partial|missing, test_file, test_method, gap_description, memory_refs}]. Store findings.') + Task(mcp__brain__agent({var SELECTED_AGENTS.quality}) 'DEEP RESEARCH - TEST QUALITY for "var TASK_DESCRIPTION": 1) Search memory for test quality standards 2) Analyze {var DISCOVERED_TESTS} for bloat indicators 3) Check: excessive mocking, implementation testing, redundant assertions, copy-paste 4) Return: [{test_file, test_method, bloat_type, severity, suggestion}]. Store findings.') + Task(mcp__brain__agent({var SELECTED_AGENTS.workflow}) 'DEEP RESEARCH - WORKFLOW COVERAGE for "var TASK_DESCRIPTION": 1) Search memory for workflow patterns 2) Verify {var DISCOVERED_TESTS} cover complete user workflows 3) Check: happy path, error paths, edge cases, boundaries 4) Return: [{workflow, coverage_status, missing_scenarios}]. Store findings.') + Task(mcp__brain__agent({var SELECTED_AGENTS.consistency}) 'DEEP RESEARCH - TEST CONSISTENCY for "var TASK_DESCRIPTION": 1) Search memory for project test conventions 2) Check {var DISCOVERED_TESTS} for consistency 3) Verify: naming, structure, assertions, fixtures, setup/teardown 4) Return: [{test_file, inconsistency_type, description, suggestion}]. Store findings.') + Task(mcp__brain__agent({var SELECTED_AGENTS.isolation}) 'DEEP RESEARCH - TEST ISOLATION for "var TASK_DESCRIPTION": 1) Search memory for isolation issues 2) Verify {var DISCOVERED_TESTS} are properly isolated 3) Check: shared state, order dependency, external calls, cleanup 4) Return: [{test_file, isolation_issue, severity, suggestion}]. Store findings.') + Task(mcp__brain__agent({var SELECTED_AGENTS.execution}) 'DEEP RESEARCH - TEST EXECUTION for "var TASK_DESCRIPTION": 1) Search memory for past test failures 2) Run tests related to task 3) Identify flaky tests 4) Return: [{test_file, execution_status: pass|fail|flaky, error_message, execution_time}]. Store findings.'))
 - STORE-AS(var VALIDATION_BATCH_1 = '{results from all agents}')
 - OUTPUT(Batch complete: {var SELECTED_AGENTS.count} test validation checks finished)
</guideline>
<guideline id="phase4-results-aggregation">
GOAL(Aggregate all test validation results and categorize issues)
## Examples
 - OUTPUT( === PHASE 4: RESULTS AGGREGATION ===)
 - Merge results from all validation agents
 - STORE-AS(var ALL_TEST_ISSUES = '{merged issues from all agents}')
 - Categorize issues:
 - STORE-AS(var MISSING_COVERAGE = '{requirements without tests}')
 - STORE-AS(var PARTIAL_COVERAGE = '{requirements with incomplete tests}')
 - STORE-AS(var BLOATED_TESTS = '{tests flagged for bloat}')
 - STORE-AS(var MISSING_WORKFLOWS = '{workflows without end-to-end coverage}')
 - STORE-AS(var INCONSISTENT_TESTS = '{tests with consistency issues}')
 - STORE-AS(var ISOLATION_ISSUES = '{tests with isolation problems}')
 - STORE-AS(var FAILING_TESTS = '{tests that fail or are flaky}')
 - OUTPUT(Test validation results: - Missing coverage: {var MISSING_COVERAGE.count} requirements - Partial coverage: {var PARTIAL_COVERAGE.count} requirements - Bloated tests: {var BLOATED_TESTS.count} tests - Missing workflows: {var MISSING_WORKFLOWS.count} workflows - Inconsistent tests: {var INCONSISTENT_TESTS.count} tests - Isolation issues: {var ISOLATION_ISSUES.count} tests - Failing/flaky tests: {var FAILING_TESTS.count} tests)
</guideline>
<guideline id="phase5-task-creation">
GOAL(Create consolidated tasks (5-8h each) for test gaps with comprehensive context)
## Examples
 - OUTPUT( === PHASE 5: TASK CREATION (CONSOLIDATED) ===)
 - Check existing tasks to avoid duplicates
 - mcp__vector-task__task_list('{query: "test var TASK_DESCRIPTION", limit: 20}')
 - STORE-AS(var EXISTING_TEST_TASKS = 'Existing test tasks')
 - CONSOLIDATION STRATEGY: Group issues into 5-8 hour task batches
 - (Calculate total estimate for ALL issues: + - Missing coverage: ~2h per requirement (tests + assertions) + - Failing tests: ~1h per test (debug + fix) + - Bloated tests: ~1.5h per test (refactor + verify) + - Missing workflows: ~3h per workflow (e2e test suite) + - Isolation issues: ~1h per test (refactor + verify) + STORE-AS(var TOTAL_ESTIMATE = '{sum of all issue estimates in hours}'))
 - IF({var TOTAL_ESTIMATE} <= 8) → THEN → [ALL issues fit into ONE consolidated task (5-8h range) → IF({var ALL_TEST_ISSUES.count} > 0 AND NOT exists similar in var EXISTING_TEST_TASKS) → THEN → [mcp__vector-task__task_create('{'."\\n"
    .'                        title: "Test fixes: var TASK_DESCRIPTION",'."\\n"
    .'                        content: "Consolidated test validation findings for var TASK_DESCRIPTION.\\\\n\\\\nTotal estimate: {var TOTAL_ESTIMATE}h\\\\n\\\\n## Missing Coverage ({var MISSING_COVERAGE.count})\\\\n{FOR each req: - {req.description} | Type: {req.expected_test_type} | File: {req.related_file}:{req.line} | Scenarios: {req.testable_scenarios}}\\\\n\\\\n## Failing Tests ({var FAILING_TESTS.count})\\\\n{FOR each test: - {test.test_file}:{test.test_method} | Error: {test.error_message} | Status: {test.execution_status}}\\\\n\\\\n## Bloated Tests ({var BLOATED_TESTS.count})\\\\n{FOR each test: - {test.test_file}:{test.test_method} | Bloat: {test.bloat_type} | Suggestion: {test.suggestion}}\\\\n\\\\n## Missing Workflows ({var MISSING_WORKFLOWS.count})\\\\n{FOR each wf: - {wf.workflow} | Missing: {wf.missing_scenarios}}\\\\n\\\\n## Isolation Issues ({var ISOLATION_ISSUES.count})\\\\n{FOR each test: - {test.test_file} | Issue: {test.isolation_issue} | Fix: {test.suggestion}}\\\\n\\\\n## Context References\\\\n- Memory IDs: {var TEST_MEMORY_CONTEXT.memory_ids}\\\\n- Related tasks: {var RELATED_TEST_TASKS.ids}\\\\n- Documentation: {var DOCS_INDEX.paths}",'."\\n"
    .'                        priority: "high",'."\\n"
    .'                        estimate: var TOTAL_ESTIMATE,'."\\n"
    .'                        tags: ["test-validation", "consolidated"],'."\\n"
    .'                        parent_id: var TASK_PARENT_ID'."\\n"
    .'                    }') → STORE-AS(var CREATED_TASKS[] = '{task_id}') → OUTPUT(Created consolidated task: Test fixes ({var TOTAL_ESTIMATE}h, {var ALL_TEST_ISSUES.count} issues))] → END-IF] → END-IF
 - IF({var TOTAL_ESTIMATE} > 8) → THEN → [Split into multiple 5-8h task batches → STORE-AS(var BATCH_SIZE = '6') → STORE-AS(var NUM_BATCHES = '{ceil(var TOTAL_ESTIMATE / 6)}') → Group issues by priority and type into batches of ~6h each → FOREACH(batch_index in range(1, var NUM_BATCHES)) → [STORE-AS(var BATCH_ISSUES = '{slice of issues for this batch, ~6h worth}') → STORE-AS(var BATCH_ESTIMATE = '{sum of batch issue estimates}') → IF(NOT exists similar in var EXISTING_TEST_TASKS) → THEN → [mcp__vector-task__task_create('{'."\\n"
    .'                            title: "Test fixes batch {batch_index}/{var NUM_BATCHES}: var TASK_DESCRIPTION",'."\\n"
    .'                            content: "Test validation batch {batch_index} of {var NUM_BATCHES} for var TASK_DESCRIPTION.\\\\n\\\\nBatch estimate: {var BATCH_ESTIMATE}h\\\\n\\\\n## Issues in this batch\\\\n{FOR each issue in var BATCH_ISSUES:\\\\n### {issue.type}: {issue.title}\\\\n- File: {issue.file}:{issue.line}\\\\n- Description: {issue.description}\\\\n- Severity: {issue.severity}\\\\n- Suggestion: {issue.suggestion}\\\\n- Related memory: {issue.memory_refs}\\\\n}\\\\n\\\\n## Full Context References\\\\n- Parent task: #{var VECTOR_TASK_ID}\\\\n- Memory IDs: {var TEST_MEMORY_CONTEXT.memory_ids}\\\\n- Related tasks: {var RELATED_TEST_TASKS.ids}\\\\n- Documentation: {var DOCS_INDEX.paths}\\\\n- Total batches: {var NUM_BATCHES} ({var TOTAL_ESTIMATE}h total)",'."\\n"
    .'                            priority: "{batch_index === 1 ? high : medium}",'."\\n"
    .'                            estimate: var BATCH_ESTIMATE,'."\\n"
    .'                            tags: ["test-validation", "batch-{batch_index}"],'."\\n"
    .'                            parent_id: var TASK_PARENT_ID'."\\n"
    .'                        }') → STORE-AS(var CREATED_TASKS[] = '{task_id}') → OUTPUT(Created batch {batch_index}/{var NUM_BATCHES}: {var BATCH_ESTIMATE}h)] → END-IF] → END-FOREACH] → END-IF
 - OUTPUT(Tasks created: {var CREATED_TASKS.count} (total estimate: {var TOTAL_ESTIMATE}h))
</guideline>
<guideline id="phase6-completion">
GOAL(Complete test validation, update task status, store summary to memory)
## Examples
 - OUTPUT( === PHASE 6: TEST VALIDATION COMPLETE ===)
 - STORE-AS(var COVERAGE_RATE = '{covered_requirements / total_requirements * 100}%')
 - STORE-AS(var TEST_HEALTH_SCORE = '{100 - (bloat_count + isolation_count + failing_count) / total_tests * 100}%')
 - STORE-AS(var VALIDATION_STATUS = 'IF({var MISSING_COVERAGE.count} === 0 AND {var FAILING_TESTS.count} === 0) → THEN → [PASSED] → ELSE → [NEEDS_WORK] → END-IF')
 - mcp__vector-memory__store_memory('{content: "Test validation of var TASK_DESCRIPTION\\\\n\\\\nStatus: {var VALIDATION_STATUS}\\\\nCoverage rate: {var COVERAGE_RATE}\\\\nTest health: {var TEST_HEALTH_SCORE}\\\\n\\\\nMissing coverage: {var MISSING_COVERAGE.count}\\\\nFailing tests: {var FAILING_TESTS.count}\\\\nBloated tests: {var BLOATED_TESTS.count}\\\\nTasks created: {var CREATED_TASKS.count}\\\\n\\\\nKey findings: {summary}", category: "code-solution", tags: ["test-validation", "audit"]}')
 - IF({var IS_VECTOR_TASK} === true) → THEN → [IF({var VALIDATION_STATUS} === "PASSED" AND {var CREATED_TASKS.count} === 0) → THEN → [mcp__vector-task__task_update('{task_id: var VECTOR_TASK_ID, status: "tested", comment: "Test validation PASSED. All requirements covered, all tests passing, no critical issues.", append_comment: true}') → OUTPUT(✅ Task #var VECTOR_TASK_ID marked as TESTED)] → END-IF → IF({var CREATED_TASKS.count} > 0) → THEN → [mcp__vector-task__task_update('{task_id: var VECTOR_TASK_ID, status: "pending", comment: "Test validation found issues. Coverage: {var COVERAGE_RATE}, Health: {var TEST_HEALTH_SCORE}. Created {var CREATED_TASKS.count} fix tasks. Returning to pending - fix tasks must be completed before re-testing.", append_comment: true}') → OUTPUT(⏳ Task #var VECTOR_TASK_ID returned to PENDING ({var CREATED_TASKS.count} fix tasks required before re-testing))] → END-IF] → END-IF
 - OUTPUT( === TEST VALIDATION REPORT === Task: {var TASK_DESCRIPTION} Status: {var VALIDATION_STATUS}  | Metric | Value | |--------|-------| | Requirements coverage | {var COVERAGE_RATE} | | Test health score | {var TEST_HEALTH_SCORE} | | Total tests | {var DISCOVERED_TESTS.count} | | Passing tests | {passing_count} | | Failing/flaky tests | {var FAILING_TESTS.count} |  | Issue Type | Count | |------------|-------| | Missing coverage | {var MISSING_COVERAGE.count} | | Partial coverage | {var PARTIAL_COVERAGE.count} | | Bloated tests | {var BLOATED_TESTS.count} | | Missing workflows | {var MISSING_WORKFLOWS.count} | | Isolation issues | {var ISOLATION_ISSUES.count} |  Tasks created: {var CREATED_TASKS.count} {IF var CREATED_TASKS.count > 0: "Follow-up tasks: {var CREATED_TASKS}"}  Test validation stored to vector memory.)
</guideline>
<guideline id="error-handling">
Graceful error handling for test validation process
## Examples
 - IF(vector task not found) → THEN → [Report: "Vector task #{id} not found" → Suggest: Check task ID with mcp__vector-task__task_list → Abort validation] → END-IF
 - IF(vector task not completed) → THEN → [Report: "Vector task #{id} status is {status}, not completed" → Suggest: Run /do:async task #{id} first → Abort validation] → END-IF
 - IF(no documentation found) → THEN → [Warn: "No documentation in .docs/ for this task" → Continue with test-only validation (existing tests analysis) → Note: "Cannot verify requirements coverage without documentation"] → END-IF
 - IF(no tests found) → THEN → [Report: "No tests found for {var TASK_DESCRIPTION}" → Create task: "Write initial tests for {var TASK_DESCRIPTION}" → Continue with documentation requirements analysis] → END-IF
 - IF(test execution fails) → THEN → [Log: "Test execution failed: {error}" → Mark tests as "execution_unknown" → Continue with static analysis] → END-IF
 - IF(agent validation fails) → THEN → [Log: "Validation agent {N} failed: {error}" → Continue with remaining agents → Report partial validation in summary] → END-IF
 - IF(task creation fails) → THEN → [Log: "Failed to create task: {error}" → Store issue details to vector memory for manual review → Continue with remaining tasks] → END-IF
</guideline>
<guideline id="test-quality-criteria">
Criteria for evaluating test quality (bloat detection)
## Examples
 - 
BLOAT INDICATORS (flag for refactoring):
(Excessive mocking (>3 mocks per test) + Testing private methods directly + Testing getters/setters without logic + Copy-paste test code (>80% similarity) + Single assertion tests without context + Testing framework internals + Hard-coded magic values without explanation + Test method >50 lines + Setup >30 lines)

 - 
QUALITY INDICATORS (good tests):
(Tests behavior, not implementation + Readable test names (given_when_then) + Single responsibility per test + Proper use of fixtures/factories + Edge cases covered + Error paths tested + Fast execution (<100ms per test) + No external dependencies without mocks)
</guideline>
<guideline id="constraints">
Test validation constraints and limits
## Examples
 - Max 6 parallel validation agents per batch
 - Max 30 tasks created per validation run
 - Test execution timeout: 5 minutes total
 - Bloat threshold: >50% bloated = critical warning
 - VERIFY-SUCCESS(completed_status_enforced = true (for vector tasks) parallel_agents_used = true documentation_checked = true tests_executed = true results_stored_to_memory = true)
</guideline>
<guideline id="example-vector-task">
SCENARIO(Test validate completed vector task)
## Examples
 - **input**: "task 15" or "test-validate task:15"
 - **detection**: Task #15 loaded, status: completed
 - **flow**: Task Detection → Context → Docs → Test Discovery → Parallel Validation (6 agents) → Aggregate → Create Tasks → Complete
 - **result**: Test validation PASSED/NEEDS_WORK, coverage %, N tasks created
</guideline>
<guideline id="example-plain-request">
SCENARIO(Test validate work by description)
## Examples
 - **input**: "test-validate user authentication"
 - **flow**: Context from memory → Docs requirements → Test Discovery → Parallel Validation → Aggregate → Create Tasks → Report
 - **result**: Test validation report with coverage metrics and created tasks
</guideline>
<guideline id="example-rerun">
SCENARIO(Re-run test validation (idempotent))
## Examples
 - **input**: "task 15" (already test-validated before)
 - **behavior**: Skips existing tasks, only creates NEW issues found
 - **result**: Same/updated validation report, no duplicate tasks
</guideline>
<guideline id="response-format">
=== headers | Parallel: agent batch indicators | Tables: coverage metrics + issue counts | Coverage % | Health score | Created tasks listed
</guideline>
</guidelines>
</command>