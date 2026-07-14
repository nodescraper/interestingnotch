//
//  ColorPickerWidgetModel.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import AppKit
import Defaults
import SwiftUI

enum ColorPickerFormat: String, CaseIterable, Identifiable, Sendable {
    case hex = "Hex"
    case rgb = "RGB"
    case hsl = "HSL"

    var id: String { rawValue }
}

struct ColorPickerRGBComponents: Equatable, Hashable, Sendable {
    let red: Int
    let green: Int
    let blue: Int
}

struct ColorPickerHSLComponents: Equatable, Hashable, Sendable {
    let hue: Int
    let saturation: Int
    let lightness: Int
}

struct ColorPickerHSBAColor: Equatable, Hashable, Sendable {
    var hue: Double
    var saturation: Double
    var brightness: Double
    var alpha: Double

    init(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1) {
        self.hue = Self.clampUnit(hue)
        self.saturation = Self.clampUnit(saturation)
        self.brightness = Self.clampUnit(brightness)
        self.alpha = Self.clampUnit(alpha)
    }

    static let defaultAccent = ColorPickerHSBAColor(hue: 0.58, saturation: 0.62, brightness: 0.95, alpha: 1)

    var rgb: ColorPickerRGBComponents {
        let h = hue.truncatingRemainder(dividingBy: 1)
        let scaledHue = (h < 0 ? h + 1 : h) * 6
        let chroma = brightness * saturation
        let secondary = chroma * (1 - abs(scaledHue.truncatingRemainder(dividingBy: 2) - 1))
        let match = brightness - chroma

        let tuple: (Double, Double, Double)
        switch scaledHue {
        case 0..<1:
            tuple = (chroma, secondary, 0)
        case 1..<2:
            tuple = (secondary, chroma, 0)
        case 2..<3:
            tuple = (0, chroma, secondary)
        case 3..<4:
            tuple = (0, secondary, chroma)
        case 4..<5:
            tuple = (secondary, 0, chroma)
        default:
            tuple = (chroma, 0, secondary)
        }

        return ColorPickerRGBComponents(
            red: Self.clampByte((tuple.0 + match) * 255),
            green: Self.clampByte((tuple.1 + match) * 255),
            blue: Self.clampByte((tuple.2 + match) * 255)
        )
    }

