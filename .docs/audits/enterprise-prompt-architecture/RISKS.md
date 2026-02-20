---
name: "Enterprise Prompt Architecture — Residual Risks"
description: "Residual risk assessment for enterprise prompt architecture audit"
date: "2026-02-20"
---

# Enterprise Prompt Architecture — Residual Risks

## Active Residual Risks

| # | Risk | Severity | Category | Mitigation |
|---|------|----------|----------|------------|
| 1 | **Cookbook case poisoning** | Medium | Supply-chain | Requires git write access to MCP repos (not user-writable RAG). Brain-exclusive writer; agents read-only. Cookbook cases in versioned `CASES.md`. Cookbook Governance Policy limits pulls to preset + onViolation. |
| 2 | **Standard mode lacks delegation reference** | Low | Functional | CoreInclude workflow guideline provides compact summary. Deep/exhaustive available for complex edge cases. |
| 3 | **ResponseValidation absent in standard** | Medium | Functional | CoreInclude quality-gate rule covers threshold (>=0.75) + retry logic (max 2). Sufficient for standard operations. |
| 4 | **Error playbooks absent in standard** | Low | Functional | Escalation-policy provides 3-tier framework (standard/critical/unrecoverable). Detailed playbooks only needed for deep troubleshooting. |
| 5 | **Sequential reasoning phases absent in standard agents** | Low | Functional | Phase-flow summary always-on provides execution order + gate rules + fallback behavior. Detailed phases available in deep/exhaustive. |
| 6 | **Long exhaustive prompt (756 lines)** | Low | Performance | Exhaustive mode explicitly trades tokens for thoroughness. Used only for security-critical/compliance tasks. Standard mode (362 lines) is the default. |
| 7 | **Text-only compliance** | Medium | Enforcement | All rules are text instructions — model compliance is probabilistic, not mechanical. Iron rules use severity markers (CRITICAL/HIGH) and onViolation actions. Schema validation is the only mechanical enforcement. |
| 8 | **Two-repo architecture** | Medium | Operational | `core/` is a separate git repo. Phase changes require commits in both repos. CI diff-guard covers main repo only. |
| 9 | **Pre-existing test failures** | Medium | Quality | 8 tests in MergerTest/XmlBuilderTest/TomlBuilderTest fail due to API changes predating optimization work. Prevents full `composer test` gate. |

## Risk Classification

- **Supply-chain**: External dependency on MCP repos content integrity
- **Functional**: Standard mode operates with reduced reference material
- **Performance**: Token budget vs thoroughness tradeoff
- **Enforcement**: Text instructions vs mechanical guarantees
- **Operational**: Multi-repo coordination requirements
- **Quality**: Pre-existing technical debt
