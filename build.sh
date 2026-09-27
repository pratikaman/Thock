#!/bin/bash
# Builds build/Thock.app (no Xcode project). ./build.sh --install also copies it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Thock.app
TARGET="$(uname -m)-apple-macos14.0"   # pin: this Mac's CLT defaults to a newer macOS than it runs

if [[ ! -f Resources/AppIcon.icns ]]; then
  swift Tools/icon.swift build/AppIcon.iconset Resources/Fonts/EBGaramond.ttf
  iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -parse-as-library -swift-version 5 -target "$TARGET" Sources/*.swift -o "$APP/Contents/MacOS/Thock"
cp Info.plist "$APP/Contents/"
cp -R Resources/Sounds Resources/Fonts Resources/AppIcon.icns "$APP/Contents/Resources/"

"$APP/Contents/MacOS/Thock" --selftest

# A stable signing identity keeps the Input Monitoring grant across rebuilds; ad-hoc resets it every build.
IDENTITY="${THOCK_SIGN_IDENTITY:-Pratik Dev Signing}"
security find-identity -v -p codesigning | grep -q "\"$IDENTITY\"" || IDENTITY=-
codesign --force --sign "$IDENTITY" "$APP"
echo "built $APP (signed: $IDENTITY)"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Thock || true
  rm -rf /Applications/Thock.app
  cp -R "$APP" /Applications/
  echo "installed /Applications/Thock.app"
fi
