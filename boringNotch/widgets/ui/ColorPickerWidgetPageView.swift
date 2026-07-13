//
//  ColorPickerWidgetPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct ColorPickerWidgetPageView: View {
    let widget: Widget

    @ObservedObject var model: ColorPickerWidgetModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            topRow
            recentRow
        }
        .padding(18)
        .background(cardBackground)
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var topRow: some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(model.color.swiftUIColor)
                .frame(width: 64, height: 64)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayHex)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("rgb(\(model.displayRGB.red), \(model.displayRGB.green), \(model.displayRGB.blue))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                actionButton(title: "Pick", systemImage: "eyedropper") {
                    Task {
                        await model.pickScreenColor()
                    }
                }

                actionButton(title: "Copy", systemImage: "doc.on.doc") {
                    model.copyCurrentColor()
                }
            }
        }
    }

    private var recentRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Recent")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if model.recentHistory.isEmpty {
                Text("Copied colors and eyedropper picks show up here.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                HStack(spacing: 8) {
                    ForEach(model.recentHistory, id: \.self) { entry in
                        Button {
                            model.restoreHistoryEntry(entry)
                        } label: {
                            if let restored = ColorPickerHistoryStore.restore(entry) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(restored.swiftUIColor)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(entry)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
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

#Preview("Color Picker Widget") {
    ColorPickerWidgetPreview()
        .frame(width: 440, height: 180)
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
