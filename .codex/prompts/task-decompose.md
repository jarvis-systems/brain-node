---
name: task:decompose
description: Decompose large task into subtasks (each <=5-8h)
---


<command>
<meta>
<id>task:decompose</id>
<description>Decompose large task into subtasks (each <=5-8h)</description>
</meta>
<purpose>Decomposes large tasks (>5-8h estimate) into smaller, manageable subtasks. Each subtask MUST have estimate <=5-8 hours (GOLDEN RULE). Recursively flags subtasks exceeding 8h for further decomposition. Input: $ARGUMENTS = task_id. Requires mandatory user approval before creating subtasks.</purpose>
<purpose>Aggressive task decomposition with MAXIMUM parallel agent orchestration. Deep multi-agent research, comprehensive codebase analysis, creates optimal subtasks meeting 5-8h golden rule. NEVER executes - only creates.</purpose>
<iron_rules>
<rule id="golden-rule-estimate" severity="critical">
<text>Each subtask estimate MUST be <= 5-8 hours. This is the CORE PURPOSE.</text>
<why>Tasks >8h are too large for effective tracking, estimation accuracy, and focus</why>
<on_violation>Decompose further until ALL subtasks meet 5-8h. Flag for recursive /task:decompose.</on_violation>
</rule>
<rule id="max-subtasks-limit" severity="critical">
<text>Maximum 10 subtasks per parent task. NEVER create more than 10 direct children.</text>
<why>Too many subtasks indicate insufficient grouping. Cognitive overload, tracking nightmare.</why>
<on_violation>Group related work into larger subtasks (each 5-8h), mark them [needs-decomposition] for recursive /task:decompose.</on_violation>
</rule>
<rule id="parallel-agent-execution" severity="critical">
<text>Launch INDEPENDENT research agents in PARALLEL (multiple Task calls in single response)</text>
<why>Maximizes research coverage, comprehensive decomposition context</why>
<on_violation>Group independent research, launch ALL simultaneously</on_violation>
</rule>
<rule id="multi-agent-research" severity="critical">
<text>Use SPECIALIZED agents: ExploreMaster(code), DocumentationMaster(docs), VectorMaster(memory)</text>
<why>Each agent has domain expertise. Single agent misses critical decomposition context.</why>
<on_violation>Delegate to appropriate specialized agent</on_violation>
</rule>
<rule id="create-only-no-execution" severity="critical">
<text>This command ONLY creates subtasks. NEVER execute any subtask after creation.</text>
<why>Decomposition and execution are separate concerns. User decides via /task:next</why>
<on_violation>STOP immediately after subtask creation</on_violation>
</rule>
<rule id="mandatory-user-approval" severity="critical">
<text>MUST get explicit user YES/APPROVE/CONFIRM before creating subtasks</text>
<why>User must validate decomposition strategy before committing</why>
<on_violation>Present subtask list and wait for explicit confirmation</on_violation>
</rule>
<rule id="fetch-parent-first" severity="critical">
<text>MUST fetch parent task via task_get BEFORE any research</text>
<why>Cannot decompose without full understanding of parent scope</why>
<on_violation>Execute task_get first, analyze completely</on_violation>
</rule>
<rule id="correct-parent-id" severity="critical">
<text>MUST set parent_id = task_id for ALL created subtasks</text>
<why>Hierarchy integrity requires correct parent-child relationships</why>
<on_violation>Verify parent_id in every task_create</on_violation>
</rule>
<rule id="exclude-brain-directory" severity="critical">
<text>NEVER analyze .brain/ when decomposing code tasks</text>
<why>Brain system internals are not project code</why>
<on_violation>Skip .brain/ in all exploration</on_violation>
</rule>
</iron_rules>
<guidelines>
<guideline id="phase0-parse">
GOAL(Extract and validate task_id from arguments)
## Examples
 - 
