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
        HStack(alignment: .top, spacing: 12) {
            statusTile
                .padding(.all, 5)

            detailsColumn

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusTile: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "cpu")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)

                    tileMetric(symbol: "cpu", label: "CPU", value: snapshot?.cpuDisplay ?? "--%")
                    tileMetric(symbol: "memorychip", label: "RAM", value: snapshot?.memoryDisplay ?? "--%")

                    if let diskDisplay = snapshot?.diskDisplay {
                        tileMetric(symbol: "internaldrive", label: "Disk", value: diskDisplay)
                    }
                }
                .padding(14)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 144)
    }

    private var detailsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(widget.manifest.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("Live CPU, memory, and disk vitals.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var metricsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            metricRow(title: "CPU", symbol: "cpu", value: snapshot?.cpuPercent)
            metricRow(title: "RAM", symbol: "memorychip", value: snapshot?.memoryPercent)

            if let diskPercent = snapshot?.diskPercent {
                metricRow(title: "Disk", symbol: "internaldrive", value: diskPercent)
            }
        }
    }

    private func metricRow(title: String, symbol: String, value: Double?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(width: 34, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))

                    Capsule()
                        .fill(barColor(for: value))
                        .frame(width: geometry.size.width * CGFloat(min(max((value ?? 0) / 100, 0), 1)))
                }
            }
            .frame(height: 5)

            Text(value.map(SystemMonitorFormatting.percentString) ?? "--")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
        .frame(height: 14)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("Uptime \(snapshot?.uptimeText ?? "--")")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text("Load \(snapshot?.loadAverageText ?? "--")")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.leading, 5)
    }

    private func barColor(for value: Double?) -> Color {
        guard let value else { return Color.white.opacity(0.32) }
        return value >= 90 ? .red : .white
    }

    private func tileMetric(symbol: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 12)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))

            Spacer(minLength: 0)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
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
                        "icon": .string("cpu"),
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
