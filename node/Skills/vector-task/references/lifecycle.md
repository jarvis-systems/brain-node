---
name: "Vector Task Lifecycle"
description: "Operational lifecycle rules for vector task execution and validation"
---

# Lifecycle

Before execution:

1. Load the assigned task.
2. Load parent and children when present.
3. Check in-progress siblings and declared scopes.

During execution:

Track blockers in comments. Keep task updates scoped to the assigned task.

After execution:

Use `completed`, `tested`, or `validated` according to actual verification. Create fix tasks for failed gates instead of marking validation as passed.
