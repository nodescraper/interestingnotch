//
//  ColorPickerWidgetPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import AppKit
import SwiftUI

struct ColorPickerWidgetPageView: View {
    let widget: Widget

    @ObservedObject var model: ColorPickerWidgetModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            HStack(alignment: .top, spacing: 16) {
                controlsPanel
                valuesPanel
            }

            historyPanel
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(widget.resolvedColor.opacity(0.18))
                .frame(width: 54, height: 54)
                .overlay {
                    Image(systemName: "eyedropper.halffull")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(widget.resolvedColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(widget.manifest.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(model.previewString)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            actionButton(title: "Eyedropper", systemImage: "scope") {
                Task {
                    await model.pickScreenColor()
                }
            }

            actionButton(title: "Copy", systemImage: "doc.on.doc") {
                model.copyCurrentColor()
            }
        }
    }

    private var controlsPanel: some View {
        cardPanel {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    SaturationBrightnessSquare(color: model.color) { point, size in
                        model.updateSaturationBrightness(at: point, in: size)
                    }

                    HueSlider(color: model.color) { locationX, width in
                        model.updateHue(at: locationX, width: width)
                    }

                    AlphaSlider(color: model.color) { locationX, width in
                        model.updateAlpha(at: locationX, width: width)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    previewSwatch

                    HStack(spacing: 10) {
                        formatTabBar
                        Spacer(minLength: 0)
                    }

                    ColorPickerValueFields(model: model)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var valuesPanel: some View {
        VStack(spacing: 16) {
            cardPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Preview")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.black.opacity(0.16))
                        .overlay {
                            CheckerboardBackground()
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(model.color.swiftUIColor)
                        }
                        .frame(height: 120)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.previewString)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Alpha \(model.displayAlphaPercent)%")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            cardPanel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Live Values")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    MetricRow(label: "HEX", value: model.color.alpha >= 0.999 ? model.displayHex : model.color.serializedHistoryValue)
                    MetricRow(label: "RGB", value: model.color.cssRGBString)
                    MetricRow(label: "HSL", value: model.color.cssHSLString)
                }
            }
        }
        .frame(width: 220)
    }

    private var historyPanel: some View {
        cardPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Picks")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer(minLength: 0)

                    Text("\(model.recentHistory.count)/\(ColorPickerHistoryStore.limit)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if model.recentHistory.isEmpty {
                    Text("Copied colors and eyedropper picks show up here.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        ForEach(model.recentHistory, id: \.self) { entry in
                            Button {
                                model.restoreHistoryEntry(entry)
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.white.opacity(0.04))
                                        .overlay {
                                            CheckerboardBackground()
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }

                                    if let restored = ColorPickerHistoryStore.restore(entry) {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(restored.swiftUIColor)
                                    }
                                }
                                .frame(width: 42, height: 42)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .help(entry)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var previewSwatch: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.black.opacity(0.18))
            .overlay {
                CheckerboardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(model.color.swiftUIColor)
            }
            .frame(height: 78)
            .overlay(alignment: .bottomLeading) {
                Text(model.previewString)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(10)
            }
    }

    private var formatTabBar: some View {
        HStack(spacing: 8) {
            ForEach(ColorPickerFormat.allCases) { format in
                Button {
                    model.activeFormat = format
                } label: {
                    Text(format.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(model.activeFormat == format ? .black : .white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(model.activeFormat == format ? widget.resolvedColor : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cardPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            }
            .overlay {
                content()
                    .padding(16)
            }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }
}

private struct SaturationBrightnessSquare: View {
    let color: ColorPickerHSBAColor
    let onChange: (CGPoint, CGSize) -> Void

    var body: some View {
        GeometryReader { geometry in
            let indicator = ColorPickerInteractionMath.point(for: color, in: geometry.size)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hue: color.hue, saturation: 1, brightness: 1))
                .overlay {
                    LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing)
                }
                .overlay {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                }
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.95), lineWidth: 2)
                        .background(Circle().fill(.clear))
                        .shadow(color: .black.opacity(0.35), radius: 4)
                        .frame(width: 18, height: 18)
                        .position(
                            x: min(max(indicator.x, 9), max(geometry.size.width - 9, 9)),
                            y: min(max(indicator.y, 9), max(geometry.size.height - 9, 9))
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            onChange(value.location, geometry.size)
                        }
                )
        }
        .frame(width: 260, height: 180)
    }
}

private struct HueSlider: View {
    let color: ColorPickerHSBAColor
    let onChange: (CGFloat, CGFloat) -> Void

