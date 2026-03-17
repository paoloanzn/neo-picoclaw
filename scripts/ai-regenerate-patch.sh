#!/usr/bin/env bash
# ai-regenerate-patch.sh — Use Claude Code to regenerate a broken patch for a new upstream version.
#
# Usage:
#   ./scripts/ai-regenerate-patch.sh <failed_patch> <old_tag> <new_tag>
#
# Prerequisites:
#   - `claude` CLI must be installed and authenticated
#   - vendor/picoclaw must be cloned at the new tag
#
# The script:
#   1. Reads the patch intent from PATCHES.md
#   2. Extracts the upstream diff between old and new tags for affected files
#   3. Invokes Claude Code with full context to regenerate the patch
#   4. Validates the regenerated patch applies cleanly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <failed_patch> <old_tag> <new_tag>"
  echo ""
  echo "Example:"
  echo "  $0 patches/001-add-stealth-flag.patch v0.2.3 v0.3.0"
  exit 1
fi

FAILED_PATCH="$1"
OLD_TAG="$2"
NEW_TAG="$3"

BUILD_DIR="$ROOT_DIR/vendor/picoclaw"

# Validate inputs
if [[ ! -f "$ROOT_DIR/$FAILED_PATCH" ]]; then
  echo "ERROR: Patch file not found: $FAILED_PATCH"
  exit 1
fi

if [[ ! -d "$BUILD_DIR/.git" ]]; then
  echo "ERROR: vendor/picoclaw not found. Run apply-patches.sh or upgrade-upstream.sh first."
  exit 1
fi

# Check that claude CLI is available
if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found. Install Claude Code first."
  echo "  See: https://docs.anthropic.com/en/docs/claude-code"
  exit 1
fi

PATCH_NAME=$(basename "$FAILED_PATCH" .patch)

echo "=== AI Patch Regeneration ==="
echo "Patch:    $PATCH_NAME"
echo "Upgrade:  $OLD_TAG -> $NEW_TAG"
echo ""

# Extract patch description from PATCHES.md
PATCH_DESC=$(sed -n "/## $PATCH_NAME/,/^## /p" "$ROOT_DIR/PATCHES.md" | head -n -1)
if [[ -z "$PATCH_DESC" ]]; then
  echo "WARNING: No description found for $PATCH_NAME in PATCHES.md"
  PATCH_DESC="(No description available — infer intent from the patch content)"
fi

# Get list of affected files from the patch
AFFECTED_FILES=$(grep "^diff --git" "$ROOT_DIR/$FAILED_PATCH" | \
  sed 's|diff --git a/\(.*\) b/.*|\1|')

echo "Affected files:"
for f in $AFFECTED_FILES; do
  echo "  $f"
done
echo ""

# Get upstream diff between old and new tag for affected files
cd "$BUILD_DIR"

# Fetch enough history for both tags
git fetch --depth 50 origin "refs/tags/$OLD_TAG:refs/tags/$OLD_TAG" 2>/dev/null || true
git fetch --depth 50 origin "refs/tags/$NEW_TAG:refs/tags/$NEW_TAG" 2>/dev/null || true

UPSTREAM_DIFF=$(git diff "$OLD_TAG..$NEW_TAG" -- $AFFECTED_FILES 2>/dev/null || echo "(Could not compute diff — tags may need deeper fetch)")

# Read current file contents at new tag
FILE_CONTENTS=""
for f in $AFFECTED_FILES; do
  if [[ -f "$f" ]]; then
    FILE_CONTENTS+="
=== $f ===
$(cat "$f")
"
  fi
done

cd "$ROOT_DIR"

echo "Invoking Claude Code for patch regeneration..."
echo ""

# Invoke Claude Code with full context
claude -p "You are a git patch maintenance agent. A patch failed to apply
after an upstream upgrade.

CONTEXT:
- Old upstream version: $OLD_TAG
- New upstream version: $NEW_TAG
- Failed patch name: $PATCH_NAME
- Failed patch intent:
$PATCH_DESC

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
$(cat "$FAILED_PATCH")

UPSTREAM CHANGES to affected files ($OLD_TAG -> $NEW_TAG):
$UPSTREAM_DIFF

NEW source files at $NEW_TAG:
$FILE_CONTENTS

TASK: Regenerate the patch so it applies cleanly to $NEW_TAG
while preserving the original intent. Output ONLY the new
.patch file content in git format-patch format.
Keep the same commit message. Adapt line numbers and context." \
  > "$FAILED_PATCH.new"

# Check if the AI flagged it for manual review
if grep -q "NEEDS_MANUAL_REVIEW" "$FAILED_PATCH.new"; then
  echo ""
  echo "AI flagged this patch for MANUAL REVIEW:"
  echo ""
  cat "$FAILED_PATCH.new"
  rm "$FAILED_PATCH.new"
  exit 1
fi

# Validate the regenerated patch
echo "Validating regenerated patch..."
cd "$BUILD_DIR"
git checkout "$NEW_TAG" 2>/dev/null
if git am --3way "$ROOT_DIR/$FAILED_PATCH.new"; then
  echo ""
  echo "Regenerated patch applies cleanly!"
  mv "$ROOT_DIR/$FAILED_PATCH.new" "$ROOT_DIR/$FAILED_PATCH"
  echo "Updated: $FAILED_PATCH"
  git checkout "$NEW_TAG" 2>/dev/null
else
  echo ""
  echo "AI-generated patch also failed to apply — needs manual review."
  echo "The attempted patch is at: $FAILED_PATCH.new"
  git am --abort 2>/dev/null || true
  exit 1
fi
