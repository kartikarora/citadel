#!/usr/bin/env bash
set -euo pipefail

# update_homebrew_tap.sh
# Usage: ./scripts/update_homebrew_tap.sh <VERSION> <DMG_PATH> <TAR_PATH> [TAP_REPO]

VERSION="${1:-}"
DMG_PATH="${2:-}"
TAR_PATH="${3:-}"
TAP_REPO="${4:-kartikarora/homebrew-tap}"

if [[ -z "$VERSION" || -z "$DMG_PATH" || -z "$TAR_PATH" ]]; then
  echo "Usage: $0 <VERSION> <DMG_PATH> <TAR_PATH> [TAP_REPO]"
  exit 1
fi

# Clean version (strip leading v)
VERSION="${VERSION#v}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Error: DMG file not found at $DMG_PATH"
  exit 1
fi

if [[ ! -f "$TAR_PATH" ]]; then
  echo "Error: TAR file not found at $TAR_PATH"
  exit 1
fi

echo "Computing SHA256 hashes..."
DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
TAR_SHA256=$(shasum -a 256 "$TAR_PATH" | awk '{print $1}')

echo "  DMG SHA256: $DMG_SHA256"
echo "  TAR SHA256: $TAR_SHA256"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/packaging/homebrew"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Cloning $TAP_REPO..."
if git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${TAP_REPO}.git" "$TEMP_DIR/tap" 2>/dev/null || git clone "https://github.com/${TAP_REPO}.git" "$TEMP_DIR/tap"; then
  mkdir -p "$TEMP_DIR/tap/Formula"
  mkdir -p "$TEMP_DIR/tap/Casks"

  # Generate Formula
  sed -e "s/__VERSION__/$VERSION/g" \
      -e "s/__TAR_SHA256__/$TAR_SHA256/g" \
      "$TEMPLATE_DIR/Formula/citadel.rb.template" > "$TEMP_DIR/tap/Formula/citadel.rb"

  # Generate Cask
  sed -e "s/__VERSION__/$VERSION/g" \
      -e "s/__DMG_SHA256__/$DMG_SHA256/g" \
      "$TEMPLATE_DIR/Casks/citadel.rb.template" > "$TEMP_DIR/tap/Casks/citadel.rb"

  cd "$TEMP_DIR/tap"
  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"
  git add Formula/citadel.rb Casks/citadel.rb

  if git diff --staged --quiet; then
    echo "No changes in tap formula or cask."
  else
    git commit -m "chore(citadel): update formula and cask to v${VERSION}"
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      git push origin HEAD:main || git push origin HEAD:master
      echo "Successfully pushed v${VERSION} update to $TAP_REPO!"
    else
      echo "GITHUB_TOKEN not provided; skipping push."
    fi
  fi
else
  echo "Notice: Could not clone $TAP_REPO (repository may not exist or access token lacks permission)."
  echo "Generated local formula and cask are stored in packaging/homebrew/ for manual import if needed."
fi
