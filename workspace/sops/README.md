# SOPs (Standard Operating Procedures)

This folder contains task-specific SOP documents that define repeatable operational procedures.

## How the agent uses SOPs
- Before executing a requested task, the agent checks this folder for a relevant SOP and follows it if found.
- Sub-agents spawned for delegated work will also read the relevant SOP before executing.
- SOPs should be kept concise, actionable, and versioned/dated when helpful.

## Naming convention
- Use: `SOP-<topic>-v<major>.<minor>.md`
  - Example: `SOP-release-checklist-v1.0.md`

## Template
Each SOP should typically include:
1. **Purpose**
2. **Scope / When to use**
3. **Inputs**
4. **Procedure (step-by-step)**
5. **Outputs / Definition of done**
6. **Edge cases / Safety checks**
7. **Logging / Artifacts** (files created/updated)
