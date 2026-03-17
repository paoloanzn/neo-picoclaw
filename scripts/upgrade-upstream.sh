#!/usr/bin/env bash
# upgrade-upstream.sh — Test patches against a new upstream tag and update UPSTREAM.conf.
#
# Usage:
#   ./scripts/upgrade-upstream.sh <new_tag>
#
# Steps:
#   1. Validates the new tag exists in the upstream remote
#   2. Attempts to apply all patches against the new tag
#   3. If successful, updates UPSTREAM.conf with the new tag and SHA
#   4. If patches fail, reports which ones need regeneration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load upstream config
# shellcheck source=../UPSTREAM.conf
source "$ROOT_DIR/UPSTREAM.conf"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <new_tag>"
  echo ""
  echo "Current pinned version: $UPSTREAM_TAG"
  echo ""
  echo "Available upstream tags (latest 10):"
  git ls-remote --tags --sort=-v:refname "$UPSTREAM_REPO" 'refs/tags/v*' \
    | head -10 | sed 's|.*refs/tags/||'
  exit 1
fi

NEW_TAG="$1"
OLD_TAG="$UPSTREAM_TAG"
PATCHES_DIR="$ROOT_DIR/patches"
BUILD_DIR="$ROOT_DIR/vendor/picoclaw"

echo "=== PicoClaw Upstream Upgrade ==="
echo "Current: $OLD_TAG"
echo "Target:  $NEW_TAG"
echo ""

# Validate that the new tag exists
echo "Validating tag $NEW_TAG exists upstream..."
if ! git ls-remote --tags "$UPSTREAM_REPO" "refs/tags/$NEW_TAG" | grep -q "$NEW_TAG"; then
  echo "ERROR: Tag $NEW_TAG not found in $UPSTREAM_REPO"
  exit 1
fi

# Get the new SHA
NEW_SHA=$(git ls-remote "$UPSTREAM_REPO" "refs/tags/$NEW_TAG" | head -1 | awk '{print $1}')
echo "New SHA: $NEW_SHA"
echo ""

# Clone at new tag
rm -rf "$BUILD_DIR"
mkdir -p "$(dirname "$BUILD_DIR")"
echo "Cloning upstream at $NEW_TAG..."
git clone --depth 50 --branch "$NEW_TAG" "$UPSTREAM_REPO" "$BUILD_DIR"

# Try applying patches
cd "$BUILD_DIR"
PATCH_COUNT=$(find "$PATCHES_DIR" -name '*.patch' 2>/dev/null | wc -l | tr -d ' ')

if [[ "$PATCH_COUNT" -eq 0 ]]; then
  echo "No patches to apply."
else
  echo ""
  echo "Applying $PATCH_COUNT patch(es) against $NEW_TAG..."
  echo ""

  APPLIED=0
  FAILED_PATCHES=()

  for patch in "$PATCHES_DIR"/*.patch; do
    [ -f "$patch" ] || continue
    PATCH_NAME="$(basename "$patch")"
    if git am --3way "$patch" 2>/dev/null; then
      echo "  OK: $PATCH_NAME"
      APPLIED=$((APPLIED + 1))
    else
      git am --abort 2>/dev/null || true
      echo "  FAIL: $PATCH_NAME"
      FAILED_PATCHES+=("$PATCH_NAME")
    fi
    # Reset for next patch test (apply independently)
    git reset --hard "$NEW_TAG" 2>/dev/null
  done

  echo ""
  if [[ ${#FAILED_PATCHES[@]} -gt 0 ]]; then
    echo "WARNING: ${#FAILED_PATCHES[@]} patch(es) failed to apply against $NEW_TAG:"
    for fp in "${FAILED_PATCHES[@]}"; do
      echo "  - $fp"
    done
    echo ""
    echo "Options:"
    echo "  1. Regenerate with AI:  ./scripts/ai-regenerate-patch.sh <patch> $OLD_TAG $NEW_TAG"
    echo "  2. Manual fix:          Resolve conflicts and re-export with generate-patches.sh"
    echo ""
    echo "UPSTREAM.conf was NOT updated. Fix patches first."
    exit 1
  fi

  echo "All $APPLIED patch(es) apply cleanly against $NEW_TAG."
fi

# Update UPSTREAM.conf
cd "$ROOT_DIR"
cat > UPSTREAM.conf <<EOF
# Upstream configuration — source of truth for the base version
UPSTREAM_REPO="https://github.com/sipeed/picoclaw.git"
UPSTREAM_TAG="$NEW_TAG"
UPSTREAM_SHA="$NEW_SHA"
EOF

echo ""
echo "UPSTREAM.conf updated: $OLD_TAG -> $NEW_TAG"
echo "Run 'git diff UPSTREAM.conf' to review, then commit."
