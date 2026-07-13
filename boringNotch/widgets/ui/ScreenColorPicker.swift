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

    private var activeSampler: NSColorSampler?

    private init() {}

    func pickColor() async -> NSColor? {
        await withCheckedContinuation { continuation in
            let sampler = NSColorSampler()
            activeSampler = sampler
            sampler.show { [weak self] color in
                self?.activeSampler = nil
                continuation.resume(returning: color)
            }
        }
    }
}
