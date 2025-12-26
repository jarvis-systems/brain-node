---
name: init-task
description: Initialize project tasks from documentation and codebase analysis
---


<command>
<meta>
<id>init-task</id>
<description>Initialize project tasks from documentation and codebase analysis</description>
</meta>
<purpose>Initializes project task hierarchy by scanning documentation (.docs/, README), analyzing codebase structure via Explore agent, decomposing work into root-level tasks with estimates, and creating tasks in vector storage after user approval. Ensures comprehensive project understanding before task creation.</purpose>
<purpose>Aggressive project task initializer with MAXIMUM parallel agent orchestration. Scans every project corner via specialized agents, creates comprehensive epic-level tasks. NEVER executes - only creates.</purpose>
<iron_rules>
<rule id="parallel-agent-execution" severity="critical">
<text>Launch INDEPENDENT research agents in PARALLEL (multiple Task calls in single response)</text>
<why>Maximizes coverage, reduces total research time, comprehensive analysis</why>
<on_violation>Group independent areas, launch ALL simultaneously</on_violation>
</rule>
<rule id="every-corner-coverage" severity="critical">
<text>MUST explore EVERY project area: code, tests, config, docs, build, migrations, routes, schemas</text>
<why>First layer tasks define entire project. Missing areas = missing epics = incomplete planning</why>
<on_violation>Add missing areas to parallel exploration batch</on_violation>
</rule>
<rule id="multi-agent-research" severity="critical">
<text>Use SPECIALIZED agents for each domain: ExploreMaster(code), DocumentationMaster(docs), VectorMaster(memory), WebResearchMaster(external)</text>
<why>Each agent has domain expertise. Single agent cannot comprehensively analyze all areas.</why>
<on_violation>Delegate to appropriate specialized agent</on_violation>
</rule>
<rule id="create-only-no-execution" severity="critical">
<text>This command ONLY creates root tasks. NEVER execute any task after creation.</text>
<why>Init-task creates strategic foundation. Execution via /task:next or /do</why>
<on_violation>STOP immediately after task creation</on_violation>
</rule>
<rule id="mandatory-user-approval" severity="critical">
<text>MUST get explicit user YES/APPROVE/CONFIRM before creating ANY tasks</text>
<why>User must validate task breakdown before committing</why>
<on_violation>Present task list and wait for explicit confirmation</on_violation>
</rule>
<rule id="estimate-required" severity="critical">
<text>MUST provide time estimate (8-40h) for EACH epic</text>
<why>Estimates enable planning and identify tasks needing decomposition</why>
<on_violation>Add estimate before presenting epic</on_violation>
</rule>
<rule id="exclude-brain-directory" severity="critical">
<text>NEVER analyze .brain/ - Brain system internals, not project code</text>
<why>Brain config pollutes task list with irrelevant system tasks</why>
<on_violation>Skip .brain/ in all exploration phases</on_violation>
</rule>
</iron_rules>
<guidelines>
<guideline id="phase0-preflight">
GOAL(Check existing state, determine mode)
## Examples
 - 
STEP 1 - Check task state:
(mcp__vector-task__task_stats('{}') + STORE-AS(var TASK_STATE = '{total, pending, in_progress}'))

 - 
STEP 2 - Decision:
(IF($TASK_STATE.total === 0) → THEN → [Fresh init → proceed] → END-IF + IF($TASK_STATE.total > 0) → THEN → [Ask: "Tasks exist. (1) Add more, (2) Clear & restart, (3) Abort"] → END-IF)
</guideline>
<guideline id="phase1-structure">
GOAL(Quick structure scan to identify ALL areas for parallel exploration)
## Examples
 - Task(mcp__brain__agent(explore), 'TASK → [(QUICK STRUCTURE SCAN - identify directories only + Glob("*") → list root directories and key files + EXCLUDE: .brain/, vendor/, node_modules/, .git/ + IDENTIFY: code(src/app), tests, config, docs(.docs), migrations, routes, build, public + Output JSON: {areas: [{path, type, estimated_files, priority}]})] → END-TASK', 'OUTPUT({areas: [{path, type, estimated_files, priority: critical|high|medium|low}]})', 'STORE-AS(var PROJECT_AREAS)')
</guideline>
<guideline id="phase2-parallel-code">
GOAL(PARALLEL: Launch code exploration agents simultaneously)
## Examples
 - 
