//
//  WidgetCardView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct WidgetCardView: View {
    @ObservedObject var widget: Widget

    var body: some View {
        templateView
    }

    @ViewBuilder
    private var templateView: some View {
        switch widget.manifest.render.template {
        case .iconLabel:
            IconLabelTemplate(
                icon: resolvedIcon,
                label: resolvedLabel,
                accentColor: widget.resolvedColor,
                status: widget.status
            )
        case .progress:
            ProgressTemplate(
                icon: resolvedIcon,
                label: resolvedLabel,
                value: resolvedProgressValue,
                accentColor: widget.resolvedColor,
                status: widget.status
            )
        case .text, .gauge, .list, .button:
            fallbackView
        }
    }

    private var resolvedIcon: String {
        WidgetSlotRenderer.resolvedString(
            forSlotNamed: "icon",
            in: widget.manifest.render.slots,
            value: widget.lastValue,
            fallback: "square.grid.2x2"
        )
    }

    private var resolvedLabel: String {
        WidgetSlotRenderer.resolvedString(
            forSlotNamed: "label",
            in: widget.manifest.render.slots,
            value: widget.lastValue,
            fallback: widget.manifest.name
        )
    }

    private var resolvedProgressValue: Double {
        WidgetSlotRenderer.numericValue(from: widget.lastValue) ?? 0
    }

    private var fallbackView: some View {
        IconLabelTemplate(
            icon: "hammer.circle",
            label: widget.manifest.name,
            accentColor: widget.resolvedColor,
            status: .error("Template '\(widget.manifest.render.template.rawValue)' is not available yet.")
        )
    }
}

#Preview("Widget Cards") {
    WidgetCardPreviewGrid()
        .padding()
        .background(.black)
}

private struct WidgetCardPreviewGrid: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 176, maximum: 208), spacing: 12)], spacing: 12) {
            if let okCard = makePreviewWidget(
                id: "git-status-preview",
                name: "Git Status",
                template: .iconLabel,
                lastValue: .integer(3),
                status: .ok,
                color: "accent",
                icon: "arrow.triangle.branch",
                label: "$value changes ready"
            ) {
                WidgetCardView(widget: okCard)
            }

            if let loadingCard = makePreviewWidget(
                id: "brew-preview",
                name: "Brew Updates",
                template: .iconLabel,
                lastValue: nil,
                status: .loading,
                color: "warn",
                icon: "shippingbox",
                label: "Checking updates"
            ) {
                WidgetCardView(widget: loadingCard)
            }

            if let progressCard = makePreviewWidget(
                id: "battery-preview",
                name: "Battery",
                template: .progress,
                lastValue: .integer(87),
                status: .ok,
                color: "good",
                icon: "battery.100",
                label: "$value%"
            ) {
                WidgetCardView(widget: progressCard)
            }

            if let errorCard = makePreviewWidget(
                id: "cpu-preview",
                name: "CPU",
                template: .progress,
                lastValue: .double(14.8),
                status: .error("Provider unavailable"),
                color: "bad",
                icon: "cpu",
                label: "$value%"
            ) {
                WidgetCardView(widget: errorCard)
            }
        }
        .frame(width: 420)
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
            executor: WidgetPreviewExecutor(),
            extractor: ExtractorPipeline(extractors: [RawExtractor()]),
            lastValue: lastValue,
            status: status
        )
    }
}

private actor WidgetPreviewExecutor: ChannelExecutor {
    let channelType: WidgetManifest.Source.ChannelType = .command

    func run(source: WidgetManifest.Source) async throws -> String {
        ""
    }
}
