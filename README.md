<h1 align="center">
  <br>
  <a href="https://github.com/nodescraper/boringnotch-se"><img src="https://framerusercontent.com/images/RFK4vs0kn8pRMuOO58JeyoemXA.png?scale-down-to=256" alt="BoringNotch SE" width="150"></a>
  <br>
  BoringNotch SE
  <br>
</h1>

<p align="center">
  A major fork of <a href="https://github.com/TheBoredTeam/boring.notch">TheBoredTeam/boring.notch</a>, maintained by <a href="https://github.com/nodescraper">nodescraper</a> and focused on expanding the notch into a richer widget surface.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-111827?logo=apple&logoColor=white" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-SwiftUI-F97316?logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/fork-major%20product%20fork-0F766E" alt="Major fork" />
  <img src="https://img.shields.io/badge/widgets-expanded-1D4ED8" alt="Expanded widgets" />
  <img src="https://img.shields.io/badge/license-MIT-334155" alt="MIT License" />
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/2d5f69c1-6e7b-4bc2-a6f1-bb9e27cf88a8" alt="BoringNotch demo" />
</p>

---

## BoringNotch SE

**BoringNotch SE** is the nodescraper-maintained release fork of the original **Boring Notch** project by **TheBoredTeam**.

The first stable SE release is **v2.8.0**. It brings the expanded widget system, Workshop flow, and the SE onboarding and navigation work together in one release line.

This repo keeps the spirit of the original app, but pushes much harder on the notch-as-a-widget-platform idea: dynamic widget tabs, a bundled widget library, a Workshop flow, and several new built-in utilities that make the notch feel more like a real desktop surface than a single-purpose overlay.

If you are looking for the original project, go here:

- [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch)

If you want the fork with the expanded widget work and SE-specific changes, you are in the right place.

Release downloads are published on the [BoringNotch SE releases page](https://github.com/nodescraper/boringnotch-se/releases).

---

## Release 0.1

The first BoringNotch SE release packages the widget-platform foundation and the current notch UI work:

- widget library, manifests, pinning, and Workshop browsing
- Timer, Clipboard History, System Monitor, Accessory Battery, Color Picker, and Calendar widgets
- full-tab calendar experience with calendar data/model support
- improved tab transitions and compact timer/music notch states
- refined notch, shelf, onboarding, settings, and widget-page behavior

This release is focused on establishing the SE architecture and making the expanded widget workflow usable as a daily desktop surface.

---

## What This Fork Adds

This is not just a rename or packaging fork. The SE branch adds substantial product and engineering work on top of upstream, including:

- **Dynamic widget-tab navigation** so the notch can host multiple utility surfaces cleanly
- **Workshop browsing and pinning** to install, manage, and surface widgets inside the notch
- **Bundled widget manifests and seeding** for built-in utilities
- **Timer widget** for quick countdown workflows
- **Clipboard history widget** for recent copy/paste access
- **System monitor widget** for live CPU and system-state visibility
- **Accessory battery widget** for connected-device battery reporting
- **Color picker widget polish** with a more focused interaction model
- **Paged tab behavior** for handling multiple pinned widgets without collapsing the UI
- **Onboarding, settings, calendar, and notch-flow changes** to support the new widget model
- **Widget extraction and rendering test coverage** expanded alongside the new functionality

In short: the original project made the notch fun. This fork pushes it toward a more modular and extensible productivity surface.

---

## SE Feature Highlights

### Widget-first notch workflow

The biggest shift in BoringNotch SE is that the notch is no longer just a media or shelf surface. It becomes a compact host for multiple pinned tools that you can swap between directly from the notch UI.

### Built-in widgets included in this fork

- **Color Picker**
- **Timer**
- **Clipboard History**
- **System Monitor**
- **Accessory Battery**

### Workshop flow

SE introduces a **Workshop** experience for browsing and pinning widgets, making the widget system feel like a real feature rather than a hardcoded experiment.

### Better notch navigation

Once multiple widgets are pinned, SE uses paging-aware notch tabs so the interface stays usable instead of turning into a cramped strip of icons.

---

## Upstream Features Preserved

BoringNotch SE builds on top of the original project's strong base, including:

- music controls and visualizer
- calendar integration
- shelf functionality
- webcam and mirror-style utilities
- system HUD replacements
- menu bar settings and onboarding flows

The goal here is not to erase upstream. It is to extend it.

---

## Why This Fork Exists

The original project already had a strong personality and a fun UX direction. This fork exists to explore what happens when the notch becomes more composable, more widget-driven, and more useful day to day.

That means the emphasis here is on:

- more utility packed into the notch
- cleaner switching between notch surfaces
- more built-in tools
- a stronger foundation for future widget-like expansion

---

## Building From Source

### Requirements

- macOS **14 Sonoma** or later
- **Xcode 26** or later

### Clone

```bash
git clone https://github.com/nodescraper/boringnotch-se.git
cd boringnotch-se
```

### Open in Xcode

```bash
open boringNotch.xcodeproj
```

### Build from Terminal

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -destination 'generic/platform=macOS' build
```

### Release build

The stable release line is maintained on `main`. The `dev` branch is used for ongoing work before it is promoted into a release.

```bash
git checkout main
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release -destination 'generic/platform=macOS' build
```

### Run a fresh development build

```bash
pkill -x boringNotch
open -n .derivedData/Build/Products/Debug/boringNotch.app
```

---

## Project Areas Touched By SE

The fork meaningfully expands work across the app, especially in:

- `boringNotch/widgets/engine/`
- `boringNotch/widgets/model/`
- `boringNotch/widgets/ui/`
- `boringNotch/widgets/ui/workshop/`
- `boringNotch/components/Tabs/`
- `boringNotch/components/Onboarding/`
- `boringNotch/components/Calendar/`
- `boringNotch/components/Notch/`
- `boringNotchTests/`

These changes are where most of the fork's added widget functionality, UI behavior, and integration work live.

---

## Credits

### Fork maintainer

**nodescraper** maintains BoringNotch SE and the expanded widget release line.

### Original project

Huge credit to **TheBoredTeam** for the original **Boring Notch** project and the foundation this fork builds on.

- [Original repository](https://github.com/TheBoredTeam/boring.notch)

### Notable upstream/open-source acknowledgments

- **[MediaRemoteAdapter](https://github.com/ungive/mediaremote-adapter)** for enabling modern macOS now-playing integration
- **[NotchDrop](https://github.com/Lakr233/NotchDrop)** for ideas that helped shape early shelf functionality

For the full attribution set, see [THIRD_PARTY_LICENSES](./THIRD_PARTY_LICENSES).

---

## License

MIT
