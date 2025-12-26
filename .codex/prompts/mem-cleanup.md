---
name: mem:cleanup
description: Cleanup old memories or delete by ID
---


<command>
<meta>
<id>mem:cleanup</id>
<description>Cleanup old memories or delete by ID</description>
</meta>
<purpose>Memory cleanup utility. Supports: bulk cleanup (days=N, max_to_keep=N), single delete (id=N), multi delete (ids=N,N,N). All operations require explicit confirmation.</purpose>
<purpose>Memory cleanup utility for bulk deletion by age/count or specific ID deletion. Requires confirmation for destructive operations.</purpose>
<guidelines>
<guideline id="role">
Memory cleanup utility that handles bulk deletion by age/count or specific ID deletion. All destructive operations require explicit confirmation.
</guideline>
<guideline id="workflow-step1">
STEP 1 - Parse $ARGUMENTS for Operation Type
## Examples
 - **format-1**: /mem:cleanup → preview default cleanup (30 days, keep 1000)
 - **format-2**: /mem:cleanup days=60 → cleanup older than 60 days
 - **format-3**: /mem:cleanup max_to_keep=500 → keep only 500 most recent
 - **format-4**: /mem:cleanup id=15 → delete specific memory
 - **format-5**: /mem:cleanup ids=15,16,17 → delete multiple specific
 - **detect**: STORE-AS(var MODE = 'bulk|single|multi')
</guideline>
<guideline id="workflow-step2">
STEP 2 - Handle Single ID Delete
## Examples
 - **check**: IF(STORE-GET(var MODE) === "single") → THEN → [Extract ID from $ARGUMENTS → mcp__vector-memory__get_by_memory_id('{memory_id: {id}}') → STORE-AS(var TARGET = 'memory to delete') → Display: "--- Memory to Delete ---" → Display: "ID: {id}" → Display: "Category: {category}" → Display: "Content: {content_preview}" → Display: "Tags: {tags}" → Display: "" → Prompt: "DELETE this memory? This cannot be undone. (yes/no)"] → END-IF
</guideline>
<guideline id="workflow-step3">
STEP 3 - Handle Multiple IDs Delete
## Examples
 - **check**: IF(STORE-GET(var MODE) === "multi") → THEN → [Extract IDs array from $ARGUMENTS → ForEach ID: fetch memory preview → Display: "--- Memories to Delete ({count}) ---" → ForEach: "#{id} [{category}] {preview}" → Display: "" → Prompt: "DELETE all {count} memories? This cannot be undone. (yes/no)"] → END-IF
</guideline>
<guideline id="workflow-step4">
STEP 4 - Bulk Cleanup Preview
## Examples
 - **check**: IF(STORE-GET(var MODE) === "bulk") → THEN → [Parse: days_old (default 30), max_to_keep (default 1000) → mcp__vector-memory__get_memory_stats('{}') → Calculate: how many would be deleted → Display: "--- Cleanup Preview ---" → Display: "Current total: {total} memories" → Display: "Settings: days_old={days}, max_to_keep={max}" → Display: "Would delete: ~{estimate} memories" → Display: "Would keep: ~{remaining} memories" → Display: "" → Prompt: "Proceed with cleanup? (yes/no)"] → END-IF
</guideline>
<guideline id="workflow-step5">
STEP 5 - Execute After Confirmation
## Examples
 - **validate**: VALIDATE(User response is YES, DELETE, or CONFIRM) → FAILS → [Abort: "Cleanup cancelled."] → END-VALIDATE
 - **execute-single**: IF(STORE-GET(var MODE) === "single") → THEN → [mcp__vector-memory__delete_by_memory_id('{memory_id: {id}}') → Display: "Memory #{id} deleted successfully."] → END-IF
 - **execute-multi**: IF(STORE-GET(var MODE) === "multi") → THEN → [ForEach ID: mcp__vector-memory__delete_by_memory_id('{memory_id: {id}}') → Display: "Deleted {count} memories successfully."] → END-IF
 - **execute-bulk**: IF(STORE-GET(var MODE) === "bulk") → THEN → [mcp__vector-memory__clear_old_memories('{days_old: {days}, max_to_keep: {max}}') → Display: "Cleanup completed. Removed {count} old memories."] → END-IF
</guideline>
<guideline id="output-format">
Cleanup display format
## Examples
 - --- Cleanup Preview ---
 - --- Memory to Delete ---
 - Current total: 37 memories
 - Would delete: ~12 memories
 - DELETE this memory? This cannot be undone. (yes/no)
 - Proceed with cleanup? (yes/no)
 - Cleanup cancelled.
 - Memory #15 deleted successfully.
 - Cleanup completed. Removed 12 old memories.
</guideline>
<guideline id="usage-examples">
Command usage patterns
## Examples
 - /mem:cleanup → preview default cleanup
 - /mem:cleanup days=60 → older than 60 days
 - /mem:cleanup max_to_keep=500 → limit to 500
 - /mem:cleanup id=15 → delete specific memory
 - /mem:cleanup ids=15,16,17 → delete multiple
</guideline>
</guidelines>
<iron_rules>
<rule id="mandatory-confirmation" severity="critical">
<text>ALL delete operations MUST require explicit user confirmation</text>
<why>Deletion is permanent and cannot be undone</why>
<on_violation>Show preview, ask for YES/DELETE confirmation, never auto-delete</on_violation>
</rule>
<rule id="show-preview" severity="high">
<text>MUST show what will be deleted before confirmation</text>
<why>User must understand impact before confirming</why>
<on_violation>Display count, preview content, then ask confirmation</on_violation>
</rule>
</iron_rules>
</command>