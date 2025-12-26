---
name: mem:store
description: Store memory with analysis, category, and tags
---


<command>
<meta>
<id>mem:store</id>
<description>Store memory with analysis, category, and tags</description>
</meta>
<purpose>Stores new memory from $ARGUMENTS content. Analyzes content, checks for duplicates, suggests category/tags, and requires user approval before storing.</purpose>
<purpose>Memory storage specialist that analyzes content, detects duplicates, suggests category/tags, and stores after user approval.</purpose>
<guidelines>
<guideline id="role">
Memory storage specialist that analyzes content, checks for duplicates, suggests appropriate category and tags, and stores memory after user approval.
</guideline>
<guideline id="workflow-step1">
STEP 1 - Parse $ARGUMENTS
## Examples
 - **format-1**: Direct content: /mem:store "This is the memory content"
 - **format-2**: With params: /mem:store content="..." category=code-solution tags=php,laravel
 - **extract**: Extract: content (required), category (optional), tags (optional)
 - **output**: STORE-AS(var INPUT = '{content, category?, tags?}')
</guideline>
<guideline id="workflow-step2">
STEP 2 - Search for Similar Memories
## Examples
 - **summarize**: Create short summary (20-30 words) of content for search
 - **search**: mcp__vector-memory__search_memories('{query: "{summary}", limit: 5}')
 - **analyze**: IF(similar memories found with similarity > 0.8) → THEN → [WARN: Similar memory exists (ID: {id}, similarity: {score}) → Show: "{content_preview}" → Ask: "Continue storing? (yes/no/update existing)"] → ELSE → [STORE-AS(var DUPLICATES = 'none')] → END-IF
</guideline>
<guideline id="workflow-step3">
STEP 3 - Analyze Content and Suggest Category/Tags
## Examples
 - **detect-category**: IF(category not provided in $ARGUMENTS) → THEN → [Analyze content domain and type → Suggest category based on content analysis] → END-IF
 - **detect-tags**: IF(tags not provided in $ARGUMENTS) → THEN → [Extract key topics, technologies, concepts → Suggest 3-5 relevant tags] → END-IF
 - **output**: STORE-AS(var SUGGESTION = '{category, tags, reasoning}')
</guideline>
<guideline id="workflow-step4">
STEP 4 - Present Memory for User Approval (MANDATORY)
## Examples
 - **display-1**: --- Memory to Store ---
 - **display-2**: Content: {content_preview} ({char_count} chars)
 - **display-3**: Category: {category}
 - **display-4**: Tags: {tags}
 - **display-5**: IF(STORE-GET(var DUPLICATES) !== none) → THEN → [WARNING: Similar memories exist!] → END-IF
 - **prompt**: Store this memory? (yes/no/modify)
 - **gate**: VALIDATE(User response is YES, APPROVE, Y, or CONFIRM) → FAILS → [Wait for explicit approval. Allow modifications if requested.] → END-VALIDATE
</guideline>
<guideline id="workflow-step5">
STEP 5 - Store Memory After Approval
## Examples
 - **store**: mcp__vector-memory__store_memory('{'."\\n"
    .'                content: "STORE-GET(var INPUT).content",'."\\n"
    .'                category: "STORE-GET(var SUGGESTION).category",'."\\n"
    .'                tags: STORE-GET(var SUGGESTION).tags'."\\n"
    .'            }')
 - **confirm**: Display: "Memory stored successfully"
</guideline>
<guideline id="categories">
Available memory categories
## Examples
 - Implementations, patterns, working solutions
 - Resolved issues, root causes, fixes applied
 - Design decisions, system structure, trade-offs
 - Insights, discoveries, lessons learned
 - Workflows, tool patterns, configurations
 - Debug approaches, troubleshooting steps
 - Optimizations, benchmarks, metrics
 - Security patterns, vulnerabilities, fixes
 - Anything that does not fit other categories
</guideline>
<guideline id="tag-guidelines">
Tag naming conventions
## Examples
 - php, laravel, javascript, python, go
 - api, database, auth, cache, queue
 - react, vue, tailwind, livewire
 - docker, nginx, redis, mysql
 - testing, ci-cd, deployment, monitoring
</guideline>
</guidelines>
<iron_rules>
<rule id="analyze-content" severity="critical">
<text>MUST analyze $ARGUMENTS content before storing</text>
<why>Content analysis ensures proper categorization and prevents garbage storage</why>
<on_violation>Parse $ARGUMENTS, extract content, determine domain and type</on_violation>
</rule>
<rule id="check-duplicates" severity="high">
<text>MUST search for similar memories before storing</text>
<why>Prevents duplicate entries and wasted storage</why>
<on_violation>Execute mcp__vector-memory__search_memories('{query: "{content_summary}", limit: 3}')</on_violation>
</rule>
<rule id="mandatory-approval" severity="critical">
<text>MUST get user approval before storing memory</text>
<why>User must validate content, category, and tags before committing</why>
<on_violation>Present memory specification and wait for YES/APPROVE</on_violation>
</rule>
</iron_rules>
</command>