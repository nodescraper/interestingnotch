//
//  ColorToken.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import AppKit
import SwiftUI

enum ColorToken: Hashable, Sendable {
    case accent
    case good
    case warn
    case bad
    case neutral
    case muted
    case hex(String)

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "accent":
            self = .accent
        case "good":
            self = .good
        case "warn":
            self = .warn
        case "bad":
            self = .bad
        case "neutral":
            self = .neutral
        case "muted":
            self = .muted
        default:
            self = .hex(rawValue)
        }
    }

    func resolve() -> Color {
        switch self {
        case .accent:
            return .effectiveAccent
        case .good:
            return Color(nsColor: .systemGreen)
        case .warn:
            return Color(nsColor: .systemOrange)
        case .bad:
            return Color(nsColor: .systemRed)
        case .neutral:
            return Color(nsColor: .secondaryLabelColor)
        case .muted:
            return Color(nsColor: .tertiaryLabelColor)
        case .hex(let value):
            return Self.color(from: value) ?? .effectiveAccent
        }
    }

    private static func color(from hex: String) -> Color? {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sanitized.hasPrefix("#") else { return nil }
        sanitized.removeFirst()

        guard sanitized.count == 6, let rgb = Int(sanitized, radix: 16) else {
            return nil
        }

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        return Color(red: red, green: green, blue: blue)
    }
}

extension ColorToken: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = ColorToken(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private var rawValue: String {
        switch self {
        case .accent:
            return "accent"
        case .good:
            return "good"
        case .warn:
            return "warn"
        case .bad:
            return "bad"
        case .neutral:
            return "neutral"
        case .muted:
            return "muted"
        case .hex(let value):
            return value
        }
    }
}
