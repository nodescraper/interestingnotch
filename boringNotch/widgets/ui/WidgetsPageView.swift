//
//  WidgetsPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct WidgetsPageView: View {
    @ObservedObject private var engine = WidgetEngine.shared

    private let columns = [
        GridItem(.adaptive(minimum: 176, maximum: 220), spacing: 12, alignment: .top),
    ]

    var body: some View {
        ScrollView {
            if engine.widgets.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(engine.widgets, id: \.id) { widget in
                        WidgetCardView(widget: widget)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
            }
        }
        .scrollIndicators(.never)
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1.5, dash: [8]))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.03))
            )
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.effectiveAccent.opacity(0.9))

                    Text("No widgets yet")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Install a widget in Workshop to see live cards here.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
    }
}

#Preview("Widgets Empty") {
    WidgetsPageView()
        .frame(width: 500, height: 320)
        .background(.black)
}

#Preview("Widgets Loaded") {
    WidgetsPageLoadedPreview()
        .frame(width: 500, height: 320)
        .background(.black)
}

private struct WidgetsPageLoadedPreview: View {
    @State private var didLoadPreview = false

    var body: some View {
        WidgetsPageView()
            .task {
                guard !didLoadPreview else { return }
                didLoadPreview = true
                WidgetEngine.shared.load(makePreviewWidgets())
            }
    }

    @MainActor
    private func makePreviewWidgets() -> [Widget] {
        [
            makePreviewWidget(
                id: "preview-git",
                name: "Git Status",
                template: .iconLabel,
                lastValue: .integer(2),
                status: .ok,
                color: "accent",
                icon: "arrow.triangle.branch",
                label: "$value pending"
            ),
            makePreviewWidget(
                id: "preview-brew",
                name: "Brew Updates",
                template: .iconLabel,
                lastValue: nil,
                status: .loading,
                color: "warn",
                icon: "shippingbox",
                label: "Checking updates"
            ),
            makePreviewWidget(
                id: "preview-usage",
                name: "Codex Usage",
                template: .progress,
                lastValue: .double(41.2),
                status: .error("CLI not reachable"),
                color: "good",
                icon: "gauge.with.needle",
                label: "$value%"
            ),
        ]
        .compactMap { $0 }
    }

    @MainActor
    private func makePreviewWidget(
        id: String,
        name: String,
        template: WidgetManifest.Render.Template,
        lastValue: WidgetValue?,
        status: WidgetStatus,
        color: String,
        icon: String,
        label: String
    ) -> Widget? {
        try? Widget(
            manifest: WidgetManifest(
                schema: 1,
                kind: .data,
                id: id,
                name: name,
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
                    template: template,
                    slots: [
                        "icon": .string(icon),
                        "label": .string(label),
                        "color": .string(color),
                    ]
                ),
                onTap: nil,
                permissions: nil
            ),
            executor: WidgetsPagePreviewExecutor(),
            extractor: ExtractorPipeline(extractors: [RawExtractor()]),
            lastValue: lastValue,
            status: status
        )
    }
}

private actor WidgetsPagePreviewExecutor: ChannelExecutor {
    let channelType: WidgetManifest.Source.ChannelType = .command

    func run(source: WidgetManifest.Source) async throws -> String {
        ""
    }
}