STEP 1 - Parse:
(Extract task_id from $ARGUMENTS + VALIDATE(task_id is numeric) → FAILS → [Request valid task_id from user] → END-VALIDATE + STORE-AS(var TASK_ID = 'extracted task_id'))
</guideline>
<guideline id="phase1-fetch">
GOAL(Fetch and fully understand parent task)
## Examples
 - 
STEP 1 - Fetch parent task:
(mcp__vector-task__task_get('{task_id: $TASK_ID}') + VALIDATE(Task exists and has content) → FAILS → [Report: Task not found] → END-VALIDATE + STORE-AS(var PARENT_TASK = '{id, title, content, priority, tags, status, estimate}'))

 - 
STEP 2 - Check existing subtasks:
(mcp__vector-task__task_list('{parent_id: $TASK_ID, limit: 50}') + IF(existing subtasks > 0) → THEN → [Ask: "Task has {count} subtasks. (1) Add more, (2) Replace all, (3) Abort"] → END-IF + STORE-AS(var EXISTING_SUBTASKS = '[{id, title, status}]'))

 - 
STEP 3 - Analyze parent task type:
(Determine task type: code | architecture | documentation | testing | infrastructure + Identify domain: backend | frontend | database | api | devops + Assess complexity: simple | moderate | complex | very-complex + STORE-AS(var TASK_TYPE = '{type, domain, complexity}'))
</guideline>
<guideline id="phase2-parallel-research">
GOAL(PARALLEL: Deep memory research + documentation analysis)
## Examples
 - 
BATCH 1 - Memory & Docs (LAUNCH IN PARALLEL):
(Task(mcp__brain__agent(vector-master), 'TASK → [(DEEP MEMORY RESEARCH for decomposition of: $PARENT_TASK.title + Multi-probe search strategy: + Probe 1: "task decomposition {domain} patterns strategies" (tool-usage) + Probe 2: "$PARENT_TASK.title implementation breakdown structure" (architecture) + Probe 3: "{domain} subtask estimation accuracy lessons" (learning) + Probe 4: "similar task decomposition mistakes pitfalls" (bug-fix) + Probe 5: "{domain} code structure component boundaries" (code-solution) + EXTRACT: decomposition patterns, common structures, past estimates, warnings + OUTPUT: actionable decomposition insights)] → END-TASK', 'OUTPUT({memories_found:N,patterns:[],estimates_accuracy:[],warnings:[]})', 'STORE-AS(var MEMORY_INSIGHTS)') + Task(mcp__brain__agent(documentation-master), 'TASK → [(DOCUMENTATION RESEARCH for task: $PARENT_TASK.title + Search brain docs for: {domain}, {related_concepts} + Find: API specs, architecture docs, implementation guides + EXTRACT: requirements, constraints, patterns, dependencies + OUTPUT: documentation-based decomposition guidance)] → END-TASK', 'OUTPUT({docs_found:N,requirements:[],patterns:[],constraints:[]})', 'STORE-AS(var DOC_INSIGHTS)'))

 - NOTE: VectorMaster + DocumentationMaster run SIMULTANEOUSLY
</guideline>
<guideline id="phase3-parallel-code">
GOAL(PARALLEL: Multi-aspect codebase analysis for code tasks)
## Examples
 - CONDITIONAL: If $TASK_TYPE.type === "code":
 - 
