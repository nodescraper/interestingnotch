import Foundation
import SwiftUI

enum PeekSide: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case split
}

enum CustomPeekDisplayMode: String, Codable, CaseIterable, Identifiable {
    case persistent
    case popUp

    var id: Self { self }

    var title: String {
        switch self {
        case .persistent: "Persistent"
        case .popUp: "Pop up"
        }
    }
}

struct CustomPeekPreference: Codable, Equatable {
    var isEnabled = true
    var displayMode: CustomPeekDisplayMode = .persistent
    var popUpDuration: TimeInterval = 4
}

@MainActor
final class CustomPeekPreferences: ObservableObject {
    static let shared = CustomPeekPreferences()

    @Published private(set) var values: [String: CustomPeekPreference] = [:]
    private let key = "customWidgetsPeekPreferences"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: CustomPeekPreference].self, from: data)
        else { return }
        values = decoded
    }

    func preference(for id: String) -> CustomPeekPreference {
        values[id] ?? CustomPeekPreference()
    }

    func preference(for peek: CustomPeek) -> CustomPeekPreference {
        values[peek.id] ?? CustomPeekPreference(
            displayMode: peek.defaultDisplayMode ?? .persistent,
            popUpDuration: peek.defaultPopUpDuration ?? 4
        )
    }

    func update(_ preference: CustomPeekPreference, for id: String) {
        values[id] = preference
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: key)
        }
        CustomPeekWatcher.shared.preferencesDidChange()
    }
}

struct CustomPeek: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String?
    let icon: String?
    let accent: Color
    let side: PeekSide
    let duration: TimeInterval?
    let defaultDisplayMode: CustomPeekDisplayMode?
    let defaultPopUpDuration: TimeInterval?

    init(id: String, title: String, message: String?, icon: String?, accent: Color,
         side: PeekSide, duration: TimeInterval?,
         defaultDisplayMode: CustomPeekDisplayMode? = nil,
         defaultPopUpDuration: TimeInterval? = nil) {
        self.id = id
        self.title = title
        self.message = message
        self.icon = icon
        self.accent = accent
        self.side = side
        self.duration = duration
        self.defaultDisplayMode = defaultDisplayMode
        self.defaultPopUpDuration = defaultPopUpDuration
    }

    static func parse(data: Data, id: String) throws -> CustomPeek {
        let raw: Raw
        do { raw = try JSONDecoder().decode(Raw.self, from: data) }
        catch { throw ParseError.invalidJSON }
        let title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { throw ParseError.missingTitle }
        if let duration = raw.duration, duration <= 0 { throw ParseError.invalidDuration }
        if let duration = raw.popUpDuration, duration <= 0 { throw ParseError.invalidPopUpDuration }
        if let side = raw.side, PeekSide(rawValue: side) == nil { throw ParseError.invalidSide }
        if let display = raw.display, CustomPeekDisplayMode(jsonValue: display) == nil {
            throw ParseError.invalidDisplay
        }
        if let accent = raw.accent, Color(hex: accent) == nil { throw ParseError.invalidAccent }

        return CustomPeek(
            id: id,
            title: title,
            message: raw.message?.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: raw.icon,
            accent: raw.accent.flatMap(Color.init(hex:)) ?? .effectiveAccent,
            side: raw.side.flatMap(PeekSide.init(rawValue:)) ?? .split,
            duration: raw.duration,
            defaultDisplayMode: raw.display.flatMap(CustomPeekDisplayMode.init(jsonValue:)),
            defaultPopUpDuration: raw.popUpDuration
        )
    }

    enum ParseError: LocalizedError {
        case invalidJSON
        case missingTitle
        case invalidDuration
        case invalidPopUpDuration
        case invalidSide
        case invalidDisplay
        case invalidAccent

        var errorDescription: String? {
            switch self {
            case .invalidJSON: "Invalid JSON."
            case .missingTitle: "The title field is required."
            case .invalidDuration: "Duration must be greater than zero."
            case .invalidPopUpDuration: "Pop-up duration must be greater than zero."
            case .invalidSide: "Side must be left, right, or split."
            case .invalidDisplay: "Display must be persistent, popUp, or popup."
            case .invalidAccent: "Accent must be a 6- or 8-digit hex color."
            }
        }
    }

    private struct Raw: Decodable {
        let title: String?
        let message: String?
        let icon: String?
        let accent: String?
        let side: String?
        let duration: TimeInterval?
        let display: String?
        let popUpDuration: TimeInterval?
    }
}

private extension CustomPeekDisplayMode {
    init?(jsonValue: String) {
        switch jsonValue.lowercased() {
        case "persistent": self = .persistent
        case "popup": self = .popUp
        default: return nil
        }
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8,
              let number = UInt64(value, radix: 16) else { return nil }
        let divisor = 255.0
        let red = Double((number >> (value.count == 8 ? 24 : 16)) & 0xff) / divisor
        let green = Double((number >> (value.count == 8 ? 16 : 8)) & 0xff) / divisor
        let blue = Double((number >> (value.count == 8 ? 8 : 0)) & 0xff) / divisor
        let alpha = value.count == 8 ? Double(number & 0xff) / divisor : 1
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
