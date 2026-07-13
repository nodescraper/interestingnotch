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
        HStack(alignment: .top, spacing: 12) {
            swatchView
                .padding(.all, 5)
            detailsColumn
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var swatchView: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(model.color.swiftUIColor)

            Button {
                Task {
                    await model.pickScreenColor()
                }
            } label: {
                Image(systemName: "eyedropper")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.black.opacity(0.38), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
            .help("Pick a color")
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 144)
    }

    private var detailsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(model.displayHex)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Button {
                        model.copyCurrentColor()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy color")
                }

                HStack(spacing: 0) {
                    Text("rgb(\(model.displayRGB.red), \(model.displayRGB.green), \(model.displayRGB.blue))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 10)
            .padding(.leading, 5)

            Spacer(minLength: 0)

            Divider()
                .overlay(Color.white.opacity(0.10))
                .padding(.vertical, 8)

            recentRow

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var recentRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Recent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if model.recentHistory.isEmpty {
                Text("Copied colors and eyedropper picks show up here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
