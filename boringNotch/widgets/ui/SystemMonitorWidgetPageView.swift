//
//  SystemMonitorWidgetPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct SystemMonitorWidgetPageView: View {
    @ObservedObject var widget: Widget

    private var snapshot: SystemMonitorSnapshot? {
        SystemMonitorSnapshot(widgetValue: widget.lastValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                header
                metricsBlock
            }
            .padding(.top, 10)
            .padding(.leading, 5)

            Spacer(minLength: 0)

            Divider()
                .overlay(Color.white.opacity(0.10))
                .padding(.vertical, 8)

            footer

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(widget.manifest.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("Live CPU, memory, and disk usage.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var metricsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            metricRow(title: "CPU", value: snapshot?.cpuPercent)
            metricRow(title: "RAM", value: snapshot?.memoryPercent)

            if let diskPercent = snapshot?.diskPercent {
                metricRow(title: "Disk", value: diskPercent)
            }
        }
    }

    private func metricRow(title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer(minLength: 0)

                Text(value.map(SystemMonitorFormatting.percentString) ?? "--")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))

                    Capsule()
                        .fill(barColor(for: value))
                        .frame(width: geometry.size.width * CGFloat(min(max((value ?? 0) / 100, 0), 1)))
                }
            }
            .frame(height: 6)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Uptime \(snapshot?.uptimeText ?? "--")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text("Load \(snapshot?.loadAverageText ?? "--")")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func barColor(for value: Double?) -> Color {
        guard let value else { return Color.white.opacity(0.32) }
        return value >= 90 ? .red : .white
    }
}

#Preview("System Monitor Widget") {
    SystemMonitorWidgetPreviewHost()
        .frame(width: 440, height: 180)
        .background(.black)
}

private struct SystemMonitorWidgetPreviewHost: View {
    var body: some View {
        if let widget = previewWidget {
            SystemMonitorWidgetPageView(widget: widget)
        }
    }

    @MainActor
    private var previewWidget: Widget? {
        try? Widget(
            manifest: WidgetManifest(
                schema: 1,
                kind: .data,
                id: "system-monitor",
                name: "System Monitor",
                author: "Preview",
                source: .init(
                    type: .framework,
                    run: nil,
                    url: nil,
                    method: nil,
                    headers: nil,
                    api: "system-monitor",
                    interval: 3,
                    timeout: nil,
                    cwd: nil,
                    env: nil
                ),
                extract: .init(method: .jsonPath, pattern: nil, path: "$", table: nil),
                render: .init(
                    template: .text,
                    slots: [
                        "icon": .string("waveform.path.ecg"),
                        "label": .string("System Monitor"),
                        "color": .string("accent"),
                    ]
                ),
                onTap: nil,
                permissions: nil,
                interactive: nil
            ),
            lastValue: SystemMonitorSnapshot(
                cpuPercent: 27,
                memoryPercent: 61,
                diskPercent: 44,
                uptimeText: "3h 42m",
                loadAverageText: "1.02 0.96 0.88"
            ).widgetValue,
            status: .ok
        )
    }
}