    var hsl: ColorPickerHSLComponents {
        let rgb = self.rgb
        let red = Double(rgb.red) / 255
        let green = Double(rgb.green) / 255
        let blue = Double(rgb.blue) / 255

        let maxChannel = max(red, green, blue)
        let minChannel = min(red, green, blue)
        let delta = maxChannel - minChannel
        let lightness = (maxChannel + minChannel) / 2

        let hueValue: Double
        if delta == 0 {
            hueValue = 0
        } else if maxChannel == red {
            hueValue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxChannel == green {
            hueValue = ((blue - red) / delta) + 2
        } else {
            hueValue = ((red - green) / delta) + 4
        }

        let normalizedHue = delta == 0 ? 0 : ((hueValue * 60).rounded().truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let saturationValue = delta == 0 ? 0 : delta / (1 - abs((2 * lightness) - 1))

        return ColorPickerHSLComponents(
            hue: Int(normalizedHue.rounded()),
            saturation: Int((saturationValue * 100).rounded()),
            lightness: Int((lightness * 100).rounded())
        )
    }

    var hexString: String {
        let rgb = self.rgb
        return String(format: "#%02X%02X%02X", rgb.red, rgb.green, rgb.blue)
    }

    var serializedHistoryValue: String {
        let rgb = self.rgb
        let alphaByte = Self.clampByte(alpha * 255)
        return String(format: "#%02X%02X%02X%02X", rgb.red, rgb.green, rgb.blue, alphaByte)
    }

    var alphaPercent: Int {
        Int((alpha * 100).rounded())
    }

    var nsColor: NSColor {
        NSColor(
            calibratedHue: CGFloat(hue),
            saturation: CGFloat(saturation),
            brightness: CGFloat(brightness),
            alpha: CGFloat(alpha)
        )
    }

    var swiftUIColor: Color {
        Color(nsColor: nsColor)
    }

    var cssRGBString: String {
        let rgb = self.rgb
        if alpha >= 0.999 {
            return "rgb(\(rgb.red), \(rgb.green), \(rgb.blue))"
        }

        return "rgba(\(rgb.red), \(rgb.green), \(rgb.blue), \(Self.alphaString(alpha)))"
    }

    var cssHSLString: String {
        let hsl = self.hsl
        if alpha >= 0.999 {
            return "hsl(\(hsl.hue), \(hsl.saturation)%, \(hsl.lightness)%)"
        }

        return "hsla(\(hsl.hue), \(hsl.saturation)%, \(hsl.lightness)%, \(Self.alphaString(alpha)))"
    }

    static func from(nsColor: NSColor) -> ColorPickerHSBAColor? {
        guard let converted = nsColor.usingColorSpace(.deviceRGB) else { return nil }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        converted.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return ColorPickerHSBAColor(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(brightness),
            alpha: Double(alpha)
        )
    }

    static func fromHex(_ string: String) -> ColorPickerHSBAColor? {
        var sanitized = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }

        guard sanitized.count == 6 || sanitized.count == 8 else { return nil }
        guard let value = UInt64(sanitized, radix: 16) else { return nil }

        let red: Int
        let green: Int
        let blue: Int
        let alpha: Double

        if sanitized.count == 6 {
            red = Int((value >> 16) & 0xFF)
            green = Int((value >> 8) & 0xFF)
            blue = Int(value & 0xFF)
            alpha = 1
        } else {
            red = Int((value >> 24) & 0xFF)
            green = Int((value >> 16) & 0xFF)
            blue = Int((value >> 8) & 0xFF)
            alpha = Double(Int(value & 0xFF)) / 255
        }

        return from(rgb: .init(red: red, green: green, blue: blue), alpha: alpha)
    }

    static func from(
        rgb: ColorPickerRGBComponents,
        alpha: Double = 1
    ) -> ColorPickerHSBAColor? {
        guard (0...255).contains(rgb.red), (0...255).contains(rgb.green), (0...255).contains(rgb.blue) else {
            return nil
        }

        let red = Double(rgb.red) / 255
        let green = Double(rgb.green) / 255
        let blue = Double(rgb.blue) / 255

        let maxChannel = max(red, green, blue)
        let minChannel = min(red, green, blue)
        let delta = maxChannel - minChannel

        let hue: Double
        if delta == 0 {
            hue = 0
        } else if maxChannel == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) / 6
        } else if maxChannel == green {
            hue = (((blue - red) / delta) + 2) / 6
        } else {
            hue = (((red - green) / delta) + 4) / 6
        }

        let normalizedHue = hue < 0 ? hue + 1 : hue
        let saturation = maxChannel == 0 ? 0 : delta / maxChannel
        let brightness = maxChannel

