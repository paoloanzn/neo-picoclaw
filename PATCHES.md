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

## 002-relax-exec-guard
- **Purpose:** Relax the exec tool's safety guard so workspace restriction is usable for real development. Removes deny patterns that blocked normal shell features (command substitution `$()`, variable expansion `${}`, backticks, heredocs, eval, source) and standard dev tools (git push, ssh, chmod, chown, kill). Adds safe system path prefixes (`/usr/`, `/bin/`, `/tmp/`, etc.) so commands referencing system tools/binaries aren't blocked by workspace boundary checks. Security is preserved for genuinely dangerous operations (rm -rf, disk wipe, sudo, remote code exec, docker, system packages).
- **Files:** `pkg/tools/shell.go`, `pkg/tools/shell_test.go`
- **Upstream PR:** None (upstream may prefer the stricter defaults for safety-first deployments)
- **Risk:** MEDIUM — modifies security-adjacent code. Reduces deny list from ~30 to ~24 patterns and widens path allowlist. Destructive/escalation patterns remain blocked. Tests updated and passing.
- **Added:** 2026-03-17

## 004-readme-install-line
- **Purpose:** Add a prominent quick-install one-liner block at the top of the upstream README for the custom fork. Gives users a single copy-paste command to clone, apply patches, and build. Links to PATCHES.md for patch details.
- **Files:** `README.md`
- **Upstream PR:** None (fork-specific install instructions)
- **Risk:** LOW — additive only. Inserts a blockquote after the header; no existing content modified.
- **Added:** 2026-03-17
