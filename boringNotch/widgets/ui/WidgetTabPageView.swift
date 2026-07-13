//
//  WidgetTabPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

enum WidgetTabPageKind: Equatable {
    case colorPicker
    case timer
    case clipboardHistory
    case systemMonitor
    case placeholder
}

enum WidgetTabPageResolver {
    static func pageKind(for widget: Widget) -> WidgetTabPageKind {
        if widget.id == "system-monitor" {
            return .systemMonitor
        }

        if widget.manifest.kind == .interactive {
            switch widget.manifest.interactive?.type {
            case .colorPicker:
                return .colorPicker
            case .timer:
                return .timer
            case .clipboardHistory:
                return .clipboardHistory
            case .none:
                break
            }
        }

        return .placeholder
    }
}

struct WidgetTabPageView: View {
    let widgetID: String

    @ObservedObject private var engine = WidgetEngine.shared

    var body: some View {
        Group {
            if let widget = engine.widgets.first(where: { $0.id == widgetID }) {
                switch WidgetTabPageResolver.pageKind(for: widget) {
                case .colorPicker:
                    if let model = widget.interactiveRuntime as? ColorPickerWidgetModel {
                        ColorPickerWidgetPageView(widget: widget, model: model)
                    } else {
                        unavailableState
                    }
                case .timer:
                    if let model = widget.interactiveRuntime as? TimerWidgetModel {
                        TimerWidgetPageView(widget: widget, model: model)
                    } else {
                        unavailableState
                    }
                case .clipboardHistory:
                    if let model = widget.interactiveRuntime as? ClipboardHistoryWidgetModel {
                        ClipboardHistoryWidgetPageView(widget: widget, model: model)
                    } else {
                        unavailableState
                    }
                case .systemMonitor:
                    SystemMonitorWidgetPageView(widget: widget)
                case .placeholder:
                    content(for: widget)
                }
            } else {
                unavailableState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func content(for widget: Widget) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(widget.resolvedColor.opacity(0.18))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: WidgetSlotRenderer.resolvedString(
                            forSlotNamed: "icon",
                            in: widget.manifest.render.slots,
                            value: widget.lastValue,
                            fallback: "square.grid.2x2"
                        ))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(widget.resolvedColor)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(widget.manifest.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(widget.id)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pinned widget page")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("This placeholder confirms dynamic notch-tab navigation is wired. The real full-page widget UI lands in the next tickets.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Divider()
                            .overlay(Color.white.opacity(0.06))

                        Text("Status: \(statusText(for: widget.status))")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(22)
                }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }

    private var unavailableState: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "questionmark.square.dashed")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("Widget unavailable")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(widgetID)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(28)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
    }

    private func statusText(for status: WidgetStatus) -> String {
        switch status {
        case .loading:
            return "Loading"
        case .ok:
            return "OK"
        case .error(let message):
            return "Error - \(message)"
        case .disabled:
            return "Disabled"
        }
    }
}

#Preview("Pinned Widget Page") {
    WidgetTabPagePreviewHost()
        .frame(width: 520, height: 280)
        .background(.black)
}

private struct WidgetTabPagePreviewHost: View {
    @State private var loaded = false

    var body: some View {
        WidgetTabPageView(widgetID: "preview-widget")
            .task {
                guard !loaded else { return }
                loaded = true

                if let widget = makePreviewWidget() {
                    WidgetEngine.shared.load([widget])
                }
            }
    }

    @MainActor
    private func makePreviewWidget() -> Widget? {
        try? Widget(
            manifest: WidgetManifest(
                schema: 1,
                kind: .interactive,
                id: "preview-widget",
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
            lastValue: nil,
            status: .ok
        )
    }
}
