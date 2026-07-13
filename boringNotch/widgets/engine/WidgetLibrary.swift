//
//  WidgetLibrary.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation

enum WidgetLibrary {
    static var bundledManifests: [WidgetManifest] {
        [colorPickerManifest, timerManifest]
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
}