BATCH 2 - Codebase Analysis (LAUNCH IN PARALLEL):
(Task(mcp__brain__agent(explore), 'TASK → [(COMPONENT ANALYSIS for: $PARENT_TASK.title + Thoroughness: very thorough + ANALYZE: affected files, classes, methods, namespaces + IDENTIFY: component boundaries, natural split points + EXTRACT: {files:[],classes:[],methods:[],boundaries:[]} + FOCUS ON: where code changes will be needed)] → END-TASK', 'OUTPUT({files:N,components:[],boundaries:[],split_points:[]})', 'STORE-AS(var CODE_COMPONENTS)') + Task(mcp__brain__agent(explore), 'TASK → [(DEPENDENCY ANALYSIS for: $PARENT_TASK.title + Thoroughness: thorough + ANALYZE: imports, dependencies, coupling between modules + IDENTIFY: dependency chains, circular deps, external deps + EXTRACT: {internal_deps:[],external_deps:[],coupling_level:str} + FOCUS ON: what must be changed together vs independently)] → END-TASK', 'OUTPUT({dependencies:[],coupling:str,independent_areas:[]})', 'STORE-AS(var CODE_DEPENDENCIES)') + Task(mcp__brain__agent(explore), 'TASK → [(TEST ANALYSIS for: $PARENT_TASK.title + Thoroughness: medium + ANALYZE: existing tests, test patterns, coverage gaps + IDENTIFY: what tests need updating/creating + EXTRACT: {existing_tests:[],patterns:[],gaps:[]} + FOCUS ON: test requirements for subtasks)] → END-TASK', 'OUTPUT({tests:N,coverage_gaps:[],test_requirements:[]})', 'STORE-AS(var CODE_TESTS)'))

 - NOTE: All 3 ExploreMaster agents run SIMULTANEOUSLY
</guideline>
<guideline id="phase4-parallel-additional">
GOAL(PARALLEL: Additional targeted research based on task type)
## Examples
 - 
BATCH 3 - Additional Research (LAUNCH IN PARALLEL):
(Task(mcp__brain__agent(explore), 'TASK → [(COMPLEXITY ASSESSMENT for: $PARENT_TASK.title + Thoroughness: quick + ANALYZE: cyclomatic complexity, lines of code, nesting depth + IDENTIFY: complex hotspots, refactoring candidates + EXTRACT: {complexity_score:N,hotspots:[],risk_areas:[]})] → END-TASK', 'OUTPUT({complexity:str,hotspots:[],risk_level:str})', 'STORE-AS(var COMPLEXITY_ANALYSIS)') + IF($TASK_TYPE.domain === "api" OR $TASK_TYPE.domain === "backend") → THEN → [Task(mcp__brain__agent(explore), 'TASK → [(API/ROUTE ANALYSIS for: $PARENT_TASK.title + Thoroughness: medium + ANALYZE: affected routes, controllers, middleware + IDENTIFY: API contract changes, breaking changes + EXTRACT: {routes:[],controllers:[],breaking_changes:[]})] → END-TASK', 'OUTPUT({routes:N,changes:[],breaking:bool})', 'STORE-AS(var API_ANALYSIS)')] → END-IF)

 - 
PARALLEL memory searches for specific aspects:
(mcp__vector-memory__search_memories('{query: "$PARENT_TASK.domain estimation accuracy", limit: 3, category: "learning"}') + mcp__vector-memory__search_memories('{query: "$PARENT_TASK.title similar implementation", limit: 3, category: "code-solution"}') + mcp__vector-memory__search_memories('{query: "$PARENT_TASK.domain common mistakes", limit: 3, category: "bug-fix"}'))
</guideline>
<guideline id="phase5-synthesis">
GOAL(Synthesize ALL research into decomposition plan)
## Examples
 - 
COMBINE all stored research:
(STORE-GET(var PARENT_TASK) + STORE-GET(var EXISTING_SUBTASKS) + STORE-GET(var TASK_TYPE) + STORE-GET(var MEMORY_INSIGHTS) + STORE-GET(var DOC_INSIGHTS) + STORE-GET(var CODE_COMPONENTS) + STORE-GET(var CODE_DEPENDENCIES) + STORE-GET(var CODE_TESTS) + STORE-GET(var COMPLEXITY_ANALYSIS) + STORE-GET(var API_ANALYSIS))

 - 
SEQUENTIAL THINKING for decomposition strategy:
(mcp__sequential-thinking__sequentialthinking('{'."\\n"
    .'                    thought: "Analyzing comprehensive research from 5+ parallel agents for optimal decomposition. Parent: $PARENT_TASK.title. Golden rule: <=5-8h per subtask.",'."\\n"
    .'                    thoughtNumber: 1,'."\\n"
    .'                    totalThoughts: 6,'."\\n"
    .'                    nextThoughtNeeded: true'."\\n"
    .'                }'))

 - 
