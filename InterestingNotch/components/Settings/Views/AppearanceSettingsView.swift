//
//  AppearanceSettingsView.swift
//  InterestingNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import Defaults
import SwiftUI

struct Appearance: View {
    @ObservedObject var coordinator = InterestingViewCoordinator.shared
    @Default(.sliderColor) var sliderColor
    @Default(.useCustomAccentColor) private var useCustomAccentColor
    @Default(.customAccentColorData) private var customAccentColorData

    let icons: [String] = ["logo2"]
    @State private var selectedIcon: String = "logo2"
    @State private var customAccentColor: Color = .accentColor
    @State private var selectedPresetColor: PresetAccentColor?

    private var realtimeAudioWaveformSupported: Bool {
        if #available(macOS 14.2, *) {
            return true
        }
        return false
    }

    var body: some View {
        Form {
            accentColorSection

            Section {
                Toggle("Always show tabs", isOn: $coordinator.alwaysShowTabs)
                Defaults.Toggle(key: .settingsIconInNotch) {
                    Text("Show settings icon in notch")
                }

            } header: {
                Text("General")
            }

            Section {
                Defaults.Toggle(key: .coloredSpectrogram) {
                    Text("Colored spectrogram")
                }
                Defaults.Toggle(key: .realtimeAudioWaveform) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Real-time audio waveform")
                        Group {
                            if realtimeAudioWaveformSupported {
                                Text("Uses Accelerate FFT on the playing app's audio. Requires audio capture permission and uses slightly more CPU.")
                            } else {
                                Text("Requires macOS 14.2 or later. Update macOS to enable real-time audio waveform.")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .disabled(!realtimeAudioWaveformSupported)
                Defaults.Toggle(key: .playerColorTinting) {
                    Text("Player tinting")
                }
                Defaults.Toggle(key: .lightingEffect) {
                    Text("Enable blur effect behind album art")
                }
                Picker("Slider color", selection: $sliderColor) {
                    ForEach(SliderColorEnum.allCases, id: \.self) { option in
                        Text(option.localizedString)
                    }
                }
            } header: {
                Text("Media")
            }
            Section {
                Defaults.Toggle(key: .showNotHumanFace) {
                    Text("Show cool face animation while inactive")
                }
            } header: {
                HStack {
                    Text("Additional features")
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Appearance")
        .onAppear {
            initializeAccentColorState()
        }
    }

    private var accentColorSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Accent color", selection: $useCustomAccentColor) {
                    Text("System").tag(false)
                    Text("Custom").tag(true)
                }
                .pickerStyle(.segmented)

                if !useCustomAccentColor {
                    HStack(spacing: 12) {
                        AccentCircleButton(isSelected: true, color: .accentColor, isSystemDefault: true) {}
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Using System Accent")
                            Text("Your macOS system accent color")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color Presets")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            ForEach(PresetAccentColor.allCases) { preset in
                                AccentCircleButton(
                                    isSelected: selectedPresetColor == preset,
                                    color: preset.color
                                ) {
                                    selectedPresetColor = preset
                                    customAccentColor = preset.color
                                    saveCustomColor(preset.color)
                                }
                            }
                            Spacer()
                        }

                        Divider()
                            .padding(.vertical, 4)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pick a Color")
                                Text("Choose any color")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            ColorPicker(selection: Binding(
                                get: { customAccentColor },
                                set: { newColor in
                                    customAccentColor = newColor
                                    selectedPresetColor = nil
                                    saveCustomColor(newColor)
                                }
                            ), supportsOpacity: false) {
                                ZStack {
                                    Circle()
                                        .fill(customAccentColor)
                                        .frame(width: 32, height: 32)
                                    if selectedPresetColor == nil {
                                        Circle()
                                            .strokeBorder(.primary.opacity(0.3), lineWidth: 2)
                                            .frame(width: 32, height: 32)
                                    }
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Accent color")
        } footer: {
            Text("Choose between your system accent color or customize it with your own selection.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private func saveCustomColor(_ color: Color) {
        let nsColor = NSColor(color)
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false) {
            Defaults[.customAccentColorData] = colorData
            NotificationCenter.default.post(name: .accentColorChanged, object: nil)
        }
    }

    private func initializeAccentColorState() {
        guard useCustomAccentColor,
              let colorData = Defaults[.customAccentColorData],
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData)
        else {
            selectedPresetColor = nil
            return
        }

        customAccentColor = Color(nsColor: nsColor)
        selectedPresetColor = PresetAccentColor.allCases.first {
            let lhs = nsColor.usingColorSpace(.sRGB) ?? nsColor
            let rhs = NSColor($0.color).usingColorSpace(.sRGB) ?? NSColor($0.color)
            return abs(lhs.redComponent - rhs.redComponent) < 0.01
                && abs(lhs.greenComponent - rhs.greenComponent) < 0.01
                && abs(lhs.blueComponent - rhs.blueComponent) < 0.01
        }
    }
}

enum PresetAccentColor: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case graphite = "Graphite"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return Color(red: 0.0, green: 0.478, blue: 1.0)
        case .purple: return Color(red: 0.686, green: 0.322, blue: 0.871)
        case .pink: return Color(red: 1.0, green: 0.176, blue: 0.333)
        case .red: return Color(red: 1.0, green: 0.271, blue: 0.227)
        case .orange: return Color(red: 0.96, green: 0.58, blue: 0.24)
        case .yellow: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case .green: return Color(red: 0.4, green: 0.824, blue: 0.176)
        case .graphite: return Color(red: 0.557, green: 0.557, blue: 0.576)
        }
    }
}

struct AccentCircleButton: View {
    let isSelected: Bool
    let color: Color
    var isSystemDefault: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color).frame(width: 32, height: 32)
                Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1).frame(width: 32, height: 32)
                if isSelected {
                    Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 2).frame(width: 28, height: 28)
                }
            }
        }
        .buttonStyle(.plain)
        .help(isSystemDefault ? "Use your macOS system accent color" : "")
    }
}
