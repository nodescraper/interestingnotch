<!-- ───────────────────────────  HERO  ─────────────────────────── -->
<div align="center">

# BoringNotch SE

### A playful macOS notch companion packed with widgets, media controls, and live utilities.

Turn the MacBook notch into a useful little control surface for music, shelf tools, calendar, webcam, widgets, and system feedback.

![macOS](https://img.shields.io/badge/macOS-14%2B-111827?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6-ready-F97316?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0F766E)
![Sparkle](https://img.shields.io/badge/updates-Sparkle-1D4ED8)
![License: MIT](https://img.shields.io/badge/license-MIT-334155)

</div>

> [!NOTE]
> BoringNotch SE is a showcase-style macOS utility focused on turning the notch into something expressive and actually useful. It combines media controls, widgets, a shelf, calendar access, webcam utilities, and system overlays in one compact surface.

---

## Contents

- [What it is](#what-it-is)
- [Features](#features)
- [Built with](#built-with)
- [Requirements](#requirements)
- [Download](#download)
- [Build from source](#build-from-source)
- [Run in development](#run-in-development)
- [Project layout](#project-layout)
- [License](#license)

---

## What it is

BoringNotch SE is a macOS notch utility by `NodeScraper`. It treats the notch like a lightweight command surface instead of dead screen space, giving you quick access to ongoing activity, small tools, and glanceable system information without opening full apps.

The project is built as a native SwiftUI desktop app and includes both user-facing notch interactions and lower-level macOS integrations for media, drag-and-drop shelf behavior, webcam access, system overlays, and background helper functionality.

---

## Features

- **Widget tabs in the notch** for compact tools and quick interactions
- **Workshop browser** for discovering, pinning, and managing widgets
- **Shelf mode** for drag-and-drop temporary file holding and quick sharing
- **Media controls** for playback, artwork, progress, and music-focused interactions
- **Calendar integration** with inline and tab-based viewing modes
- **System monitor widgets** for live hardware and system status
- **Clipboard history widget** for quick paste workflows
- **Accessory battery widget** for connected device visibility
- **Color picker widget** built directly into the notch workflow
- **Timer widget** for lightweight time tracking
- **Custom OSD and live activity surfaces** for system feedback beyond the default macOS overlays
- **Webcam and sharing integrations** for richer utility-style interactions
- **Built-in updater support** with Sparkle and DMG packaging infrastructure

---

## Built with

- **SwiftUI** for the main app interface and settings experience
- **AppKit + native macOS APIs** for windowing, status behaviors, media hooks, and system interactions
- **Sparkle** for app update delivery
- **XPC helper services** for privileged or isolated macOS functionality
- **Custom DMG tooling** for distribution-ready macOS releases

---

## Requirements

- macOS 14 or later
- Xcode 26 or later for development

Some features may additionally rely on macOS permissions such as media access, calendar access, webcam access, or automation depending on which modules you use.

---

## Download

If you are publishing releases for the project, the repository already includes:

- **Sparkle appcast support** under `updater/appcast.xml`
- **DMG creation scripts** under `Configuration/dmg/`
- **Updater settings UI** inside the app

That means the project is structured to support polished downloadable `.dmg` releases instead of source-only distribution.

---

## Build from source

```bash
git clone https://github.com/nodescraper/boringnotch-se.git
cd boringnotch-se
open boringNotch.xcodeproj
```

Terminal build:

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -destination 'generic/platform=macOS' build
```

---

## Run in development

Run from Xcode with `Cmd + R`, or open the built app bundle from Derived Data after a successful build.

If an older instance is already running, relaunch the freshly built app explicitly:

```bash
pkill -x boringNotch
open -n .derivedData/Build/Products/Debug/boringNotch.app
```

To package a distributable DMG once the app has been built:

```bash
./Configuration/dmg/create_dmg.sh /path/to/boringNotch.app boringNotch.dmg "BoringNotch SE"
```

---

## Project layout

```text
boringNotch/
├── components/         # Notch UI, settings, OSD, shelf, onboarding, music, webcam
├── widgets/            # Widget engine, models, providers, UI, and workshop flows
├── managers/           # Calendar, webcam, audio capture, music, notch-space coordination
├── helpers/            # App utilities, media checks, AppleScript helpers, relaunch helpers
├── observers/          # Media, drag, and fullscreen observation logic
├── menu/               # Status/menu bar integration
└── XPCHelperClient/    # Client side communication for helper functionality

Configuration/dmg/
├── create_dmg.sh       # Release DMG wrapper
└── dmgbuild_settings.py

updater/
└── appcast.xml         # Sparkle update feed
```

---

## License

MIT