BATCH 1 - Core Code Areas (LAUNCH IN PARALLEL):
(Task(mcp__brain__agent(explore), 'TASK → [(Area: src/ or app/ (MAIN CODE) + Thoroughness: very thorough + ANALYZE: directory structure, namespaces, classes, design patterns + IDENTIFY: entry points, core modules, service layers, models + EXTRACT: {path|files_count|classes|namespaces|patterns|complexity} + FOCUS ON: what needs to be built/refactored/improved)] → END-TASK', 'OUTPUT({path:"src",files:N,modules:[],patterns:[],tech_debt:[]})', 'STORE-AS(var CODE_ANALYSIS)') + Task(mcp__brain__agent(explore), 'TASK → [(Area: tests/ (TEST COVERAGE) + Thoroughness: medium + ANALYZE: test structure, frameworks, coverage areas + IDENTIFY: tested modules, missing coverage, test patterns + EXTRACT: {path|test_files|framework|covered_modules|gaps})] → END-TASK', 'OUTPUT({path:"tests",files:N,framework:str,coverage_gaps:[]})', 'STORE-AS(var TEST_ANALYSIS)') + Task(mcp__brain__agent(explore), 'TASK → [(Area: database/ + migrations/ (DATA LAYER) + Thoroughness: thorough + ANALYZE: migrations, seeders, factories, schema + IDENTIFY: tables, relationships, indexes, pending migrations + EXTRACT: {migrations_count|tables|relationships|pending_changes})] → END-TASK', 'OUTPUT({migrations:N,tables:[],relationships:[],pending:[]})', 'STORE-AS(var DATABASE_ANALYSIS)'))

 - NOTE: All 3 ExploreMaster agents run SIMULTANEOUSLY
</guideline>
<guideline id="phase3-parallel-config">
GOAL(PARALLEL: Config, routes, and infrastructure analysis)
## Examples
 - 
BATCH 2 - Config & Infrastructure (LAUNCH IN PARALLEL):
(Task(mcp__brain__agent(explore), 'TASK → [(Area: config/ (CONFIGURATION) + Thoroughness: quick + ANALYZE: config files, env vars, service bindings + IDENTIFY: services configured, missing configs, security settings + EXTRACT: {configs:[names],services:[],env_vars_needed:[]})] → END-TASK', 'OUTPUT({configs:[],services:[],security_gaps:[]})', 'STORE-AS(var CONFIG_ANALYSIS)') + Task(mcp__brain__agent(explore), 'TASK → [(Area: routes/ (API SURFACE) + Thoroughness: thorough + ANALYZE: route definitions, middleware, controllers + IDENTIFY: endpoints, auth requirements, API versioning + EXTRACT: {routes_count|endpoints:[method,path,controller]|middleware:[]})] → END-TASK', 'OUTPUT({routes:N,api_endpoints:[],web_routes:[],middleware:[]})', 'STORE-AS(var ROUTES_ANALYSIS)') + Task(mcp__brain__agent(explore), 'TASK → [(Area: build/CI (.github/, docker*, Makefile) + Thoroughness: quick + ANALYZE: CI/CD pipelines, Docker setup, build scripts + IDENTIFY: deployment process, missing CI steps, containerization + EXTRACT: {ci:bool,docker:bool,pipelines:[],missing:[]})] → END-TASK', 'OUTPUT({ci:bool,docker:bool,deployment_ready:bool,gaps:[]})', 'STORE-AS(var BUILD_ANALYSIS)'))

 - NOTE: All 3 agents run SIMULTANEOUSLY with Batch 1
</guideline>
<guideline id="phase4-documentation">
GOAL(Index docs via brain docs, then PARALLEL DocumentationMaster analysis)
## Examples
 - 
STEP 1 - Get documentation index:
(Bash('brain docs') + STORE-AS(var DOCS_INDEX = '[{path, name, description, type}]'))

 - 
STEP 2 - Adaptive batching based on doc count:
(IF(docs_count <= 3) → THEN → [Single DocumentationMaster for all] → END-IF + IF(docs_count 4-8) → THEN → [2 DocumentationMaster agents in parallel] → END-IF + IF(docs_count > 8) → THEN → [3+ DocumentationMaster agents in parallel] → END-IF)

 - 
STEP 3 - PARALLEL DocumentationMaster agents:
(Task(mcp__brain__agent(documentation-master), 'TASK → [(Docs batch: [README*, CONTRIBUTING*, ARCHITECTURE*] + Read each doc via Read tool + EXTRACT: {name|purpose|requirements|constraints|decisions} + FOCUS ON: project goals, user requirements, acceptance criteria)] → END-TASK', 'OUTPUT({docs_analyzed:N,requirements:[],constraints:[]})', 'STORE-AS(var DOCS_REQUIREMENTS)') + Task(mcp__brain__agent(documentation-master), 'TASK → [(Docs batch: [API docs, technical specs, .docs/*.md] + Read each doc via Read tool + EXTRACT: {name|endpoints|integrations|dependencies} + FOCUS ON: technical requirements, API contracts, integrations)] → END-TASK', 'OUTPUT({docs_analyzed:N,api_specs:[],integrations:[]})', 'STORE-AS(var DOCS_TECHNICAL)'))

 - 
