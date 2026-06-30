# BusylightMenu

A tiny, dependency-free macOS **menu-bar app** for the Kuando **Busylight Alpha**.
Click the menu-bar lightbulb → a grid of labeled color buttons → click one to set
the light. Replaces the clunky kuandoHUB app.

Native Swift + IOKit only. No Python, no Electron, no third-party libraries.

## Use it

The lightbulb icon lives in your menu bar. Click it, then click a color.
"Off" turns the light off; "Quit" exits.

> The Busylight needs a keepalive every few seconds, so the app stays running in
> the menu bar to hold the color. Quitting the app lets the light go dark.

## Customize colors & labels

Edit `~/.config/busylight/palette.json` — a list of `{label, r, g, b}` (RGB 0–255):

```json
[
  { "label": "Available", "r": 0,   "g": 255, "b": 0 },
  { "label": "Busy",      "r": 255, "g": 0,   "b": 0 }
]
```

Then click **Reload palette** in the menu (no rebuild needed).

## Build

```bash
./build.sh          # produces a universal (arm64 + x86_64) build/BusylightMenu.app
open build/BusylightMenu.app
```

Requires the Xcode command-line tools (Swift). Targets macOS 14+.

## Install on another Mac

Copy this whole folder to the other machine (AirDrop, USB, or `git clone`), then:

```bash
xcode-select --install   # once, if you've never installed the Swift tools
./install.sh             # builds, installs to /Applications, login item, palette, launches
```

`install.sh` produces a **universal** binary, so it runs on both Apple Silicon and
Intel Macs. On first run it seeds a palette (if that Mac doesn't already have one)
from a private `palette.json` if you've placed one next to the installer, otherwise
from the generic `palette.example.json`. To carry your own colors to another Mac,
copy your `~/.config/busylight/palette.json` there (it's intentionally kept out of
this repo).

## Start automatically at login

System Settings → General → Login Items → **＋** → choose
`build/BusylightMenu.app`. (Or move the `.app` to `/Applications` first.)

## Layout

- `Sources/BusylightMenu/Busylight.swift` — HID protocol + keepalive (the device driver)
- `Sources/BusylightMenu/Palette.swift` — color/label model + JSON loader
- `Sources/BusylightMenu/App.swift` — SwiftUI menu-bar UI
- `tools/test_cli.swift` — standalone CLI that cycles colors, for testing the driver
- `build.sh` — compiles the `.app` bundle

## Protocol notes

USB HID, vendor `0x27BB`, product `0x3BCE` (Busylight Alpha). Commands are a
64-byte output report: seven 8-byte "steps" + an 8-byte footer. We use step 0:
`jump` (opcode `0x1`) to show a steady color, `keepalive` (opcode `0x8`) on a
timer to keep the device awake. Colors scale from 0–255 to the device's 0–100.
Footer holds a `0xFFF` pad and a 16-bit big-endian checksum (sum of all bytes
except the two checksum bytes).
