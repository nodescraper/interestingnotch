<!-- ─────────────────────────── HERO ─────────────────────────── -->
<div align="center">

# InterestingNotch

### The notch, reimagined.

A powerful, extensible take on the Mac notch — built on the foundation of boring.notch, then pushed far beyond it with its own widgets, a pinnable widget library, Bluetooth accessory battery, a built-in caffeine tool, and a custom-widget system you can script yourself.

![macOS](https://img.shields.io/badge/macOS-notch-111827?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white)
![Local first](https://img.shields.io/badge/local%20first-no%20cloud-0F766E)
![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-334155)

</div>

<!-- ─────────────────────────── DEMO ─────────────────────────── -->
<div align="center">

https://github.com/user-attachments/assets/2d5f69c1-6e7b-4bc2-a6f1-bb9e27cf88a8

</div>

> [!NOTE]
> InterestingNotch is a heavily extended fork built for people who want the notch to actually *do* things — glanceable widgets, quick controls, and a way to wire in your own status without waiting for a feature request.

---

## Contents

- [What it is](#what-it-is)
- [Highlights](#highlights)
- [Widgets](#widgets)
- [Custom widgets](#custom-widgets-beta)
- [Caffeine](#caffeine)
- [Bluetooth accessory battery](#bluetooth-accessory-battery)
- [Widget library](#widget-library)
- [Getting started](#getting-started)
- [Credits](#credits)
- [License](#license)

---

## What it is

InterestingNotch turns the empty space around the Mac notch into a compact, glanceable surface for the things you check constantly — and the things you build yourself.

It keeps everything the original boring.notch does well — media live activity, gestures, HUD replacement, the shelf, multi-display support — and layers on a redesigned settings experience, a proper widget library with pinning, a family of native widgets, first-party quick controls, and an open custom-widget system that any script can push to.

Everything runs locally. No cloud, no account.

---

## Highlights

- **A real widget family** — timer, stopwatch, system monitor, color picker, clipboard history, calendar, voice recorder, accessory battery.
- **Pinnable widget library** — browse widgets and pin the ones you want as notch tabs.
- **Custom widgets** — let your own scripts push sneak peeks to the notch with a single JSON file.
- **Built-in caffeine** — keep your Mac awake with a tap or a hotkey, no separate app.
- **Bluetooth accessory battery** — AirPods and Magic accessories, right in the notch.
- **Redesigned settings** — a cleaner, organized settings layout and a dedicated widget library view.
- **Local-first** — no network required for anything core.

---

## Widgets

A consistent, Apple-like family of widgets designed for the notch — quiet, glanceable, and interactive.

| Widget | What it does |
|---|---|
| **Timer / Stopwatch** | A scrubbable ruler to set a countdown, live closed-notch glance, haptic detents, and a stopwatch mode. |
| **System Monitor** | Live CPU, RAM, disk, and network ring gauges that shift color with load. |
| **Color Picker** | Pick any color on screen, copy HEX/RGB/HSL, and keep a quick recent history. |
| **Clipboard History** | Recent text, links, and images as scrollable cards — recopy or pin with one click. |
| **Calendar** | A compact month grid plus an agenda of events and reminders; tap to open in Calendar or Reminders. |
| **Voice Recorder** | Capture quick voice notes with a live waveform, elapsed time, and instant reveal of the saved file. |
| **Accessory Battery** | Battery for AirPods and Magic accessories, shown natively. |

Any widget can be **pinned** from the library to become its own notch tab.

---

## Custom widgets (beta)

The most powerful part: you can push your own content to the notch without touching the app.

InterestingNotch watches a folder and turns any JSON file dropped into it into a sneak peek. It's event-driven — the app stays asleep until a file changes — so it costs effectively nothing while idle.

**Write a peek from anything** — bash, Python, a Shortcut, a cron job:

```bash
echo '{"title":"X1C","message":"78%","icon":"printer.fill","side":"split"}' \
  > ~/.interestingnotch/peeks/bambu.json
```

**The schema** (only `title` is required):

| Field | Description |
|---|---|
| `title` | Required. The main line. |
| `message` | Optional secondary line / value. |
| `icon` | Optional SF Symbol name. |
| `accent` | Optional hex color. |
| `side` | `left`, `right`, or `split` — where it sits around the notch. |
| `duration` | Optional seconds. Omit to keep it until the file is removed. |

Overwrite the same file to update a peek in place (great for live progress), delete it to clear it. Timing is entirely up to your script — the peek appears the moment the file is written.

The **Custom Widgets** panel shows live status, the folder path, and per-file errors so you can debug your scripts.

> Pairs perfectly with tools like [Bambuddy Tray](https://github.com/bcsutar/BambuddyTray) — your printer app can push print progress and a "ready!" alert straight to the notch.

---

## Caffeine

A built-in keep-awake, no extra menu-bar app required.

- Toggle from the notch header or a **global keyboard shortcut**.
- Choose display-awake (screen stays on) or system-awake (Mac stays up, screen can sleep).
- Timed modes (15m / 1h / 2h / until off) with a sneak peek when it ends.
- Always-visible state so it never drains your battery silently.

Built on native macOS power assertions — clean, revocable, no shell-outs.

---

## Bluetooth accessory battery

See battery levels for supported Bluetooth accessories — AirPods and Apple Magic devices — directly in the notch, with per-device cards and charging indicators.

> Battery reporting depends on what macOS exposes to apps. Apple and Magic accessories report their level; most generic third-party devices do not expose battery to any app-accessible API, so they may show as connected without a percentage.

---

## Widget library

A dedicated library for managing what's in your notch:

- **Browse** every available widget with a description.
- **Pin / Unpin** to add or remove a widget as a notch tab.
- **Installed** view for what's currently active.
- **Built-in widgets** (Mirror, Shelf, Calendar, Media) alongside the widget family.
- **Custom Widgets (beta)** to enable and monitor script-driven peeks.

The settings experience has been reorganized around this library, so adding and arranging notch content is fast and obvious.

---

## Getting started

```bash
git clone https://github.com/nodescraper/interestingnotch.git
cd interestingnotch
open InterestingNotch.xcodeproj
```

Build and run in Xcode. On first launch, grant the permissions the features you use require.

---

## Credits

Built on the foundation of [boring.notch](https://github.com/TheBoredTeam/boring.notch) by The Bored Team. InterestingNotch is a public fork that preserves upstream attribution and extends it with its own widget family, widget library, custom-widget system, caffeine, accessory battery, and a redesigned settings layout.

---

## License

This repository currently carries the upstream **GNU GPL v3.0** license.
