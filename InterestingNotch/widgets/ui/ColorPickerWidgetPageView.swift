//
//  ColorPickerWidgetPageView.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//  Horizontal Apple-like layout: signature swatch, a clean value column
//  (HEX hero + copyable RGB/HSL), and a saved-colors strip filling the right.
//

import SwiftUI

struct ColorPickerWidgetPageView: View {
    let widget: Widget

    @ObservedObject var model: ColorPickerWidgetModel

    private let accent = Color.effectiveAccent

    @State private var copiedFormat: ColorPickerFormat?

    // Layout constants.
    private let hPadding: CGFloat = 14
    private let vPadding: CGFloat = 12
    private let swatchSize: CGFloat = 110

    var body: some View {
        HStack(spacing: 16) {
            swatch
            values
            Spacer(minLength: 8)
            savedColors
        }
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    // MARK: - Signature swatch

    private var swatch: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(model.color.swiftUIColor)
                .blur(radius: 14)
                .opacity(0.5)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(model.color.swiftUIColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.color)

            Button {
                Task { await model.pickScreenColor() }
            } label: {
                Image(systemName: "eyedropper")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.32), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(8)
            .help("Pick a color from screen")
        }
        .frame(width: swatchSize, height: swatchSize)
    }

    // MARK: - Value column

    private var values: some View {
        VStack(alignment: .leading, spacing: 0) {
            hexRow
            valueRow(label: "RGB", value: model.color.cssRGBString, format: .rgb)
                .padding(.top, 10)
            valueRow(label: "HSL", value: model.color.cssHSLString, format: .hsl)
                .padding(.top, 6)
        }
        .frame(minWidth: 150, alignment: .leading)
        .frame(height: swatchSize, alignment: .top)
    }

    private var hexRow: some View {
        Button {
            copy(model.displayHex, format: .hex)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.displayHex)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())

                Image(systemName: copiedFormat == .hex ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(copiedFormat == .hex ? accent : .white.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Copy HEX")
    }

    private func valueRow(label: String, value: String, format: ColorPickerFormat) -> some View {
        Button {
            copy(value, format: format)
        } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .tracking(0.8)
                    .frame(width: 28, alignment: .leading)

                Text(value)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer(minLength: 6)

                Image(systemName: copiedFormat == format ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(copiedFormat == format ? accent : .white.opacity(0.3))
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Copy \(label)")
    }

    // MARK: - Saved colors (right strip)

    private var savedColors: some View {
        let dot: CGFloat = 22
        let spacing: CGFloat = 8
        let rows = max(1, Int((swatchSize + spacing) / (dot + spacing)))
        let capacity = rows * 2

        return VStack(alignment: .leading, spacing: 6) {
            Text("SAVED")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.35))

            if model.recentHistory.isEmpty {
                Text("Picks appear here")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(width: dot * 2 + spacing, alignment: .leading)
            } else {
                let entries = Array(model.recentHistory.prefix(capacity))
                LazyVGrid(
                    columns: [GridItem(.fixed(dot), spacing: spacing),
                              GridItem(.fixed(dot), spacing: spacing)],
                    alignment: .leading,
                    spacing: spacing
                ) {
                    ForEach(entries, id: \.self) { entry in
                        Button {
                            model.restoreHistoryEntry(entry)
                        } label: {
                            if let restored = ColorPickerHistoryStore.restore(entry) {
                                Circle()
                                    .fill(restored.swiftUIColor)
                                    .frame(width: dot, height: dot)
                                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                            }
                        }
                        .buttonStyle(.plain)
                        .help(entry)
                    }
                }
            }
        }
        .frame(width: dot * 2 + spacing, height: swatchSize, alignment: .top)
        .clipped()
    }

    // MARK: - Copy handling

    private func copy(_ string: String, format: ColorPickerFormat) {
        let previous = model.activeFormat
        model.activeFormat = format
        model.copyCurrentColor()
        model.activeFormat = previous

        withAnimation(.easeInOut(duration: 0.15)) { copiedFormat = format }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if copiedFormat == format { copiedFormat = nil }
                }
            }
        }
    }
}

#Preview("Color Picker Widget") {
    ColorPickerWidgetPreview()
        .frame(width: 460, height: 150)
        .background(.black)
}

private struct ColorPickerWidgetPreview: View {
    @State private var loaded = false
    private let previewModel = ColorPickerWidgetModel(widgetID: "preview-color-picker")

    var body: some View {
        Group {
            if let widget = previewWidget {
                ColorPickerWidgetPageView(widget: widget, model: previewModel)
            } else {
                Color.black
            }
        }
        .task {
            guard !loaded else { return }
            loaded = true
            previewModel.copyCurrentColor()
        }
    }

    @MainActor
    private var previewWidget: Widget? {
        try? Widget(
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
            ),
            interactiveRuntime: previewModel,
            lastValue: nil,
            status: .ok
        )
    }
}
