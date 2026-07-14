//
//  AccessoryBatteryWidgetPageView.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//  Compact battery rows — logical for a notch: icon, name, level bar, percent,
//  with AirPods L/R/Case inline. Battery-level color (green → yellow → red).
//

import SwiftUI

struct AccessoryBatteryWidgetPageView: View {
    @ObservedObject var widget: Widget

    private let orange = Color(red: 0.96, green: 0.58, blue: 0.24)

    private var snapshot: AccessoryBatterySnapshot? {
        AccessoryBatterySnapshot(widgetValue: widget.lastValue)
    }

    private var devices: [AccessoryBatteryDeviceSnapshot] {
        snapshot?.devices ?? []
    }

    var body: some View {
        Group {
            if case .error(let message) = widget.status {
                infoState(title: "Battery unavailable", detail: message, icon: "exclamationmark.triangle")
            } else if widget.status == .loading && devices.isEmpty {
                infoState(title: "Checking accessories…", detail: "Looking for Bluetooth devices reporting battery.", icon: "dot.radiowaves.left.and.right")
            } else if devices.isEmpty {
                infoState(title: "No accessories", detail: "Connect AirPods or a Magic accessory to see battery here.", icon: "airpods")
            } else {
                deviceList
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var deviceList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(devices) { device in
                    deviceCard(device)
                }
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: - Device card

    private func deviceCard(_ device: AccessoryBatteryDeviceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: icon + charging bolt.
            HStack(spacing: 6) {
                Image(systemName: device.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
                if device.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                } else if !device.isConnected {
                    Text("Recent")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer(minLength: 6)

            // Name.
            Text(device.name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            // Battery.
            batteryDetail(device)
        }
        .padding(11)
        .frame(width: cardWidth(for: device), height: 96, alignment: .topLeading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func cardWidth(for device: AccessoryBatteryDeviceSnapshot) -> CGFloat {
        device.isAirPodsStyle ? 176 : 140
    }

    // MARK: - Battery detail per device

    @ViewBuilder
    private func batteryDetail(_ device: AccessoryBatteryDeviceSnapshot) -> some View {
        Group {
            if device.isAirPodsStyle, let battery = device.battery {
                // AirPods: L / R / Case chips spread across the card.
                HStack(spacing: 0) {
                    ForEach(battery.cellValues, id: \.0) { label, value in
                        VStack(spacing: 2) {
                            Text(label)
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                                .tracking(0.3)
                            Text("\(value)%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(levelColor(value))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else if let percent = device.primaryPercent {
                // Single battery: percent hero + slim bar.
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(percent)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(levelColor(percent))

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.10))
                            Capsule()
                                .fill(levelColor(percent))
                                .frame(width: max(3, geo.size.width * CGFloat(percent) / 100))
                        }
                    }
                    .frame(height: 4)
                }
            } else {
                Text("No info")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    // MARK: - Info / empty / error state

    private func infoState(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(orange.opacity(0.8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Battery-level color

    /// Green when healthy, warming through yellow to red as it drains.
    private func levelColor(_ percent: Int) -> Color {
        let t = min(max(Double(percent) / 100, 0), 1)
        let green  = (r: 0.30, g: 0.85, b: 0.39)
        let yellow = (r: 0.98, g: 0.78, b: 0.24)
        let red    = (r: 0.93, g: 0.30, b: 0.26)

        func lerp(_ a: (r: Double, g: Double, b: Double),
                  _ b: (r: Double, g: Double, b: Double),
                  _ f: Double) -> Color {
            Color(red: a.r + (b.r - a.r) * f,
                  green: a.g + (b.g - a.g) * f,
                  blue: a.b + (b.b - a.b) * f)
        }

        // 0–40% red→yellow, 40–100% yellow→green.
        if t < 0.4 {
            return lerp(red, yellow, t / 0.4)
        } else {
            return lerp(yellow, green, (t - 0.4) / 0.6)
        }
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
                        isCharging: true,
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
                        id: "kbd",
                        name: "Magic Keyboard",
                        kind: .keyboard,
                        isConnected: true,
                        battery: .init(single: 9)
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
