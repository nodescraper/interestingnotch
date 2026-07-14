//
//  AccessoryBatteryWidgetPageView.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct AccessoryBatteryWidgetPageView: View {
    @ObservedObject var widget: Widget

    private var snapshot: AccessoryBatterySnapshot? {
        AccessoryBatterySnapshot(widgetValue: widget.lastValue)
    }

    private var devices: [AccessoryBatteryDeviceSnapshot] {
        snapshot?.devices ?? []
    }

    var body: some View {
        Group {
            if case .error(let message) = widget.status {
                errorState(message: message)
            } else if widget.status == .loading && devices.isEmpty {
                loadingState
            } else if devices.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(devices) { device in
                            AccessoryBatteryDeviceCard(device: device)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.leading, 5)
                    .padding(.trailing, 5)
                    .padding(.bottom, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Loading accessory batteries…")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text("Looking for connected Bluetooth devices that report battery levels.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No accessories with battery info")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text("Connect AirPods, a Magic accessory, or another reporting Bluetooth device to see it here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func errorState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Accessory battery unavailable")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(.top, 12)
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct AccessoryBatteryDeviceCard: View {
    let device: AccessoryBatteryDeviceSnapshot

    private var accentColor: Color {
        device.isCritical ? .red : .white
    }

    private var cardWidth: CGFloat {
        device.isAirPodsStyle ? 168 : 138
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if device.isAirPodsStyle, let battery = device.battery {
                airPodsSummary(battery)
            } else if let percent = device.primaryPercent {
                singleBatterySummary(percent: percent)
            } else {
                Text("no battery info")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(width: cardWidth, height: 104, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: device.symbolName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(device.hasBatteryInfo ? accentColor : .white.opacity(0.72))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(device.isConnected ? "Connected" : "Recent")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if device.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private func singleBatterySummary(percent: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))

                    Capsule()
                        .fill(accentColor)
                        .frame(width: geometry.size.width * CGFloat(Double(percent) / 100.0))
                }
            }
            .frame(height: 6)

            Text("\(percent)%")
                .font(.headline.weight(.bold))
                .foregroundStyle(accentColor)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func airPodsSummary(_ battery: AccessoryBatteryComponents) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(battery.cellValues, id: \.0) { label, value in
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text("\(value)%")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(value < 15 ? .red : .white)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview("Accessory Battery Widget") {
    AccessoryBatteryWidgetPreviewHost()
        .frame(width: 440, height: 180)
        .background(.black)
}

private struct AccessoryBatteryWidgetPreviewHost: View {
    @MainActor
    private var previewWidget: Widget? {
        try? Widget(
            manifest: WidgetManifest(
                schema: 1,
                kind: .data,
                id: "accessory-battery",
                name: "Accessory Battery",
                author: "Preview",
                source: .init(
                    type: .framework,
                    run: nil,
                    url: nil,
                    method: nil,
                    headers: nil,
                    api: AccessoryBatteryProvider.api,
                    interval: 30,
                    timeout: nil,
                    cwd: nil,
                    env: nil
                ),
                extract: .init(method: .jsonPath, pattern: nil, path: "$", table: nil),
                render: .init(
                    template: .text,
                    slots: [
                        "icon": .string("airpodspro"),
                        "label": .string("Accessory Battery"),
                        "color": .string("accent"),
                    ]
                ),
                onTap: nil,
                permissions: ["bluetooth"],
                interactive: nil
            ),
            lastValue: AccessoryBatterySnapshot(
                devices: [
                    AccessoryBatteryDeviceSnapshot(
                        id: "airpods",
                        name: "AirPods Pro",
                        kind: .earbuds,
                        isConnected: true,
                        battery: .init(left: 82, right: 18, casePercent: 100)
                    ),
                    AccessoryBatteryDeviceSnapshot(
                        id: "mouse",
                        name: "Magic Mouse",
                        kind: .mouse,
                        isConnected: true,
                        battery: .init(single: 46)
                    ),
                    AccessoryBatteryDeviceSnapshot(
                        id: "jabra",
                        name: "Jabra Elite 3",
                        kind: .headphones,
                        isConnected: true,
                        battery: nil
                    ),
                ]
            ).widgetValue,
            status: .ok
        )
    }

    var body: some View {
        if let previewWidget {
            AccessoryBatteryWidgetPageView(widget: previewWidget)
        }
    }
}