DECOMPOSITION ANALYSIS:
(Step 1: Identify natural task boundaries from CODE_COMPONENTS + Step 2: Map dependencies between potential subtasks from CODE_DEPENDENCIES + Step 3: Group related changes (files that change together) + Step 4: Estimate effort per group (MUST be <=5-8h) + Step 5: Determine optimal execution order + Step 6: Flag any subtask >8h for recursive decomposition + Step 7: COUNT subtasks - if >10, GROUP into larger chunks (5-8h each) with [needs-decomposition] tag)

 - STORE-AS(var DECOMPOSITION_PLAN = '[{title, scope, files, estimate, dependencies, order}]')
</guideline>
<guideline id="phase6-specification">
GOAL(Create detailed subtask specifications)
## Examples
 - 
For EACH subtask in DECOMPOSITION_PLAN:
(FOREACH(subtask in $DECOMPOSITION_PLAN) → [title: Concise, action-oriented (max 6 words) → content: Scope, requirements, acceptance criteria, affected files → estimate: hours (MUST be <=5-8h) → priority: inherit from parent or adjust → tags: inherit parent + subtask-specific + [decomposed] → IF(estimate > 8) → THEN → [Add tag [needs-decomposition], FLAG for recursive] → END-IF] → END-FOREACH)

 - 
DECOMPOSITION STRATEGIES to apply:
(LAYERED: Split by layer (API → service → repository → tests) + FEATURE: Split by feature (auth → validation → core → UI) + PHASE: Split by phase (research → implement → test → document) + DEPENDENCY: Independent first, dependent after + RISK: High-risk isolated for focused testing)

 - STORE-AS(var SUBTASK_SPECS = '[{title, content, estimate, priority, tags, needs_decomposition}]')
</guideline>
<guideline id="phase7-approval">
GOAL(Present subtasks for user approval (MANDATORY GATE))
## Examples
 - 
DISPLAY decomposition summary:
(═══ DECOMPOSITION SUMMARY ═══ + Parent Task: $PARENT_TASK.title (ID: $TASK_ID) + Parent Estimate: $PARENT_TASK.estimate + Existing Subtasks: {count} + ═══════════════════════════════)

 - 
