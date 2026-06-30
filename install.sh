#!/bin/bash
# One-command install for a new Mac:
#   1. builds a universal BusylightMenu.app
#   2. installs it to /Applications
#   3. registers it to launch (hidden) at login
#   4. seeds your color palette if you don't already have one
#   5. launches it
#
# Requires Xcode command-line tools (run `xcode-select --install` first if missing).
set -euo pipefail
cd "$(dirname "$0")"

# 1. Build
./build.sh

# 2. Install to /Applications (replacing any prior copy)
pkill -f BusylightMenu 2>/dev/null || true
sleep 1
rm -rf /Applications/BusylightMenu.app
cp -R build/BusylightMenu.app /Applications/
# Strip any quarantine flag and re-sign ad-hoc so it opens without warnings.
xattr -dr com.apple.quarantine /Applications/BusylightMenu.app 2>/dev/null || true
codesign --force --deep --sign - /Applications/BusylightMenu.app >/dev/null 2>&1 || true
echo "Installed /Applications/BusylightMenu.app"

# 3. Login item (idempotent)
osascript -e 'tell application "System Events" to delete (every login item whose name is "BusylightMenu")' 2>/dev/null || true
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/BusylightMenu.app", hidden:true}' >/dev/null
echo "Registered to launch at login"

# 4. Seed palette if the machine doesn't have one yet.
#    Prefer a private ./palette.json (git-ignored); fall back to the generic example.
PALETTE="$HOME/.config/busylight/palette.json"
SEED=""
[[ -f palette.json ]] && SEED="palette.json"
[[ -z "$SEED" && -f palette.example.json ]] && SEED="palette.example.json"
if [[ ! -f "$PALETTE" && -n "$SEED" ]]; then
  mkdir -p "$(dirname "$PALETTE")"
  cp "$SEED" "$PALETTE"
  echo "Seeded palette at $PALETTE (from $SEED)"
fi

# 5. Launch
open /Applications/BusylightMenu.app
echo "Done — look for the beacon icon in your menu bar."
