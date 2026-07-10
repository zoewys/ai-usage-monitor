#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-${VERSION:-}}"
APP_DIR="$ROOT_DIR/build/AIUsageMonitor.app"
RELEASE_DIR="$ROOT_DIR/build/releases"
STAGE_DIR="$ROOT_DIR/build/dmg-stage"

if [[ -z "$VERSION" ]]; then
  echo "usage: scripts/build_dmg.sh <version>" >&2
  exit 2
fi

VERSION="${VERSION#v}"
DMG_PATH="$RELEASE_DIR/AIUsageMonitor-v${VERSION}.dmg"

if [[ ! -d "$APP_DIR" ]]; then
  echo "missing app bundle: $APP_DIR" >&2
  echo "run scripts/build_app.sh first" >&2
  exit 1
fi

cleanup() {
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR" "$RELEASE_DIR"
ditto "$APP_DIR" "$STAGE_DIR/AIUsageMonitor.app"
ln -s /Applications "$STAGE_DIR/Applications"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "AI Usage Monitor" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"
echo "$DMG_PATH"
