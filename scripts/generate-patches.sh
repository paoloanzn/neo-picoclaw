#!/usr/bin/env bash
# generate-patches.sh — Generate patch files from commits on a working branch.
#
# Usage:
#   ./scripts/generate-patches.sh [--since <tag>]
#
# This script generates git format-patch files for all commits since the
# upstream tag (from UPSTREAM.conf) on the current branch, and writes them
# into the patches/ directory.
#
# Workflow:
#   1. Clone upstream, checkout the pinned tag
#   2. Create a working branch, make your changes as focused commits
#   3. Run this script from the working branch to export patches

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load upstream config
# shellcheck source=../UPSTREAM.conf
source "$ROOT_DIR/UPSTREAM.conf"

# Allow base ref override
SINCE="$UPSTREAM_TAG"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

PATCHES_DIR="$ROOT_DIR/patches"

echo "=== PicoClaw Patch Generator ==="
echo "Base ref: $SINCE"
echo "Output:   $PATCHES_DIR/"
echo ""

# Count commits to export
COMMIT_COUNT=$(git rev-list --count "$SINCE"..HEAD 2>/dev/null || echo 0)
if [[ "$COMMIT_COUNT" -eq 0 ]]; then
  echo "No commits found since $SINCE — nothing to generate."
  exit 0
fi

echo "Found $COMMIT_COUNT commit(s) since $SINCE"

# Clear existing patches (regenerate fresh set)
rm -f "$PATCHES_DIR"/*.patch

# Generate patches with zero-padded numeric prefixes
git format-patch "$SINCE" -o "$PATCHES_DIR" --zero-commit --numbered

echo ""
echo "Generated patches:"
for p in "$PATCHES_DIR"/*.patch; do
  [ -f "$p" ] || continue
  echo "  $(basename "$p")"
done

echo ""
echo "Done. Remember to update PATCHES.md with descriptions for any new patches."