        return ColorPickerHSBAColor(
            hue: normalizedHue,
            saturation: saturation,
            brightness: brightness,
            alpha: alpha
        )
    }

    static func from(
        hsl: ColorPickerHSLComponents,
        alpha: Double = 1
    ) -> ColorPickerHSBAColor? {
        guard (0...360).contains(hsl.hue), (0...100).contains(hsl.saturation), (0...100).contains(hsl.lightness) else {
            return nil
        }

        let hue = Double(hsl.hue) / 360
        let saturation = Double(hsl.saturation) / 100
        let lightness = Double(hsl.lightness) / 100

        let chroma = (1 - abs((2 * lightness) - 1)) * saturation
        let scaledHue = hue * 6
        let secondary = chroma * (1 - abs(scaledHue.truncatingRemainder(dividingBy: 2) - 1))
        let match = lightness - chroma / 2

        let tuple: (Double, Double, Double)
        switch scaledHue {
        case 0..<1:
            tuple = (chroma, secondary, 0)
        case 1..<2:
            tuple = (secondary, chroma, 0)
        case 2..<3:
            tuple = (0, chroma, secondary)
        case 3..<4:
            tuple = (0, secondary, chroma)
        case 4..<5:
            tuple = (secondary, 0, chroma)
        default:
            tuple = (chroma, 0, secondary)
        }

        return from(
            rgb: .init(
                red: clampByte((tuple.0 + match) * 255),
                green: clampByte((tuple.1 + match) * 255),
                blue: clampByte((tuple.2 + match) * 255)
            ),
            alpha: alpha
        )
    }

    private static func clampUnit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func clampByte(_ value: Double) -> Int {
        min(max(Int(value.rounded()), 0), 255)
    }

    private static func alphaString(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        if rounded == floor(rounded) {
            return String(Int(rounded))
        }
        return String(format: "%.3f", rounded).replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
    }
}

enum ColorPickerInteractionMath {
    static func saturationBrightness(at point: CGPoint, in size: CGSize) -> (saturation: Double, brightness: Double) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let clampedX = min(max(point.x, 0), width)
        let clampedY = min(max(point.y, 0), height)

        return (
            saturation: Double(clampedX / width),
            brightness: Double(1 - (clampedY / height))
        )
    }

    static func point(for color: ColorPickerHSBAColor, in size: CGSize) -> CGPoint {
        CGPoint(
            x: CGFloat(color.saturation) * size.width,
            y: CGFloat(1 - color.brightness) * size.height
        )
    }

    static func normalizedValue(at x: CGFloat, width: CGFloat) -> Double {
        let safeWidth = max(width, 1)
        return min(max(Double(x / safeWidth), 0), 1)
    }
}

enum ColorPickerHistoryStore {
    static let limit = 12

    static func push(
        _ color: ColorPickerHSBAColor,
        into history: [String],
        limit: Int = ColorPickerHistoryStore.limit
    ) -> [String] {
        let entry = color.serializedHistoryValue
        var updated = history.filter { $0.caseInsensitiveCompare(entry) != .orderedSame }
        updated.insert(entry, at: 0)
        return Array(updated.prefix(limit))
    }

    static func restore(_ entry: String) -> ColorPickerHSBAColor? {
        ColorPickerHSBAColor.fromHex(entry)
    }
}

@MainActor
protocol ColorStringCopying {
    func copy(_ string: String)
}

@MainActor
struct SystemColorStringCopying: ColorStringCopying {
    func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

@MainActor
protocol InteractiveWidgetRuntime: AnyObject {
    var interactiveKind: WidgetManifest.Interactive.Kind { get }
}

@MainActor
final class ColorPickerWidgetModel: ObservableObject, InteractiveWidgetRuntime {
    let interactiveKind: WidgetManifest.Interactive.Kind = .colorPicker
    let widgetID: String

    @Published private(set) var color: ColorPickerHSBAColor
    @Published var activeFormat: ColorPickerFormat
    @Published private(set) var recentHistory: [String]

    private let screenColorPicker: any ScreenColorPicking
    private let pasteboard: any ColorStringCopying

    init(
        widgetID: String,
        initialColor: ColorPickerHSBAColor = .defaultAccent,
        activeFormat: ColorPickerFormat = .hex,
        screenColorPicker: (any ScreenColorPicking)? = nil,
        pasteboard: (any ColorStringCopying)? = nil
    ) {
        self.widgetID = widgetID
        self.color = initialColor
        self.activeFormat = activeFormat
        self.recentHistory = Defaults[.colorPickerRecentHistory]
        self.screenColorPicker = screenColorPicker ?? ScreenColorPicker.shared
        self.pasteboard = pasteboard ?? SystemColorStringCopying()
    }

