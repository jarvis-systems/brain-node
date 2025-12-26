---
name: task:create
description: Create task from description with analysis and estimation
---


<command>
<meta>
<id>task:create</id>
<description>Create task from description with analysis and estimation</description>
</meta>
<purpose>Creates task(s) from user description provided via $ARGUMENTS. Analyzes relevant materials, searches vector memory for similar past work, estimates time, gets mandatory user approval, creates task(s), and recommends decomposition if estimate >5-8 hours. Golden rule: each task 5-8 hours max.</purpose>
<purpose>Task creation specialist that analyzes user descriptions, researches context, estimates effort, and creates well-structured tasks after user approval.</purpose>
<guidelines>
<guideline id="role">
Task creation specialist that analyzes user descriptions, researches context, estimates effort, and creates well-structured tasks after user approval.
</guideline>
<guideline id="workflow-step0">
STEP 0 - Parse an input task and Understand
## Examples
 - **parse**: TASK → [$ARGUMENTS] → END-TASK
 - **action-1**: Extract: primary objective, scope, requirements from user description
 - **action-2**: Identify: implicit constraints, technical domain, affected areas
 - **action-3**: Determine: task type (feature, bugfix, refactor, research, docs)
 - **output**: STORE-AS(var TASK_SCOPE = 'parsed objective, domain, requirements, type') → STORE-AS(var TASK_TEXT = 'full original user description from phase parse')
</guideline>
<guideline id="workflow-step1">
STEP 1 - Search Existing Tasks for Duplicates/Related Work (MANDATORY)
## Examples
 - **delegate**: Task(mcp__brain__agent(vector-master) 'Search existing tasks for potential duplicates or related work. Task objective: {STORE-GET(var TASK_SCOPE)}. Search by: 1) objective keywords, 2) domain terms, 3) pending tasks. Analyze: duplicates, potential parent tasks, dependencies (blocked-by, blocks). Return: structured report with task IDs, relationships, recommendation (create new / update existing / make subtask).')
 - **decision**: IF(duplicate task found in agent report) → THEN → [STOP. Inform user about existing task ID and ask: update existing or create new?] → ELSE → [Continue to next step] → END-IF
 - **output**: STORE-AS(var EXISTING_TASKS = 'agent report: related task IDs, potential parent, dependencies')
</guideline>
<guideline id="workflow-step2">
STEP 2 - Deep Search Vector Memory for Prior Knowledge (MANDATORY)
## Examples
 - **delegate**: Task(mcp__brain__agent(vector-master) 'Deep multi-probe search for prior knowledge related to task. Task context: {STORE-GET(var TASK_SCOPE)}. Search categories: code-solution, architecture, bug-fix, learning. Use decomposed queries: 1) domain + objective, 2) implementation patterns, 3) known bugs/errors, 4) lessons learned. Return: structured report with memory IDs, key insights, reusable patterns, approaches to avoid, past mistakes.')
 - **output**: STORE-AS(var PRIOR_WORK = 'agent report: memory IDs, insights, recommendations, warnings')
</guideline>
<guideline id="workflow-step3">
STEP 3 - Codebase Exploration (MANDATORY for code-related tasks)
## Examples
 - **decision**: IF(task is code-related (feature, bugfix, refactor)) → THEN → [TASK → [Task(mcp__brain__agent(explore) 'Comprehensive scan for {domain}. Find: existing implementations, related components, patterns used, dependencies, test coverage. Return: relevant files with paths, architecture notes, integration points') → Wait for Explore agent to complete] → END-TASK] → ELSE → [SKIP(Task is not code-related (research, docs))] → END-IF
 - **output**: STORE-AS(var CODEBASE_CONTEXT = 'relevant files, patterns, dependencies, integration points')
</guideline>
<guideline id="workflow-step4">
STEP 4 - Documentation Research (if relevant)
## Examples
 - **decision**: IF(task involves architecture, API, or external integrations) → THEN → [Task(mcp__brain__agent(documentation-master) 'Research documentation for task context. Domain: {STORE-GET(var TASK_SCOPE)}. Search: 1) project .docs/ via brain docs command, 2) relevant package docs if external deps. Return: structured report with doc paths, API specs, architectural decisions, relevant sections.')] → ELSE → [SKIP(Documentation scan not needed for this task type)] → END-IF
 - **output**: STORE-AS(var DOC_CONTEXT = 'agent report: documentation references, API specs, architectural decisions')
</guideline>
<guideline id="workflow-step5">
STEP 5 - Task Analysis via Sequential Thinking
## Examples
 - **thinking**: mcp__sequential-thinking__sequentialthinking('{'."\\n"
    .'                    thought: "Analyzing task scope, complexity, and requirements for: STORE-GET(var TASK_SCOPE)",'."\\n"
    .'                    thoughtNumber: 1,'."\\n"
    .'                    totalThoughts: 4,'."\\n"
    .'                    nextThoughtNeeded: true'."\\n"
    .'                }')
 - **analyze-1**: Assess complexity: simple (1-2h), moderate (2-4h), complex (4-6h), major (6-8h), decompose (>8h)
 - **analyze-2**: Identify: dependencies, blockers, prerequisites from STORE-GET(var EXISTING_TASKS) and STORE-GET(var CODEBASE_CONTEXT)
 - **analyze-3**: Determine: priority based on urgency and impact
 - **analyze-4**: Extract: acceptance criteria from requirements
 - **output**: STORE-AS(var ANALYSIS = 'complexity, estimate, priority, dependencies, criteria')
