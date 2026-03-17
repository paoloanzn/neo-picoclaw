#!/usr/bin/env bash
# apply-patches.sh — Clone upstream at pinned version and apply all patches in order.
#
# Usage:
#   ./scripts/apply-patches.sh [--tag <override_tag>]
#
# Reads UPSTREAM.conf for repo URL and pinned tag.
# Applies patches from patches/ directory using git am --3way.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load upstream config
# shellcheck source=../UPSTREAM.conf
source "$ROOT_DIR/UPSTREAM.conf"

# Allow tag override via flag
TAG="$UPSTREAM_TAG"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

PATCHES_DIR="$ROOT_DIR/patches"
BUILD_DIR="$ROOT_DIR/vendor/picoclaw"

# Check if there are any patches to apply
PATCH_COUNT=$(find "$PATCHES_DIR" -name '*.patch' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$PATCH_COUNT" -eq 0 ]]; then
  echo "No patches found in $PATCHES_DIR — nothing to apply."
  exit 0
fi

echo "=== PicoClaw Patch Applicator ==="
echo "Upstream: $UPSTREAM_REPO"
echo "Tag:      $TAG"
echo "Patches:  $PATCH_COUNT file(s)"
echo ""

# Clean slate
rm -rf "$BUILD_DIR"
mkdir -p "$(dirname "$BUILD_DIR")"

echo "Cloning upstream at $TAG..."
git clone --depth 1 --branch "$TAG" "$UPSTREAM_REPO" "$BUILD_DIR"

# Apply all patches in lexicographic order
cd "$BUILD_DIR"
APPLIED=0
FAILED=0

for patch in "$PATCHES_DIR"/*.patch; do
  [ -f "$patch" ] || continue
  PATCH_NAME="$(basename "$patch")"
  echo "Applying: $PATCH_NAME"
  if git am --3way "$patch"; then
    APPLIED=$((APPLIED + 1))
  else
    FAILED=$((FAILED + 1))
    echo ""
    echo "FAILED: $PATCH_NAME"
    echo "  To inspect: cd $BUILD_DIR && git am --show-current-patch"
    echo "  To abort:   cd $BUILD_DIR && git am --abort"
    exit 1
  fi
done

echo ""
echo "All $APPLIED patch(es) applied successfully to $TAG."