    var displayHex: String { color.hexString }
    var displayRGB: ColorPickerRGBComponents { color.rgb }
    var displayHSL: ColorPickerHSLComponents { color.hsl }
    var displayAlphaPercent: Int { color.alphaPercent }
    var previewString: String {
        switch activeFormat {
        case .hex:
            return color.alpha >= 0.999 ? color.hexString : color.serializedHistoryValue
        case .rgb:
            return color.cssRGBString
        case .hsl:
            return color.cssHSLString
        }
    }

    func updateSaturationBrightness(at point: CGPoint, in size: CGSize) {
        let values = ColorPickerInteractionMath.saturationBrightness(at: point, in: size)
        color = ColorPickerHSBAColor(
            hue: color.hue,
            saturation: values.saturation,
            brightness: values.brightness,
            alpha: color.alpha
        )
    }

    func updateHue(at x: CGFloat, width: CGFloat) {
        color = ColorPickerHSBAColor(
            hue: ColorPickerInteractionMath.normalizedValue(at: x, width: width),
            saturation: color.saturation,
            brightness: color.brightness,
            alpha: color.alpha
        )
    }

    func updateAlpha(at x: CGFloat, width: CGFloat) {
        color = ColorPickerHSBAColor(
            hue: color.hue,
            saturation: color.saturation,
            brightness: color.brightness,
            alpha: ColorPickerInteractionMath.normalizedValue(at: x, width: width)
        )
    }

    @discardableResult
    func updateFromHex(_ string: String) -> Bool {
        guard let parsed = ColorPickerHSBAColor.fromHex(string) else { return false }
        color = parsed
        return true
    }

    @discardableResult
    func updateFromRGB(red: String, green: String, blue: String, alpha: String) -> Bool {
        guard
            let redValue = Int(red),
            let greenValue = Int(green),
            let blueValue = Int(blue),
            let alphaValue = Int(alpha),
            (0...255).contains(redValue),
            (0...255).contains(greenValue),
            (0...255).contains(blueValue),
            (0...100).contains(alphaValue),
            let parsed = ColorPickerHSBAColor.from(
                rgb: .init(red: redValue, green: greenValue, blue: blueValue),
                alpha: Double(alphaValue) / 100
            )
        else {
            return false
        }

        color = parsed
        return true
    }

    @discardableResult
    func updateFromHSL(hue: String, saturation: String, lightness: String, alpha: String) -> Bool {
        guard
            let hueValue = Int(hue),
            let saturationValue = Int(saturation),
            let lightnessValue = Int(lightness),
            let alphaValue = Int(alpha),
            (0...360).contains(hueValue),
            (0...100).contains(saturationValue),
            (0...100).contains(lightnessValue),
            (0...100).contains(alphaValue),
            let parsed = ColorPickerHSBAColor.from(
                hsl: .init(hue: hueValue, saturation: saturationValue, lightness: lightnessValue),
                alpha: Double(alphaValue) / 100
            )
        else {
            return false
        }

        color = parsed
        return true
    }

    func restoreHistoryEntry(_ entry: String) {
        guard let restored = ColorPickerHistoryStore.restore(entry) else { return }
        color = restored
    }

    func applyPickedColor(_ pickedColor: ColorPickerHSBAColor, addToHistory: Bool = true) {
        color = pickedColor

        if addToHistory {
            pushCurrentColorToHistory()
        }
    }

    func copyCurrentColor() {
        pasteboard.copy(previewString)
        pushCurrentColorToHistory()
    }

    func pickScreenColor() async {
        guard let pickedColor = await screenColorPicker.pickColor(),
              let parsed = ColorPickerHSBAColor.from(nsColor: pickedColor) else {
            return
        }

        applyPickedColor(parsed)
    }

    private func pushCurrentColorToHistory() {
        recentHistory = ColorPickerHistoryStore.push(color, into: recentHistory)
        Defaults[.colorPickerRecentHistory] = recentHistory
    }
}
