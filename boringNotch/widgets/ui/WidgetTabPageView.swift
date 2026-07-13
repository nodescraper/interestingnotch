//
//  WidgetTabPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct WidgetTabPageView: View {
    let widgetID: String

    @ObservedObject private var engine = WidgetEngine.shared

    var body: some View {
        if let widget = engine.widgets.first(where: { $0.id == widgetID }) {
            content(for: widget)
        } else {
            unavailableState
        }
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
                kind: .data,
                id: "preview-widget",
                name: "Preview Widget",
                author: "Preview",
                source: .init(
                    type: .command,
                    run: "cat /dev/null",
                    url: nil,
                    method: nil,
                    headers: nil,
                    api: nil,
                    interval: 10,
                    timeout: 1,
                    cwd: nil,
                    env: nil
                ),
                extract: .init(
                    method: .raw,
                    pattern: nil,
                    path: nil,
                    table: nil
                ),
                render: .init(
                    template: .iconLabel,
                    slots: [
                        "icon": .string("paintpalette.fill"),
                        "label": .string("Preview"),
                        "color": .string("accent"),
                    ]
                ),
                onTap: nil,
                permissions: nil
            ),
            executor: WidgetTabPagePreviewExecutor(),
            extractor: ExtractorPipeline(extractors: [RawExtractor()]),
            lastValue: .string("Preview"),
            status: .ok
        )
    }
}

private actor WidgetTabPagePreviewExecutor: ChannelExecutor {
    let channelType: WidgetManifest.Source.ChannelType = .command

    func run(source: WidgetManifest.Source) async throws -> String {
        ""
    }
}