    var body: some View {
        sliderTrack(
            knobColor: Color(hue: color.hue, saturation: 1, brightness: 1)
        ) {
            LinearGradient(
                colors: stride(from: 0.0, through: 1.0, by: 0.1667).map {
                    Color(hue: $0, saturation: 1, brightness: 1)
                } + [Color(hue: 1, saturation: 1, brightness: 1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } onChange: { locationX, width in
            onChange(locationX, width)
        } indicatorX: { width in
            CGFloat(color.hue) * width
        }
    }
}

private struct AlphaSlider: View {
    let color: ColorPickerHSBAColor
    let onChange: (CGFloat, CGFloat) -> Void

    var body: some View {
        sliderTrack(
            knobColor: color.swiftUIColor
        ) {
            ZStack {
                CheckerboardBackground()
                LinearGradient(
                    colors: [
                        color.swiftUIColor.opacity(0),
                        color.swiftUIColor.opacity(1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        } onChange: { locationX, width in
            onChange(locationX, width)
        } indicatorX: { width in
            CGFloat(color.alpha) * width
        }
    }
}

private func sliderTrack<Background: View>(
    knobColor: Color,
    @ViewBuilder background: @escaping () -> Background,
    onChange: @escaping (CGFloat, CGFloat) -> Void,
    indicatorX: @escaping (CGFloat) -> CGFloat
) -> some View {
    GeometryReader { geometry in
        let knobX = min(max(indicatorX(geometry.size.width), 10), max(geometry.size.width - 10, 10))

        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.white.opacity(0.05))
            .overlay {
                background()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .overlay {
                Circle()
                    .fill(knobColor)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(.white.opacity(0.95), lineWidth: 2))
                    .shadow(color: .black.opacity(0.35), radius: 4)
                    .position(x: knobX, y: geometry.size.height / 2)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onChange(value.location.x, geometry.size.width)
                    }
            )
    }
    .frame(height: 18)
}

private struct CheckerboardBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let squareSize: CGFloat = 8
                let columns = Int(ceil(size.width / squareSize))
                let rows = Int(ceil(size.height / squareSize))

                for row in 0..<rows {
                    for column in 0..<columns {
                        let color = ((row + column) % 2 == 0)
                            ? Color.white.opacity(0.12)
                            : Color.black.opacity(0.08)
                        let rect = CGRect(
                            x: CGFloat(column) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}

private struct ColorPickerValueFields: View {
    @ObservedObject var model: ColorPickerWidgetModel

    @State private var hexDraft = ""
    @State private var redDraft = ""
    @State private var greenDraft = ""
    @State private var blueDraft = ""
    @State private var rgbAlphaDraft = ""
    @State private var hueDraft = ""
    @State private var saturationDraft = ""
    @State private var lightnessDraft = ""
    @State private var hslAlphaDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch model.activeFormat {
            case .hex:
                field(label: "HEX", text: $hexDraft)
                    .onChange(of: hexDraft) { _, newValue in
                        if model.updateFromHex(newValue) {
                            syncFromModel()
                        }
                    }
            case .rgb:
                HStack(spacing: 10) {
                    field(label: "R", text: $redDraft)
                    field(label: "G", text: $greenDraft)
                    field(label: "B", text: $blueDraft)
                    field(label: "A%", text: $rgbAlphaDraft)
                }
                .onChange(of: redDraft) { _, _ in applyRGBDrafts() }
                .onChange(of: greenDraft) { _, _ in applyRGBDrafts() }
                .onChange(of: blueDraft) { _, _ in applyRGBDrafts() }
                .onChange(of: rgbAlphaDraft) { _, _ in applyRGBDrafts() }
            case .hsl:
                HStack(spacing: 10) {
                    field(label: "H", text: $hueDraft)
                    field(label: "S%", text: $saturationDraft)
                    field(label: "L%", text: $lightnessDraft)
                    field(label: "A%", text: $hslAlphaDraft)
                }
                .onChange(of: hueDraft) { _, _ in applyHSLDrafts() }
                .onChange(of: saturationDraft) { _, _ in applyHSLDrafts() }
                .onChange(of: lightnessDraft) { _, _ in applyHSLDrafts() }
                .onChange(of: hslAlphaDraft) { _, _ in applyHSLDrafts() }
            }
        }
        .onAppear(perform: syncFromModel)
        .onChange(of: model.color.serializedHistoryValue) { _, _ in
            syncFromModel()
        }
        .onChange(of: model.activeFormat) { _, _ in
            syncFromModel()
        }
    }

    private func field(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func applyRGBDrafts() {
        if model.updateFromRGB(red: redDraft, green: greenDraft, blue: blueDraft, alpha: rgbAlphaDraft) {
            syncFromModel()
        }
    }

    private func applyHSLDrafts() {
        if model.updateFromHSL(hue: hueDraft, saturation: saturationDraft, lightness: lightnessDraft, alpha: hslAlphaDraft) {
            syncFromModel()
        }
    }

    private func syncFromModel() {
        hexDraft = model.color.alpha >= 0.999 ? model.displayHex : model.color.serializedHistoryValue
        let rgb = model.displayRGB
        redDraft = "\(rgb.red)"
        greenDraft = "\(rgb.green)"
        blueDraft = "\(rgb.blue)"
        rgbAlphaDraft = "\(model.displayAlphaPercent)"

        let hsl = model.displayHSL
        hueDraft = "\(hsl.hue)"
        saturationDraft = "\(hsl.saturation)"
        lightnessDraft = "\(hsl.lightness)"
        hslAlphaDraft = "\(model.displayAlphaPercent)"
    }
}

#Preview {
    if let widget = try? Widget(
        manifest: WidgetManifest(
            schema: 1,
            kind: .interactive,
            id: "color-picker",
            name: "Color Picker",
            author: "Preview",
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
            permissions: nil,
            interactive: .init(type: .colorPicker)
        )
    ),
       let model = widget.interactiveRuntime as? ColorPickerWidgetModel {
        ColorPickerWidgetPageView(widget: widget, model: model)
            .frame(width: 760, height: 360)
            .background(.black)
    }
}
