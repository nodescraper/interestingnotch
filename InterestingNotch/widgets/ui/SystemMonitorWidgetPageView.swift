//
//  SystemMonitorWidgetPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//  Redesigned to match the Timer widget's Apple-like styling.
//

import SwiftUI

struct SystemMonitorWidgetPageView: View {
    @ObservedObject var widget: Widget

    // Subtle track behind each ring.
    private let track = Color.white.opacity(0.08)

    private struct MetricDescriptor: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let value: Double?
        /// Unit for the ring label: "%" or "°".
        let unit: String
        /// Value at which the metric is considered "maxed" for the ring/bar fill.
        let fullScale: Double
        /// Optional pre-formatted center label (used by non-percent metrics like network).
        var customLabel: String? = nil
        /// Optional 0...1 fill override (used when fill isn't value/fullScale).
        var customFraction: Double? = nil
    }

    private var snapshot: SystemMonitorSnapshot? {
        SystemMonitorSnapshot(widgetValue: widget.lastValue)
    }

    private var metrics: [MetricDescriptor] {
        var items: [MetricDescriptor] = [
            MetricDescriptor(id: "cpu", title: "CPU", symbol: "cpu", value: snapshot?.cpuPercent, unit: "%", fullScale: 100),
            MetricDescriptor(id: "ram", title: "RAM", symbol: "memorychip", value: snapshot?.memoryPercent, unit: "%", fullScale: 100),
        ]
        if let diskPercent = snapshot?.diskPercent {
            items.append(MetricDescriptor(id: "disk", title: "Disk", symbol: "internaldrive", value: diskPercent, unit: "%", fullScale: 100))
        }

        // Network ring: fill scaled against the rolling peak, compact label.
        let rate = snapshot?.networkBytesPerSec
        let peak = max(snapshot?.networkPeakBytesPerSec ?? 1, 1)
        items.append(
            MetricDescriptor(
                id: "net",
                title: "Net",
                symbol: "arrow.up.arrow.down",
                value: rate,
                unit: "",
                fullScale: peak,
                customLabel: rate.map(shortRate) ?? "--",
                customFraction: rate.map { min(max($0 / peak, 0), 1) }
            )
        )
        return items
    }

    var body: some View {
        GeometryReader { geometry in
            contentColumn(availableHeight: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func contentColumn(availableHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Signature: ring gauges spread evenly across the full width.
            HStack(spacing: 0) {
                ForEach(metrics) { metric in
                    ringGauge(metric)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)

            footer
                .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Ring gauge (signature element)

    private func ringGauge(_ metric: MetricDescriptor) -> some View {
        let fraction = fillFraction(metric)
        let color = accentColor(metric)
        // Gradient sweeps from a warm base into the metric's accent, so the arc
        // has depth instead of reading as a flat stroke.
        let gradient = AngularGradient(
            gradient: Gradient(colors: [color.opacity(0.55), color]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * fraction)
        )

        return VStack(spacing: 7) {
            ZStack {
                // Track
                Circle()
                    .stroke(track, lineWidth: 6)

                // Progress arc with gradient + soft glow
                Circle()
                    .trim(from: 0, to: CGFloat(fraction))
                    .stroke(gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.45), radius: 4, x: 0, y: 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8), value: fraction)

                // Center: value as hero, tiny icon above.
                VStack(spacing: 0) {
                    Image(systemName: metric.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color.opacity(0.75))
                    Text(ringLabel(metric))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                }
            }
            .frame(width: 64, height: 64)

            Text(metric.title)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(1.2)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .medium))
            Text(snapshot?.uptimeText ?? "--")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.38))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Shared value logic

    /// 0...1 fill for rings and bars.
    private func fillFraction(_ metric: MetricDescriptor) -> Double {
        if let custom = metric.customFraction { return custom }
        guard let value = metric.value else { return 0 }
        return min(max(value / metric.fullScale, 0), 1)
    }

    /// Smoothly warms from amber → orange → red as load rises, instead of a hard
    /// snap to red at 90%. Gives each ring a color that reads its own load at a glance.
    private func accentColor(_ metric: MetricDescriptor) -> Color {
        guard let value = metric.value else { return .white.opacity(0.28) }
        let t = min(max(value / metric.fullScale, 0), 1)

        // Anchor colors.
        let amber  = (r: 0.98, g: 0.72, b: 0.30)   // low
        let orange = (r: 0.96, g: 0.52, b: 0.20)   // mid
        let red    = (r: 0.93, g: 0.30, b: 0.26)   // high

        func lerp(_ a: (r: Double, g: Double, b: Double),
                  _ b: (r: Double, g: Double, b: Double),
                  _ f: Double) -> Color {
            Color(red: a.r + (b.r - a.r) * f,
                  green: a.g + (b.g - a.g) * f,
                  blue: a.b + (b.b - a.b) * f)
        }

        if t < 0.6 {
            return lerp(amber, orange, t / 0.6)
        } else {
            return lerp(orange, red, (t - 0.6) / 0.4)
        }
    }

    private func ringLabel(_ metric: MetricDescriptor) -> String {
        if let custom = metric.customLabel { return custom }
        guard let value = metric.value else { return "--" }
        return "\(Int(value.rounded()))\(metric.unit)"
    }

    /// Compact rate for the network ring center, e.g. "1.2M", "840K".
    private func shortRate(_ bytesPerSec: Double) -> String {
        let units = ["B", "K", "M", "G"]
        var v = bytesPerSec
        var u = 0
        while v >= 1024 && u < units.count - 1 { v /= 1024; u += 1 }
        if u == 0 { return "\(Int(v))\(units[u])" }
        return String(format: "%.1f%@", v, units[u])
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
                loadAverageText: "1.02 0.96 0.88",
                networkBytesPerSec: 1_340_000,
                networkPeakBytesPerSec: 2_000_000
            ).widgetValue,
            status: .ok
        )
    }
}
