#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/AIUsageMonitor.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
VERSION="${VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

if [[ -z "$VERSION" ]]; then
  if git -C "$ROOT_DIR" describe --tags --exact-match >/dev/null 2>&1; then
    VERSION="$(git -C "$ROOT_DIR" describe --tags --exact-match | sed 's/^v//')"
  else
    VERSION="0.1.0"
  fi
fi

swift build -c release --package-path "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$ROOT_DIR/.build/release/AIUsageMonitor" "$MACOS_DIR/AIUsageMonitor"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>AIUsageMonitor</string>
  <key>CFBundleIdentifier</key>
  <string>local.ai-usage-monitor</string>
  <key>CFBundleName</key>
  <string>AI Usage Monitor</string>
  <key>CFBundleDisplayName</key>
  <string>AI Usage Monitor</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"