STEP 4 - README.md direct read for project overview:
(Read('README.md') + STORE-AS(var README_CONTENT = 'project overview, features, setup'))
</guideline>
<guideline id="phase5-vector-research">
GOAL(VectorMaster for comprehensive prior knowledge extraction)
## Examples
 - Task(mcp__brain__agent(vector-master), 'TASK → [(DEEP MEMORY RESEARCH for project planning + Multi-probe search strategy: + Probe 1: "project architecture implementation patterns" (architecture) + Probe 2: "project requirements features roadmap" (learning) + Probe 3: "bugs issues problems technical debt" (bug-fix) + Probe 4: "decisions trade-offs alternatives" (code-solution) + Probe 5: "project context conventions standards" (project-context) + EXTRACT: past decisions, known issues, lessons learned, patterns + OUTPUT: actionable insights for task planning)] → END-TASK', 'OUTPUT({memories_found:N,insights:[],warnings:[],recommendations:[]})', 'STORE-AS(var PRIOR_KNOWLEDGE)')
 - 
PARALLEL: Direct memory searches for specific categories:
(mcp__vector-memory__search_memories('{query: "project goals objectives success criteria", limit: 5, category: "learning"}') + mcp__vector-memory__search_memories('{query: "technical debt refactoring needed", limit: 5, category: "architecture"}') + mcp__vector-memory__search_memories('{query: "blocked issues dependencies", limit: 5, category: "debugging"}'))
</guideline>
<guideline id="phase6-external">
GOAL(WebResearchMaster for external dependencies and APIs)
## Examples
 - 
CONDITIONAL: If project uses external services/APIs:
(IF(external services detected in config/routes analysis) → THEN → [Task(mcp__brain__agent(web-research-master), 'TASK → [(Research external dependencies: {detected_services} + Find: API documentation, rate limits, best practices + Find: known issues, integration patterns, gotchas + OUTPUT: integration requirements, constraints, risks)] → END-TASK', 'OUTPUT({services_researched:N,requirements:[],risks:[]})', 'STORE-AS(var EXTERNAL_CONTEXT)')] → ELSE → [SKIP(No external dependencies detected)] → END-IF)
</guideline>
<guideline id="phase7-synthesis">
GOAL(Synthesize ALL research into comprehensive project context)
## Examples
 - 
COMBINE all stored research:
(STORE-GET(var CODE_ANALYSIS) + STORE-GET(var TEST_ANALYSIS) + STORE-GET(var DATABASE_ANALYSIS) + STORE-GET(var CONFIG_ANALYSIS) + STORE-GET(var ROUTES_ANALYSIS) + STORE-GET(var BUILD_ANALYSIS) + STORE-GET(var DOCS_REQUIREMENTS) + STORE-GET(var DOCS_TECHNICAL) + STORE-GET(var README_CONTENT) + STORE-GET(var PRIOR_KNOWLEDGE) + STORE-GET(var EXTERNAL_CONTEXT))

 - 
SEQUENTIAL THINKING for strategic decomposition:
(mcp__sequential-thinking__sequentialthinking('{'."\\n"
    .'                    thought: "Analyzing comprehensive research from 8+ parallel agents. Synthesizing into strategic epics.",'."\\n"
    .'                    thoughtNumber: 1,'."\\n"
    .'                    totalThoughts: 8,'."\\n"
    .'                    nextThoughtNeeded: true'."\\n"
    .'                }'))

 - 
SYNTHESIS STEPS:
(Step 1: Extract project scope, primary objectives, success criteria + Step 2: Map functional requirements from docs + code analysis + Step 3: Map non-functional requirements (performance, security, scalability) + Step 4: Identify current state: greenfield / existing / refactor + Step 5: Calculate completion percentage per area + Step 6: Identify major work streams (future epics) + Step 7: Map dependencies between work streams + Step 8: Prioritize: blockers first, then core, then features)

 - STORE-AS(var PROJECT_SYNTHESIS = 'comprehensive project understanding')
</guideline>
<guideline id="phase8-epic-generation">
GOAL(Generate 5-15 strategic epics from synthesis)
## Examples
 - 
