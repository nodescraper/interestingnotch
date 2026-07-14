# BoringNotch SE

`BoringNotch SE` is a macOS notch utility by `NodeScraper`.

It turns the notch into a customizable surface for media, widgets, shelf tools, calendar access, system controls, and compact live activities.

## Highlights

- dynamic widget tabs inside the notch
- Workshop library for browsing and pinning widgets
- built-in color picker widget
- built-in timer widget
- built-in system monitor widget
- built-in clipboard history widget
- built-in accessory battery widget
- optional calendar tab mode in addition to inline calendar
- media controls, shelf, calendar, and OSD utilities

## Requirements

- macOS 14 or later
- Xcode 26 or later for development

## Build From Source

```bash
git clone https://github.com/nodescraper/boringnotch-se.git
cd boringnotch-se
open boringNotch.xcodeproj
```

Terminal build:

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -destination 'generic/platform=macOS' build
```

## Run

Run from Xcode with `Cmd + R`, or open the built app bundle from the derived data path used during your build.

If a previous `boringNotch` instance is already running, relaunch the freshly built app explicitly:

```bash
pkill -x boringNotch
open -n .derivedData/Build/Products/Debug/boringNotch.app
```

## Project

- App name: `BoringNotch SE`
- Maintainer: `NodeScraper`
- Platform: macOS

## Credits

BoringNotch SE stands on top of a lot of excellent open-source work, including the original notch-app ideas that helped shape this space.