FORMAT subtask list as table:
(# | Subtask Title | Estimate | Priority | Dependencies | Files | Flags + --|--------------|----------|----------|--------------|-------|------ + 1 | Setup base structure | 4h | high | - | 3 | - + 2 | Implement core logic | 6h | high | #1 | 5 | - + 3 | Add validation | 8h | medium | #2 | 4 | [!] NEEDS DECOMPOSE + ... (all subtasks))

 - 
RESEARCH SUMMARY:
(Agents used: {count} (VectorMaster, DocMaster, 3x ExploreMaster) + Memory insights: {count} patterns found + Components analyzed: {files} files, {classes} classes + Dependencies mapped: {count} relationships + Total estimate: {sum}h (parent was: {parent_estimate}h))

 - 
PROMPT:
(Ask: "Create {count} subtasks? (yes/no/modify)" + VALIDATE(User response is YES, APPROVE, CONFIRM) → FAILS → [Wait for explicit approval] → END-VALIDATE)
</guideline>
<guideline id="phase8-create">
GOAL(Create subtasks in vector task system after approval)
## Examples
 - 
CREATE subtasks via bulk:
(mcp__vector-task__task_create_bulk('{tasks: $SUBTASK_SPECS.map(s => ({'."\\n"
    .'                    title: s.title,'."\\n"
    .'                    content: s.content,'."\\n"
    .'                    parent_id: $TASK_ID,'."\\n"
    .'                    priority: s.priority,'."\\n"
    .'                    tags: s.tags'."\\n"
    .'                }))}') + STORE-AS(var CREATED_SUBTASKS = '[{id, title, estimate}]'))

 - 
VERIFY creation:
(mcp__vector-task__task_list('{parent_id: $TASK_ID}') + Confirm: {count} subtasks created)
</guideline>
<guideline id="phase9-complete">
GOAL(Report completion, store insight, STOP)
## Examples
 - 
STORE decomposition insight:
(mcp__vector-memory__store_memory('{'."\\n"
    .'                    content: "DECOMPOSED|$PARENT_TASK.title|subtasks:{count}|strategy:{approach}|estimates:{breakdown}|components:{from CODE_COMPONENTS}",'."\\n"
    .'                    category: "tool-usage",'."\\n"
    .'                    tags: ["task-decomposition", "$TASK_TYPE.domain", "workflow-pattern"]'."\\n"
    .'                }'))

 - 
REPORT:
(═══ DECOMPOSITION COMPLETE ═══ + Created: {count} subtasks for task #{$TASK_ID} + Total estimate: {sum}h + Agents used: {agent_count} (parallel execution) + ═══════════════════════════════)

 - 
RECURSIVE DECOMPOSITION (if any):
(IF(any subtask.needs_decomposition) → THEN → [[!] SUBTASKS NEED FURTHER DECOMPOSITION: → FOREACH(subtask in $CREATED_SUBTASKS where needs_decomposition) → [  - /task:decompose {subtask.id} (estimate: {subtask.estimate}h)] → END-FOREACH] → END-IF)

 - 
NEXT STEPS:
(  1. /task:decompose {id} - for subtasks >8h +   2. /task:list --parent=$TASK_ID - view hierarchy +   3. /task:next - start first subtask)

 - STOP: Do NOT execute any subtask. Return control to user.
</guideline>
<guideline id="subtask-format">
Required subtask structure
## Examples
 - Max 6 words, action-oriented
 - Scope, requirements, acceptance criteria, files
 - MUST be <=5-8h (GOLDEN RULE)
 - Inherit or adjust: critical|high|medium|low
 - Inherit parent + subtask-specific + [decomposed]
</guideline>
<guideline id="estimation-guide">
Subtask estimation (GOLDEN RULE: <=5-8h)
## Examples
 - 1-2h: Config, single file, simple edit
 - 2-4h: Small feature, multi-file, simple tests
 - 4-6h: Moderate feature, refactoring
 - 6-8h: Complex feature, architectural piece
 - >8h: VIOLATION - decompose further!
</guideline>
<guideline id="grouping-strategy">
When initial decomposition yields >10 subtasks, GROUP into larger chunks
## Examples
 - 
TRIGGER: count($DECOMPOSITION_PLAN) > 10
(Step 1: Identify logical clusters (by feature, layer, or dependency chain) + Step 2: Merge related subtasks into parent chunks (5-8h each) + Step 3: Each chunk gets [needs-decomposition] tag + Step 4: Final count MUST be ≤10 subtasks + Step 5: Recommend /task:decompose for each chunk after creation)

 - 
EXAMPLE:
(15 subtasks → group into 6-8 chunks: +   - "API Layer" (auth + validation + routes) → 7h [needs-decomposition] +   - "Service Layer" (logic + handlers) → 8h [needs-decomposition] +   - "Data Layer" (models + migrations + seeders) → 6h [needs-decomposition] +   - "Testing" (unit + integration) → 7h [needs-decomposition])
</guideline>
<guideline id="parallel-pattern">
Parallel agent execution pattern
## Examples
 - WRONG: Sequential agent calls → slow, incomplete
 - RIGHT: Multiple Task() calls in single response
 - All agents run SIMULTANEOUSLY
 - Synthesize ALL results before decomposition
</guideline>
<guideline id="directive">
PARALLEL agents! DEEP research! 5-8h GOLDEN RULE! MAX 10 subtasks! User approval! STOP after create!
</guideline>
</guidelines>
</command>