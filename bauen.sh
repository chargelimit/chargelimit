#!/bin/bash
# Baut ChargeLimit als .app-Bündel (Plan 4.1, 4.8): build/ChargeLimit.app, ad-hoc signiert.
# Aufruf: bash ChargeLimit/bauen.sh   — erzeugt dazu build/ChargeLimit.dmg zum Installieren und Weitergeben.
set -euo pipefail
ORDNER="$(cd "$(dirname "$0")" && pwd)"
APP="$ORDNER/build/ChargeLimit.app"

echo "==> Bauen (release)…"
swift build --package-path "$ORDNER" -c release
BIN="$(swift build --package-path "$ORDNER" -c release --show-bin-path)/ChargeLimit"

echo "==> Bündel anlegen…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ChargeLimit"

ICON_ZEILE=""
ICON_SRC="$ORDNER/icon/AppIcon-1024.png"
if [ -f "$ICON_SRC" ]; then
  echo "==> Logo erzeugen…"
  SET="$(mktemp -d)/AppIcon.iconset"; mkdir -p "$SET"
  for G in 16 32 128 256 512; do
    sips -z $G $G "$ICON_SRC" --out "$SET/icon_${G}x${G}.png" >/dev/null
    sips -z $((G*2)) $((G*2)) "$ICON_SRC" --out "$SET/icon_${G}x${G}@2x.png" >/dev/null
  done
  iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$(dirname "$SET")"
  ICON_ZEILE="<key>CFBundleIconFile</key><string>AppIcon</string>"
else
  echo "   (kein icon/AppIcon-1024.png – App ohne Logo)"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>               <string>ChargeLimit</string>
    <key>CFBundleDisplayName</key>        <string>ChargeLimit</string>
    <key>CFBundleIdentifier</key>         <string>io.github.chargelimit</string>
    <key>CFBundleExecutable</key>         <string>ChargeLimit</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>            <string>1</string>
    <key>LSMinimumSystemVersion</key>     <string>27.0</string>
    <key>LSArchitecturePriority</key>     <array><string>arm64</string></array>
    <key>LSUIElement</key>                <true/>
    <key>NSPrincipalClass</key>           <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>    <true/>
    ${ICON_ZEILE}
</dict>
</plist>
PLIST

echo "==> Ad-hoc signieren…"
codesign --force -s - "$APP"
echo "FERTIG: $APP"

# DMG zum Weitergeben (Wunsch des Nutzers 24.11.; Muster LocDict scripts/make_dmg.sh):
# App + Verknüpfung „Applications“ + Installation.txt + Volume-Logo.
echo "==> DMG bauen…"
DMG="$ORDNER/build/ChargeLimit.dmg"
STAGE="$(mktemp -d)/ChargeLimit"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ORDNER/Installation.txt" "$STAGE/"
if [ -f "$APP/Contents/Resources/AppIcon.icns" ]; then
  cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
  SetFile -a C "$STAGE" 2>/dev/null || true
fi
hdiutil create -quiet -volname "ChargeLimit" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$(dirname "$STAGE")"
echo "FERTIG: $DMG"
