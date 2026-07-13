//
//  ScreenColorPicker.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import AppKit

@MainActor
protocol ScreenColorPicking {
    func pickColor() async -> NSColor?
}

@MainActor
final class ScreenColorPicker: ScreenColorPicking {
    static let shared = ScreenColorPicker()

    private init() {}

    func pickColor() async -> NSColor? {
        await withCheckedContinuation { continuation in
            NSColorSampler().show { color in
                continuation.resume(returning: color)
            }
        }
    }
}
