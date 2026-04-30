---
name: "Automation Flags"
description: "Shared CLI flag contract for unattended Brain command execution"
type: architecture
date: 2026-05-01
version: "1.0.0"
status: active
---

# Automation Flags

Automation flags make unattended command execution predictable without weakening task lifecycle or quality gates.

Supported aliases: `-y/--yes`, `-n/--dry-run`, `-j/--json`, `-k/--checkpoint`, `-o/--offline`, `-t/--timeout`, `-m/--max-agents`, `-s/--sequential`, `-F/--fail-fast`, `-R/--resume`, `--restart`, `-S/--full-suite`, and `-a/--audit-only`.

Context reuse has separate task lifecycle flags: `-c/--cold` and `-r/--reuse-context`.

Flags are constraints, not bypasses. They must not skip source-of-truth MCP reads, status checks, security rules, validation, parent-readonly behavior, or finalization safety nets.

Forbidden bypass flags by design: `--force`, `--skip-tests`, `--skip-validation`, `--skip-docs`, and `--run-all`.
