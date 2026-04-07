#!/usr/bin/env node
/**
 * ai-regenerate-patch-ci.mjs — CI-ready patch regeneration using Claude Agent SDK.
 *
 * Usage:
 *   node scripts/ai-regenerate-patch-ci.mjs <failed_patch> <old_tag> <new_tag>
 *
 * Environment:
 *   ANTHROPIC_API_KEY — required, set as a GitHub Actions secret
 *
 * This script is the CI equivalent of scripts/ai-regenerate-patch.sh but uses
 * the Claude Agent SDK instead of the Claude CLI, making it runnable in GitHub
 * Actions without installing the CLI.
 */

import { query } from "@anthropic-ai/claude-agent-sdk";
import { readFileSync, writeFileSync, existsSync } from "fs";
import { execSync } from "child_process";
import { basename, resolve } from "path";

const ROOT_DIR = resolve(import.meta.dirname, "..");

function run(cmd, opts = {}) {
  try {
    return execSync(cmd, { encoding: "utf-8", cwd: ROOT_DIR, ...opts }).trim();
  } catch (e) {
    return e.stdout?.trim?.() ?? "";
  }
}

async function main() {
  const [failedPatch, oldTag, newTag] = process.argv.slice(2);

  if (!failedPatch || !oldTag || !newTag) {
    console.error("Usage: ai-regenerate-patch-ci.mjs <failed_patch> <old_tag> <new_tag>");
    process.exit(1);
  }

  if (!process.env.ANTHROPIC_API_KEY) {
    console.error("ERROR: ANTHROPIC_API_KEY environment variable is required.");
    process.exit(1);
  }

  const patchPath = resolve(ROOT_DIR, failedPatch);
  if (!existsSync(patchPath)) {
    console.error(`ERROR: Patch file not found: ${failedPatch}`);
    process.exit(1);
  }

  const buildDir = resolve(ROOT_DIR, "vendor/picoclaw");
  if (!existsSync(resolve(buildDir, ".git"))) {
    console.error("ERROR: vendor/picoclaw not found. Clone upstream first.");
    process.exit(1);
  }

  const patchName = basename(failedPatch, ".patch");
  const patchContent = readFileSync(patchPath, "utf-8");

  console.log(`=== AI Patch Regeneration (CI) ===`);
  console.log(`Patch:   ${patchName}`);
  console.log(`Upgrade: ${oldTag} -> ${newTag}`);
  console.log();

  // Extract patch description from PATCHES.md
  const patchesMd = readFileSync(resolve(ROOT_DIR, "PATCHES.md"), "utf-8");
  const descMatch = patchesMd.match(
    new RegExp(`## ${patchName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}[\\s\\S]*?(?=\\n## |$)`)
  );
  const patchDesc = descMatch ? descMatch[0] : "(No description available)";

  // Get affected files from the patch
  const affectedFiles = [...patchContent.matchAll(/^diff --git a\/(.+?) b\//gm)]
    .map((m) => m[1]);

  console.log("Affected files:");
  affectedFiles.forEach((f) => console.log(`  ${f}`));
  console.log();

  // Get upstream diff between tags for affected files
  let upstreamDiff = "";
  try {
    run(`git fetch --depth 50 origin refs/tags/${oldTag}:refs/tags/${oldTag}`, { cwd: buildDir });
  } catch { /* may already exist */ }

  if (affectedFiles.length > 0) {
    upstreamDiff = run(
      `git diff ${oldTag}..${newTag} -- ${affectedFiles.join(" ")}`,
      { cwd: buildDir }
    );
  }

  // Read current file contents at new tag
  let fileContents = "";
  for (const f of affectedFiles) {
    const filePath = resolve(buildDir, f);
    if (existsSync(filePath)) {
      fileContents += `\n=== ${f} ===\n${readFileSync(filePath, "utf-8")}\n`;
    }
  }

  // Build the prompt
  const prompt = `You are a git patch maintenance agent. A patch failed to apply
after an upstream upgrade.

CONTEXT:
- Old upstream version: ${oldTag}
- New upstream version: ${newTag}
- Failed patch name: ${patchName}
- Failed patch intent:
${patchDesc}

RULES:
1. NEVER change the patch's intent — only adapt its implementation
2. Match the coding style of the upstream project
3. If a function was renamed, update the patch to use the new name
4. If the file was restructured, find the equivalent location
5. If the logic the patch modifies was fundamentally rewritten,
   respond with NEEDS_MANUAL_REVIEW and explain why
6. Output valid git format-patch format with correct line numbers
7. Preserve the original commit author and message

ORIGINAL PATCH:
${patchContent}

UPSTREAM CHANGES to affected files (${oldTag} -> ${newTag}):
${upstreamDiff || "(Could not compute diff)"}

NEW source files at ${newTag}:
${fileContents || "(Could not read files)"}

TASK:
1. Use Bash to run \`git diff ${oldTag}..${newTag} -- ${affectedFiles.join(" ")}\` in the vendor/picoclaw directory to see what changed
2. Use Read to examine the current versions of the affected files in vendor/picoclaw
3. Regenerate the patch so it applies cleanly to ${newTag} while preserving the original intent
4. Write the new patch to ${patchPath}.new using the Write tool
5. Validate by running: cd vendor/picoclaw && git reset --hard ${newTag} && git am --3way "${patchPath}.new"
6. If validation passes, the task is complete. If it fails, iterate and fix the patch.

Output ONLY the final status message. The regenerated patch file is the deliverable.`;

  console.log("Invoking Claude Agent SDK for patch regeneration...");
  console.log();

  // Call Claude via Agent SDK with proper tool access for CI
  let result = "";
  for await (const message of query({
    prompt,
    options: {
      allowedTools: ["Read", "Write", "Bash", "Glob", "Grep"],
      permissionMode: "bypassPermissions",
      cwd: buildDir,
      maxTurns: 30,
    },
  })) {
    if (message.type === "result") {
      result = message.result ?? "";
    }
  }

  if (!result) {
    console.error("ERROR: No response from Claude.");
    process.exit(1);
  }

  // Check if Claude flagged it for manual review
  if (result.includes("NEEDS_MANUAL_REVIEW")) {
    console.error("Claude flagged this patch for MANUAL REVIEW:");
    console.error();
    console.error(result);
    process.exit(1);
  }

  // Check if the .new patch file was written and validates
  const newPatchPath = patchPath + ".new";
  if (!existsSync(newPatchPath)) {
    console.error("ERROR: Agent did not produce a patch file.");
    console.error("Result:", result);
    process.exit(1);
  }

  const patchOutput = readFileSync(newPatchPath, "utf-8");

  // Validate the regenerated patch
  console.log("Validating regenerated patch...");
  run(`git checkout ${newTag}`, { cwd: buildDir });

  try {
    execSync(`git am --3way "${newPatchPath}"`, {
      cwd: buildDir,
      encoding: "utf-8",
      stdio: "pipe",
    });
    console.log();
    console.log("Regenerated patch applies cleanly!");
    writeFileSync(patchPath, patchOutput);
    console.log(`Updated: ${failedPatch}`);
    run(`git checkout ${newTag}`, { cwd: buildDir });
  } catch {
    console.error();
    console.error("AI-generated patch also failed to apply — needs manual review.");
    console.error(`The attempted patch is at: ${newPatchPath}`);
    run("git am --abort", { cwd: buildDir });
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
