# BoringNotch SE

`BoringNotch SE` is a personal fork of `boring.notch`, maintained by `NodeScraper`.

This fork keeps the original notch app idea and extends it with a first-party widget system, including:

- dynamic widget tabs in the notch
- a widget workshop/library
- a color picker widget
- a timer widget
- a system monitor widget

## Requirements

- macOS 14 or later
- Xcode 26 or later for development

## Build From Source

```bash
git clone https://github.com/NodeScraper/BoringNotch-SE.git
cd BoringNotch-SE
open boringNotch.xcodeproj
```

Or build from Terminal:

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -destination 'generic/platform=macOS' build
```

## Run

From Xcode, select the `boringNotch` scheme and press `Cmd + R`.

If you already built from Terminal, you can launch the app bundle directly from the derived data location you used for the build.

## Fork Notes

- App name: `BoringNotch SE`
- Maintainer: `NodeScraper`
- This fork is separate from the upstream `TheBoredTeam/boring.notch` project

## Credits

This project builds on the excellent original work from the `boring.notch` contributors and the open-source projects it depends on.
