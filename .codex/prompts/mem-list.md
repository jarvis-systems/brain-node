---
name: mem:list
description: List recent memories chronologically
---


<command>
<meta>
<id>mem:list</id>
<description>List recent memories chronologically</description>
</meta>
<purpose>Lists recent memories in chronological order. Accepts optional limit parameter via $ARGUMENTS (default 10, max 50). Shows previews with category and tags.</purpose>
<purpose>Lists recent memories in chronological order with content previews and metadata.</purpose>
<guidelines>
<guideline id="role">
Simple memory listing utility that displays recent memories chronologically with previews and metadata.
</guideline>
<guideline id="workflow-step1">
STEP 1 - Parse $ARGUMENTS for Limit
## Examples
 - **format**: /mem:list OR /mem:list limit=20
 - **extract**: Extract: limit (optional, default 10, max 50)
 - **validate**: IF(limit > 50) → THEN → [Set limit = 50 (max allowed)] → END-IF
 - **output**: STORE-AS(var LIMIT = 'parsed limit value')
</guideline>
<guideline id="workflow-step2">
STEP 2 - Fetch Recent Memories
## Examples
 - **fetch**: mcp__vector-memory__list_recent_memories('{limit: STORE-GET(var LIMIT)}')
 - **store**: STORE-AS(var MEMORIES = 'recent memories array')
</guideline>
<guideline id="workflow-step3">
STEP 3 - Handle No Memories
## Examples
 - **check**: IF(STORE-GET(var MEMORIES) is empty) → THEN → [Display: "No memories stored yet." → Suggest: "Use /mem:store to add your first memory"] → END-IF
</guideline>
<guideline id="workflow-step4">
STEP 4 - Format and Display
## Examples
 - **header**: Display: "--- Recent Memories ({count}) ---"
 - **list**: FOREACH(memory in STORE-GET(var MEMORIES)) → [Display: "#{id} [{category}] {created_at}" → Display: "  {content_preview} (first 80 chars)..." → Display: "  Tags: {tags}"] → END-FOREACH
 - **footer**: Display: "Use /mem:get {id} to view full content"
</guideline>
<guideline id="output-format">
Display format for memory list
## Examples
 - --- Recent Memories (10) ---
 - #{id} [{category}] 2025-11-22
 -   Content preview here...
 -   Tags: php, laravel, auth
 - Use /mem:get {id} to view full content
</guideline>
<guideline id="usage-examples">
Command usage patterns
## Examples
 - /mem:list → last 10 memories
 - /mem:list limit=20 → last 20 memories
 - /mem:list limit=50 → maximum allowed
</guideline>
</guidelines>
</command>