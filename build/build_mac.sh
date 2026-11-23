#!/bin/bash
# FOHstick – build macOS .app + .dmg (Apple Silicon + Intel)
# (c) 2026 fristik.eu · apps@fristik.eu
# Usage:  bash build/build_mac.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-}"
python3 build/gen.py ${VERSION:+"$VERSION"}
VERSION="$(python3 -c 'import re,sys;print(re.search(r"APP_VERSION : \"([^\"]+)\"",open("build/out/mac/app.applescript",encoding="utf-8").read()).group(1))')"

OUT="build/out/mac"
DIST="dist"
APP="$DIST/FOHstick.app"
mkdir -p "$DIST"
rm -rf "$APP" "$DIST/dmg"

echo "› Compiling app…"
osacompile -s -o "$APP" "$OUT/app.applescript"
cp "$OUT/conv.sh" "$OUT/usbformat.sh" "$OUT/fristik.png" "$APP/Contents/Resources/"
chmod 755 "$APP/Contents/Resources/conv.sh" "$APP/Contents/Resources/usbformat.sh"

echo "› Icon…"
ICONSET="$(mktemp -d)/icon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$OUT/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s*2)); sips -z $d $d "$OUT/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/applet.icns"
rm -f "$APP/Contents/Resources/Assets.car"

echo "› Info.plist…"
P="$APP/Contents/Info.plist"
plutil -remove CFBundleIconName "$P" 2>/dev/null || true
plutil -replace CFBundleIconFile -string "applet" "$P"
plutil -replace CFBundleName -string "FOHstick" "$P"
plutil -replace CFBundleDisplayName -string "FOHstick" "$P" 2>/dev/null || plutil -insert CFBundleDisplayName -string "FOHstick" "$P"
plutil -replace CFBundleIdentifier -string "eu.fristik.fohstick" "$P"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$P"
plutil -replace CFBundleVersion -string "$VERSION" "$P"
plutil -replace LSMinimumSystemVersion -string "10.14" "$P" 2>/dev/null || plutil -insert LSMinimumSystemVersion -string "10.14" "$P"
plutil -replace NSHumanReadableCopyright -string "© 2026 fristik.eu · apps@fristik.eu · https://fristik.eu" "$P"
plutil -replace NSAppleEventsUsageDescription -string "FOHstick uses AppleScript to show dialogs." "$P" 2>/dev/null || true

echo "› Architectures: $(lipo -archs "$APP/Contents/MacOS/applet" 2>/dev/null || echo '?')"
codesign --force --deep -s - "$APP"

echo "› DMG…"
mkdir -p "$DIST/dmg"
cp -R "$APP" "$DIST/dmg/"
ln -s /Applications "$DIST/dmg/Applications"
DMG="$DIST/FOHstick-$VERSION-mac.dmg"
rm -f "$DMG"
hdiutil create -volname "FOHstick $VERSION" -srcfolder "$DIST/dmg" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$DIST/dmg"
echo "✓ $DMG"
