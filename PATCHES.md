# Patch Registry

> This file documents the intent, scope, and risk level of each custom patch
> applied on top of the upstream [sipeed/picoclaw](https://github.com/sipeed/picoclaw).
>
> It serves as both human documentation and structured context for AI agents
> that regenerate patches after upstream upgrades.
>
> **Upstream:** `https://github.com/sipeed/picoclaw.git`
> **Pinned version:** see `UPSTREAM.conf`

---

<!-- Template for new patches:

## NNN-short-description
- **Purpose:** What this patch does and why
- **Files:** list of affected files
- **Upstream PR:** link or "None (reason)"
- **Risk:** LOW | MEDIUM | HIGH — brief justification
- **Added:** YYYY-MM-DD

-->

## 001-add-sop-framework
- **Purpose:** Add SOP-driven execution as a first-class agent behavior. Includes the `sops/` directory with README.md in the default workspace template, and hardcodes SOP lookup instructions (rule #5) into the agent system prompt. This replaces the need to manually configure SOP behavior via memory.md.
- **Files:** `pkg/agent/context.go`, `workspace/sops/README.md`
- **Upstream PR:** None (custom operational framework unlikely to be accepted upstream)
- **Risk:** LOW — additive only. Adds one line to workspace listing, one new rule to system prompt, and one new template file. No existing behavior changed.
- **Added:** 2026-03-17