</guideline>
<guideline id="workflow-step6">
STEP 6 - Formulate Task Specification with Context Links
## Examples
 - **title**: Create concise title (max 10 words) capturing objective
 - **content**: Write detailed description with: objective, context, acceptance criteria, implementation hints
 - **priority**: Assign: critical | high | medium | low
 - **tags**: Add relevant tags: [category, domain, stack]
 - **estimate**: Set time estimate in hours
 - **comment**: Build initial comment with research context: → - Memory refs: list memory IDs from STORE-GET(var PRIOR_WORK) (format: "Related memories: #ID1, #ID2") → - File refs: list key file paths from STORE-GET(var CODEBASE_CONTEXT) (format: "Key files: path1, path2") → - Task refs: list related task IDs from STORE-GET(var EXISTING_TASKS) (format: "Related tasks: #ID1, #ID2") → - Doc refs: list doc paths from STORE-GET(var DOC_CONTEXT) if available
 - **output**: STORE-AS(var TASK_SPEC = '{title, content, priority, tags, estimate, comment}')
</guideline>
<guideline id="workflow-step7">
STEP 7 - Present Task for User Approval (MANDATORY GATE)
## Examples
 - **present-1**: Display task specification:
 - **present-2**:   Title: {title}
 - **present-3**:   Priority: {priority}
 - **present-4**:   Estimate: {estimate} hours
 - **present-5**:   Tags: {tags}
 - **present-6**:   Content: {content preview}
 - **present-7**:   Related Tasks: STORE-GET(var EXISTING_TASKS)
 - **present-8**:   Prior Work: Memory IDs from STORE-GET(var PRIOR_WORK)
 - **present-9**:   Codebase Context: STORE-GET(var CODEBASE_CONTEXT)
 - **warning**: IF(estimate > 8 hours) → THEN → [WARN: Estimate exceeds 8h. Strongly recommend running /task:decompose {task_id} after creation.] → END-IF
 - **prompt**: Ask: "Create this task? (yes/no/modify)"
 - **gate**: VALIDATE(User response is YES, APPROVE, CONFIRM, or Y) → FAILS → [Wait for explicit approval. Allow modifications if requested.] → END-VALIDATE
</guideline>
<guideline id="workflow-step8">
STEP 8 - Create Task After Approval (with context links in comment)
## Examples
 - **create**: mcp__vector-task__task_create('{'."\\n"
    .'                    title: "STORE-GET(var TASK_SPEC).title",'."\\n"
    .'                    content: "STORE-GET(var TASK_SPEC).content",'."\\n"
    .'                    priority: "STORE-GET(var TASK_SPEC).priority",'."\\n"
    .'                    tags: STORE-GET(var TASK_SPEC).tags,'."\\n"
    .'                    comment: "STORE-GET(var TASK_SPEC).comment"'."\\n"
    .'                }')
 - **capture**: STORE-AS(var CREATED_TASK_ID = 'task ID from response')
</guideline>
<guideline id="workflow-step9">
STEP 9 - Post-Creation Summary (END - NO EXECUTION)
## Examples
 - **confirm**: Report: Task created with ID: STORE-GET(var CREATED_TASK_ID)
 - **decompose-check**: IF(estimate > 8 hours) → THEN → [STRONGLY RECOMMEND: Run /task:decompose STORE-GET(var CREATED_TASK_ID) to break down this large task] → END-IF
 - **next-steps**: Suggest: /task:next to start working, /task:list to view all tasks
 - **stop**: STOP HERE. Do NOT execute the task. Return control to user.
</guideline>
<guideline id="workflow-step10">
STEP 10 - Store Task Creation Insight
## Examples
 - **store**: mcp__vector-memory__store_memory('{'."\\n"
    .'                    content: "Created task: {title}. Domain: {domain}. Approach: {key insights from analysis}. Estimate: {hours}h.",'."\\n"
    .'                    category: "tool-usage",'."\\n"
    .'                    tags: ["task-creation", "{domain}"]'."\\n"
    .'                }')
</guideline>
<guideline id="task-format">
Required task specification structure
## Examples
 - Concise, action-oriented (max 10 words)
 - Detailed with: objective, context, acceptance criteria, hints
 - critical | high | medium | low
 - [category, domain, stack-tags]
 - 1-8 hours (>8h needs decomposition)
</guideline>
<guideline id="estimation-rules">
Task estimation guidelines
## Examples
 - 1-2h: Config changes, simple edits, minor fixes
 - 2-4h: Small features, multi-file changes, tests
 - 4-6h: Moderate features, refactoring, integrations
 - 6-8h: Complex features, architectural changes
 - >8h: MUST recommend /task:decompose
