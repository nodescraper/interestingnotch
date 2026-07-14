//
//  SystemMonitorWidgetPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct SystemMonitorWidgetPageView: View {
    @ObservedObject var widget: Widget

    private struct MetricDescriptor: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let value: Double?
        let tint: Color?
    }

    private var snapshot: SystemMonitorSnapshot? {
        SystemMonitorSnapshot(widgetValue: widget.lastValue)
    }

    private var metrics: [MetricDescriptor] {
        var items: [MetricDescriptor] = [
            MetricDescriptor(id: "cpu", title: "CPU", symbol: "cpu", value: snapshot?.cpuPercent, tint: nil),
            MetricDescriptor(id: "ram", title: "RAM", symbol: "memorychip", value: snapshot?.memoryPercent, tint: nil),
        ]

        if let diskPercent = snapshot?.diskPercent {
            items.append(
                MetricDescriptor(id: "disk", title: "Disk", symbol: "internaldrive", value: diskPercent, tint: nil)
            )
        }

        if let temperatureCelsius = snapshot?.temperatureCelsius {
            items.append(
                MetricDescriptor(
                    id: "temp",
                    title: "Temp",
                    symbol: "thermometer.medium",
                    value: temperatureCelsius,
                    tint: Color.orange.opacity(0.9)
                )
            )
        }

        return items
    }

    var body: some View {
        GeometryReader { geometry in
            detailsColumn(availableHeight: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func detailsColumn(availableHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            metricsBlock
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)
                .padding(.horizontal, 4)

            Divider()
                .overlay(Color.white.opacity(0.10))
                .padding(.top, max(8, availableHeight * 0.05))
                .padding(.bottom, 8)

            footer
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var metricsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                metricRow(
                    title: metric.title,
                    symbol: metric.symbol,
                    value: metric.value,
                    tint: metric.tint
                )

                if index < metrics.count - 1 {
                    Spacer(minLength: 8)
                }
            }
        }
    }

    private func metricRow(title: String, symbol: String, value: Double?, tint: Color?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 12)

            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(width: 28, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))

                    Capsule()
                        .fill(barColor(for: value, tint: tint))
                        .frame(width: geometry.size.width * CGFloat(min(max((value ?? 0) / 100, 0), 1)))
                }
            }
            .frame(height: 6)

            Text(formattedValue(for: title, value: value))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor(for: value, tint: tint))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
        .frame(height: 16)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("Uptime \(snapshot?.uptimeText ?? "--")")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text("Load \(snapshot?.loadAverageText ?? "--")")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func formattedValue(for title: String, value: Double?) -> String {
        guard let value else { return "--" }
        if title == "Temp" {
            return SystemMonitorFormatting.temperatureString(value)
        }
        return SystemMonitorFormatting.percentString(value)
    }

    private func barColor(for value: Double?, tint: Color?) -> Color {
        if let tint {
            return tint
        }

        guard let value else { return Color.white.opacity(0.32) }
        return value >= 90 ? .red : .white
    }

    private func valueColor(for value: Double?, tint: Color?) -> Color {
        if let tint {
            return tint
        }

        guard let value else { return .white.opacity(0.42) }
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
                temperatureCelsius: 56,
                uptimeText: "3h 42m",
                loadAverageText: "1.02 0.96 0.88"
            ).widgetValue,
            status: .ok
        )
    }
}
