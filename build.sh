#!/bin/bash
# Build BusylightMenu.app — a self-contained, dependency-free macOS menu-bar app.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/BusylightMenu.app"
MACOS="$APP/Contents/MacOS"
BIN="$MACOS/BusylightMenu"

rm -rf "$APP"
mkdir -p "$MACOS"

echo "Compiling (universal: arm64 + x86_64)…"
COMMON=(-parse-as-library -O -framework AppKit -framework SwiftUI -framework IOKit Sources/BusylightMenu/*.swift)
swiftc "${COMMON[@]}" -target arm64-apple-macos14.0  -o "$BIN.arm64"
swiftc "${COMMON[@]}" -target x86_64-apple-macos14.0 -o "$BIN.x86_64"
lipo -create "$BIN.arm64" "$BIN.x86_64" -output "$BIN"
rm -f "$BIN.arm64" "$BIN.x86_64"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>BusylightMenu</string>
    <key>CFBundleDisplayName</key>     <string>Busylight</string>
    <key>CFBundleIdentifier</key>      <string>local.busylight.menu</string>
    <key>CFBundleVersion</key>         <string>1.0</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleExecutable</key>      <string>BusylightMenu</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc codesign so the binary runs without "damaged app" prompts.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP"