</guideline>
<guideline id="priority-rules">
Priority assignment criteria
## Examples
 - Blockers, security issues, data integrity, production bugs
 - Key features, deadlines, dependencies for other work
 - Standard features, improvements, optimizations
 - Nice-to-have, cosmetic, documentation, cleanup
</guideline>
<guideline id="quality-gates">
ALL checkpoints MUST pass before task creation
## Examples
 - Step 0: STORE-GET(var TASK_TEXT) fully parsed - objective, domain, type extracted
 - Step 1: Existing tasks searched - duplicates checked, dependencies identified
 - Step 2: Vector memory searched - code-solution, architecture, bug-fix, learning categories
 - Step 3: Codebase explored (if code-related) - relevant files, patterns, dependencies found
 - Step 4: Documentation reviewed (if architecture/API) - specs, decisions documented
 - Step 5: Sequential thinking analysis completed - complexity, estimate, priority determined
 - Step 6: Task spec complete - title, content, priority, tags, estimate, comment with context links
 - Step 7: User approval explicitly received - YES/APPROVE/CONFIRM
 - Step 8: Task created with comment containing memory IDs, file paths, related task IDs
 - Step 9: STOP after creation - do NOT execute task
</guideline>
<guideline id="comment-format">
Initial task comment structure for context preservation
## Examples
 - Related memories: #42, #58, #73 (insights about {domain})
 - Key files: src/Services/Auth.php:45, app/Models/User.php
 - Related tasks: #12 (blocked-by), #15 (related)
 - Docs: .docs/architecture/auth-flow.md
 - Notes: {any critical insights from research}
</guideline>
</guidelines>
<iron_rules>
<rule id="analyze-arguments" severity="critical">
<text>MUST analyze an input task thoroughly before creating any task</text>
<why>User description requires deep understanding to create accurate task specification</why>
<on_violation>Parse and analyze an input task first, extract scope, requirements, and context</on_violation>
</rule>
<rule id="search-memory-first" severity="critical">
<text>MUST search vector memory for similar past work before analysis</text>
<why>Prevents duplicate work and leverages existing insights</why>
<on_violation>Execute mcp__vector-memory__search_memories('{query: "{task_domain}", limit: 5}')</on_violation>
</rule>
<rule id="estimate-required" severity="critical">
<text>MUST provide time estimate for the task</text>
<why>Estimates enable planning and identify tasks needing decomposition</why>
<on_violation>Add estimate in hours before presenting task</on_violation>
</rule>
<rule id="mandatory-user-approval" severity="critical">
<text>MUST get explicit user approval BEFORE creating any task</text>
<why>User must validate task specification before committing to vector storage</why>
<on_violation>Present task specification and wait for explicit YES/APPROVE/CONFIRM</on_violation>
</rule>
<rule id="max-task-estimate" severity="high">
<text>If estimate >5-8 hours, MUST strongly recommend /task:decompose</text>
<why>Large tasks should be decomposed for better manageability and tracking</why>
<on_violation>Warn user and recommend decomposition after task creation</on_violation>
</rule>
<rule id="create-only-no-execution" severity="critical">
<text>This command ONLY creates tasks. NEVER execute the task after creation, regardless of size or complexity.</text>
<why>Task creation and task execution are separate concerns. User decides when to execute via /task:next or /do commands.</why>
<on_violation>STOP immediately. Return created task ID and let user decide next action.</on_violation>
</rule>
<rule id="comment-with-context" severity="critical">
<text>MUST add initial comment with useful links: memory IDs from research, relevant file paths from codebase exploration, related task IDs.</text>
<why>Comments preserve critical context for future execution. Without links, executor loses valuable research done during creation.</why>
<on_violation>Add comment with: Memory refs (IDs from PRIOR_WORK), File refs (paths from CODEBASE_CONTEXT), Related tasks (from EXISTING_TASKS).</on_violation>
</rule>
<rule id="deep-research-mandatory" severity="critical">
<text>MUST perform comprehensive research BEFORE formulating task: existing tasks, vector memory, codebase (if code-related), documentation.</text>
<why>Quality task creation requires full context. Skipping research leads to duplicate tasks, missed dependencies, and poor estimates.</why>
<on_violation>STOP. Execute ALL research steps (existing tasks, memory, codebase exploration) before proceeding to analysis.</on_violation>
</rule>
<rule id="check-existing-tasks" severity="critical">
<text>MUST search existing tasks for duplicates or related work before creating new task.</text>
<why>Prevents duplicate tasks, identifies potential parent tasks, reveals blocked/blocking relationships.</why>
<on_violation>Execute mcp__vector-task__task_list('{query: "{objective}", limit: 10}') and analyze results.</on_violation>
</rule>
<rule id="mandatory-agent-delegation" severity="critical">
<text>ALL research steps (existing tasks, vector memory, codebase, documentation) MUST be delegated to specialized agents. NEVER execute research directly.</text>
<why>Direct execution consumes command context. Agents have dedicated context for deep research and return concise structured reports.</why>
<on_violation>STOP. Delegate to: vector-master (tasks/memory), explore (codebase), documentation-master (docs). Never use direct MCP/Glob/Grep calls for research.</on_violation>
</rule>
</iron_rules>
</command>