//
//  WidgetLibrary.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation

enum WidgetLibrary {
    static var bundledManifests: [WidgetManifest] {
        [colorPickerManifest, timerManifest, clipboardHistoryManifest, systemMonitorManifest]
    }

    static func seedBundledManifestsIfNeeded(
        into directoryURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        for manifest in bundledManifests {
            let fileURL = directoryURL.appendingPathComponent("\(manifest.id).notchwidget.json")
            guard !fileManager.fileExists(atPath: fileURL.path) else { continue }

            let data = try encoder.encode(manifest)
            try data.write(to: fileURL, options: .atomic)
        }
    }

    private static var colorPickerManifest: WidgetManifest {
        WidgetManifest(
            schema: 1,
            kind: .interactive,
            id: "color-picker",
            name: "Color Picker",
            author: "NodeScraper",
            source: nil,
            extract: nil,
            render: .init(
                template: .iconLabel,
                slots: [
                    "icon": .string("eyedropper.halffull"),
                    "label": .string("Pick colors"),
                    "color": .string("accent"),
                ]
            ),
            onTap: nil,
            permissions: ["screen-color-pick", "clipboard"],
            interactive: .init(type: .colorPicker)
        )
    }

    private static var timerManifest: WidgetManifest {
        WidgetManifest(
            schema: 1,
            kind: .interactive,
            id: "timer",
            name: "Timer",
            author: "NodeScraper",
            source: nil,
            extract: nil,
            render: .init(
                template: .iconLabel,
                slots: [
                    "icon": .string("timer"),
                    "label": .string("Countdown timer"),
                    "color": .string("accent"),
                ]
            ),
            onTap: nil,
            permissions: nil,
            interactive: .init(type: .timer)
        )
    }

    private static var clipboardHistoryManifest: WidgetManifest {
        WidgetManifest(
            schema: 1,
            kind: .interactive,
            id: "clipboard-history",
            name: "Clipboard History",
            author: "NodeScraper",
            source: nil,
            extract: nil,
            render: .init(
                template: .iconLabel,
                slots: [
                    "icon": .string("document.on.clipboard"),
                    "label": .string("Recent clips"),
                    "color": .string("accent"),
                ]
            ),
            onTap: nil,
            permissions: ["clipboard"],
            interactive: .init(type: .clipboardHistory)
        )
    }

    private static var systemMonitorManifest: WidgetManifest {
        WidgetManifest(
            schema: 1,
            kind: .data,
            id: "system-monitor",
            name: "System Monitor",
            author: "NodeScraper",
            source: .init(
                type: .framework,
                run: nil,
                url: nil,
                method: nil,
                headers: nil,
                api: "system-monitor",
                interval: 3,
                timeout: nil,
                cwd: nil,
                env: nil
            ),
            extract: .init(
                method: .jsonPath,
                pattern: nil,
                path: "$",
                table: nil
            ),
            render: .init(
                template: .text,
                slots: [
                    "icon": .string("cpu"),
                    "label": .string("System Monitor"),
                    "color": .string("accent"),
                ]
            ),
            onTap: nil,
            permissions: nil,
            interactive: nil
        )
    }
}
