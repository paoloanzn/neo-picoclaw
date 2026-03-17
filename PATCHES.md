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

## 003-ci-autofix-agent-sdk
- **Purpose:** Add fully automated cloud-based patch maintenance pipeline. When upstream releases a new tag, the auto-fix workflow tries all patches, invokes Claude Agent SDK to regenerate any that fail, validates the full sequence, and creates a PR — all without local CLI or manual intervention. Replaces the local `ai-regenerate-patch.sh` approach with a headless CI-compatible Node.js script. Also updates `upstream-watch.yml` to trigger the new auto-fix pipeline instead of the basic `patch-ci.yml`.
- **Files:** `.github/workflows/patch-autofix.yml`, `.github/workflows/upstream-watch.yml`, `scripts/ai-regenerate-patch-ci.mjs`, `scripts/package.json`
- **Upstream PR:** None (custom fork maintenance infrastructure)
- **Risk:** LOW — additive CI workflows and scripts only. No application code changed. Requires `ANTHROPIC_API_KEY` secret in GitHub Actions.
- **Added:** 2026-03-17

## 004-fix-subagent-tools
- **Purpose:** Fix critical bug where subagents cannot use any tools. `SubagentManager` was initialized with an empty `ToolRegistry` and `SetTools()` was never called after the multi-agent refactor, so all subagent tool invocations returned `"tool not found"`. Fix adds `ToolRegistry.Clone()` method and wires it into `registerSharedTools()` to propagate file, exec, web, and other tools to subagents while excluding spawn/spawn_status (preventing recursive spawning).
- **Files:** `pkg/tools/registry.go`, `pkg/tools/registry_test.go`, `pkg/agent/loop.go`
- **Upstream PR:** Likely upstreamable — this is a clear regression fix
- **Risk:** LOW — single-line wiring fix plus defensive Clone helper. No behavioral change for existing tools. 3 new tests added.
- **Added:** 2026-03-17
