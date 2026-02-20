---
name: "Permissions Contract"
description: "Permission model, safe-by-default posture, --yolo scope, and enterprise recommendations"
type: "product"
version: "v0.2.0"
status: "active"
---

# Permissions Contract

## Safe-by-Default

Brain's compiled artifacts enforce a **safe-by-default** posture. The AI CLI (Claude Code) requires explicit user approval for every potentially impactful action:

| Action Category | Default Behavior | Approval Required |
|----------------|------------------|-------------------|
| Read files | Allowed | No |
| Search/Glob | Allowed | No |
| Write/Edit files | Blocked | Yes |
| Bash commands | Blocked | Yes |
| MCP tool calls | Blocked | Yes |
| Web fetch | Blocked | Yes |

In default mode, the AI agent **asks before acting**. This is the intended production behavior.

## What --yolo Enables

The `--yolo` flag (or `--dangerously-skip-permissions`) disables the approval prompt for tool invocations. When active:

- **Write/Edit**: Files are modified without confirmation
- **Bash**: Shell commands execute without confirmation
- **MCP calls**: Vector memory and task operations proceed automatically
- **Web fetch**: External URLs are fetched without confirmation

The `--yolo` flag does NOT bypass:
- Iron rules compiled into artifacts (these are instructions to the model, not permission gates)
- Governance rules (delegation depth, authority levels, non-recursive delegation)
- Model safety filters (built into the AI model itself)
- Benchmark validation checks (these run in shell, not in AI CLI)

## Forbidden Always

The following actions are forbidden regardless of permission mode. These are enforced by compiled iron rules and governance policies:

| Forbidden Action | Iron Rule | Enforcement |
|-----------------|-----------|-------------|
| Mode self-switch at runtime | `no-mode-self-switch` (CRITICAL) | Compiled iron rule |
| Recursive delegation | `non-recursive` (CRITICAL) | Compiled iron rule |
| Direct Brain execution (beyond 5% meta-ops) | `delegation-limit` (CRITICAL) | Compiled iron rule |
| Runtime cookbook parameter construction | `cookbook-governance` (CRITICAL) | Compiled iron rule + ADV-003 benchmark |
| Manual timestamp manipulation | `timestamps-auto` (CRITICAL) | Compiled iron rule |
| Parent task modification | `parent-readonly` (CRITICAL) | Compiled iron rule |
| Editing compiled output (`.claude/`, `.mcp.json`) | `never-write-compiled` (CRITICAL) | Compiled iron rule |
| Secret exposure (API keys, credentials) | Safety policy | Model + governance |
| Force push to main/master | Git safety | AI CLI built-in |

## Recommended Enterprise Posture

### Development

```
# Standard development: approval prompts enabled (default)
brain compile
claude

# Fast iteration: skip approvals (developer discretion)
claude --yolo
```

Use `--yolo` only during active development with local, reversible changes. Never with shared branches or production data.

### CI/CD

```
# CI: never use --yolo. All operations are scripted, not interactive.
PIN_STRICT=1 brain compile
composer benchmark:ci
bash scripts/verify-pins.sh
```

CI pipelines should never invoke the AI CLI interactively. All CI operations use shell scripts (`benchmark-llm-suite.sh`, `verify-pins.sh`, `generate-manifest.sh`) that do not require `--yolo`.

### Enterprise Demo / Pilot

```
# Demo: --yolo is acceptable for automated demo execution
bash scripts/demo-enterprise.sh --model haiku --yolo

# Pilot validation: --yolo for unattended execution
bash scripts/demo-enterprise.sh --model haiku
```

The demo script passes `--yolo` to the AI CLI for unattended multi-turn scenario execution. This is acceptable because demo scenarios are curated, read-only (no destructive operations), and produce auditable output (`dist/demo-report.json`).

### Audit

For any deployment, collect operational evidence:

```
bash scripts/collect-ops-evidence.sh
```

This generates `dist/ops-evidence.json` with manifest hashes, pin status, mode configuration, and demo results. Include this artifact in support requests and audit reviews.

See the [Pilot Guide](06-pilot.md) for demo execution details and success criteria.