EPIC GENERATION RULES:
(Target: 5-15 root epics (not too few, not too many) + Each epic: major work stream, 8-40 hours estimate + Epic boundaries: clear scope, deliverables, acceptance criteria + Dependencies: identify inter-epic dependencies + Tags: [epic, {domain}, {stack}, {phase}])

 - 
EPIC CATEGORIES to consider:
(FOUNDATION: setup, infrastructure, CI/CD, database schema + CORE: main features, business logic, models, services + API: endpoints, authentication, authorization, contracts + FRONTEND: UI components, views, assets, interactions + TESTING: unit tests, integration tests, E2E, coverage + SECURITY: auth, validation, encryption, audit + PERFORMANCE: optimization, caching, scaling, monitoring + DOCUMENTATION: API docs, guides, deployment docs + TECH_DEBT: refactoring, upgrades, cleanup, migrations)

 - STORE-AS(var EPIC_LIST = '[{title, content, priority, estimate, tags, dependencies}]')
</guideline>
<guideline id="phase9-approval">
GOAL(Present epics for user approval (MANDATORY GATE))
## Examples
 - 
FORMAT epic list as table:
(# | Epic Title | Priority | Estimate | Dependencies | Tags + ---|------------|----------|----------|--------------|----- + 1 | Foundation Setup | critical | 16h | - | [epic,infra,setup] + 2 | Core Models | high | 24h | #1 | [epic,backend,models] + ... (all epics))

 - 
SUMMARY:
(Total epics: {count} + Total estimated hours: {sum} + Critical path: {epics with dependencies} + Research agents used: {count} (Explore, Doc, Vector, Web) + Areas analyzed: code, tests, database, config, routes, build, docs, memory)

 - 
PROMPT:
(Ask: "Approve epic creation? (yes/no/modify)" + VALIDATE(User response is YES, APPROVE, or CONFIRM) → FAILS → [Wait for explicit approval] → END-VALIDATE)
</guideline>
<guideline id="phase10-create">
GOAL(Create epics in vector task system after approval)
## Examples
 - 
CREATE epics:
(mcp__vector-task__task_create_bulk('{tasks: STORE-GET(var EPIC_LIST)}') + STORE-AS(var CREATED_EPICS = '[task_ids]'))

 - 
VERIFY creation:
(mcp__vector-task__task_stats('{}') + Confirm: {count} epics created)
</guideline>
<guideline id="phase11-complete">
GOAL(Report completion, store insight, STOP)
## Examples
 - 
STORE initialization insight:
(mcp__vector-memory__store_memory('{'."\\n"
    .'                    content: "PROJECT_INIT|epics:{count}|hours:{total}|areas:{list}|stack:{tech}|critical_path:{deps}",'."\\n"
    .'                    category: "architecture",'."\\n"
    .'                    tags: ["project-init", "epics", "planning", "init-task"]'."\\n"
    .'                }'))

 - 
REPORT:
(═══ INIT-TASK COMPLETE ═══ + Epics created: {count} + Total estimate: {hours}h + Agents used: {agent_count} (parallel execution) + Areas covered: code, tests, db, config, routes, build, docs, memory, external + ═══════════════════════════ +  + NEXT STEPS: +   1. /task:decompose {epic_id} - Break down each epic +   2. /task:list - View all tasks +   3. /task:next - Start first task)

 - STOP: Do NOT execute any task. Return control to user.
</guideline>
<guideline id="epic-format">
Required epic structure
## Examples
 - title: Concise name (max 10 words)
 - content: Scope, objectives, deliverables, acceptance criteria
 - priority: critical | high | medium | low
 - estimate: 8-40 hours (will be decomposed)
 - tags: [epic, {domain}, {stack}, {phase}]
</guideline>
<guideline id="estimation-guide">
Epic estimation guidelines
## Examples
 - 8-16h: Focused, single domain
 - 16-24h: Cross-component, moderate
 - 24-32h: Architectural, integrations
 - 32-40h: Foundational, high complexity
 - >40h: Split into multiple epics
</guideline>
<guideline id="parallel-pattern">
How to execute agents in parallel
## Examples
 - WRONG: forEach(areas) → sequential, slow, incomplete
 - RIGHT: List multiple Task() calls in single response
 - Brain executes all Task() calls simultaneously
 - Each agent stores findings, then synthesize all
</guideline>
<guideline id="directive">
PARALLEL agents! EVERY corner! MAXIMUM coverage! Dense synthesis! User approval!
</guideline>
</guidelines>
</command>