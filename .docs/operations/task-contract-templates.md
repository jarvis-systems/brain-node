---
name: "Per-Task Contract Templates"
description: "Copy-paste templates for task execution: whitelist, stop conditions, evidence pack, mode declaration"
type: operations
date: 2026-02-22
version: "1.0.0"
status: active
---

# Per-Task Contract Templates

Canonical copy-paste blocks for per-task execution contracts. Each template is self-contained. Paste into task prompt, fill placeholders.

Context: per-task contract elements are defined in `.docs/architecture/instruction-surfaces.md` (Output Contract > Per-Task Contract Elements). Evidence Pack structure follows `.docs/product/15-model2-operating-contract.md` (Section 6+).

---

## Template 1: Micro-Batch (<=2 files)

```
# Task: {TASK_NAME}
# Mode: EVIDENCE-ONLY | PLAN-ONLY  (pick one; mixing = P0 failure)
# PARALLELISM_BUDGET={1|2|3}

## Touch Whitelist
- {file-1.ext}
- {file-2.ext}

## STOP CONDITIONS
- Any gate FAIL -> stop, report, do NOT commit
- Touch outside whitelist -> stop immediately
- If scope creep detected -> report-only, ask GO

## Evidence Pack
| Gate | Command | Status | Key Metric |
|------|---------|--------|------------|
| tests | composer test | PASS/FAIL | {N} tests |
| phpstan | composer analyse | PASS/FAIL | 0 errors |
| docs | brain docs --validate | PASS/FAIL | invalid=0 |

## Commit
{type}({scope}): {description}
```

---

## Template 2: Macro-Batch Multi-Track (3 tracks)

```
# Task: {TASK_NAME}
# Mode: EVIDENCE-ONLY | PLAN-ONLY
# PARALLELISM_BUDGET=3

## Track A (Main): {track-a-description}
Touch Whitelist: {file-a1}, {file-a2}

## Track B (Sub-agent): {track-b-description}
Touch Whitelist: {file-b1}

## Track C (Sub-agent): {track-c-description}
Touch Whitelist: {file-c1}

## Cross-Repo Boundary Rule
- Root repo: {root files only}
- CLI repo: {cli files only}
- NEVER cross repo boundary in a single sub-agent

## STOP CONDITIONS
- Any track gate FAIL -> pause that track, continue others
- Cross-repo file conflict -> stop both tracks, report
- Touch outside any track whitelist -> stop that track
- Total touched files > {N} -> stop, reassess scope

## Sub-Agent Report Slots
### Track A Result
{status}: {summary}
Files: {list}

### Track B Result
{status}: {summary}
Files: {list}

### Track C Result
{status}: {summary}
Files: {list}

## Evidence Pack
| Gate | Command | Status | Key Metric |
|------|---------|--------|------------|
| tests | composer test | PASS/FAIL | {N} tests |
| phpstan | composer analyse | PASS/FAIL | 0 errors |
| docs | brain docs --validate | PASS/FAIL | invalid=0 |
| formats | verify-client-formats.sh | PASS/FAIL | {N}/{N} |
| metrics | verify-compile-metrics.sh | PASS/FAIL | {N}/{N} |
| audit | audit-enterprise.sh | PASS/FAIL | WARN:0 FAIL:0 |

## Commit
{type}({scope}): {description}
```

---

## Template 3: Investigate-Only / Report-Only

```
# Task: {TASK_NAME}
# Mode: EVIDENCE-ONLY (investigation still requires evidence)
# PARALLELISM_BUDGET={1|2|3}

## Scope
Investigation only. NO file modifications. NO commits.

## Touch Whitelist
(empty - read-only task)

## STOP CONDITIONS
- Any urge to modify files -> stop, report finding instead
- If investigation reveals P0 issue -> report immediately, do NOT fix

## Required Evidence
| What | How | Output |
|------|-----|--------|
| {question-1} | {command or search} | {paste stdout} |
| {question-2} | {command or search} | {paste stdout} |

## Report Structure
1. Findings (what was discovered)
2. Evidence (commands run + raw output)
3. Recommendations (actionable next steps, NOT executed)
```

---

## Template 4: Release / GO PRE-PUB

```
# Task: GO PRE-PUB for v{X.Y.Z}
# Mode: EVIDENCE-ONLY (mandatory for releases)
# PARALLELISM_BUDGET=1 (sequential for safety)

## Touch Whitelist
- CHANGELOG.md (if tracked)
- composer.json (version bump only)

## STOP CONDITIONS (strict)
- ANY gate FAIL -> full stop, no tag, no push
- Uncommitted changes after compile -> full stop (non-determinism)
- Secret pattern detected -> full stop, rotate credentials
- Missing pre-pub checklist item -> full stop

## Pre-Publication Checklist
See: .docs/product/10-pre-publication.md

## Tag + Lock Semantics
- Tag format: v{X.Y.Z} (semver, no pre-release suffix for stable)
- Tag MUST point to green-gate commit (all gates PASS)
- After tag: branch is locked for that version

## Evidence Pack
| Gate | Command | Status | Key Metric |
|------|---------|--------|------------|
| tests | composer test | PASS/FAIL | {N} tests, {N} assertions |
| phpstan | composer analyse | PASS/FAIL | 0 errors |
| docs | brain docs --validate | PASS/FAIL | invalid=0, warnings=0 |
| formats | verify-client-formats.sh | PASS/FAIL | {N}/{N} PASS |
| metrics | verify-compile-metrics.sh | PASS/FAIL | {N}/{N} PASS |
| audit | audit-enterprise.sh | PASS/FAIL | PASS:{N} WARN:0 FAIL:0 |
| secrets | scan-secrets.sh (if exists) | PASS/FAIL | 0 findings |
| compile | brain compile + git diff | PASS/FAIL | clean worktree |

## GO / NO-GO Decision
All gates PASS -> GO: tag + push
Any gate FAIL -> NO-GO: fix first, re-run from top
```
