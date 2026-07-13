//
//  ProgressTemplate.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import AppKit
import SwiftUI

struct ProgressTemplate: View {
    let icon: String
    let label: String
    let value: Double
    let accentColor: Color
    let status: WidgetStatus

    private var clampedValue: Double {
        min(max(value, 0), 100)
    }

    private var fillFraction: CGFloat {
        CGFloat(clampedValue / 100)
    }

    var body: some View {
        WidgetTemplateCard(status: status, accentColor: accentColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    iconBadge

                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(statusMessage)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Text(percentageText)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isError ? Color(nsColor: .systemRed) : .primary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.09))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accentColor,
                                        accentColor.opacity(0.6),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * fillFraction)
                            .opacity(barOpacity)
                    }
                }
                .frame(height: 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(percentageText))
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(isError ? 0.12 : 0.18))
                .frame(width: 42, height: 42)

            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isError ? Color(nsColor: .systemRed) : accentColor)
        }
    }

    private var isError: Bool {
        if case .error = status {
            return true
        }

        return false
    }

    private var percentageText: String {
        "\(Int(clampedValue.rounded()))%"
    }

    private var statusMessage: String {
        switch status {
        case .loading:
            return "Collecting baseline"
        case .ok:
            return "Current level"
        case .error(let message):
            return message
        case .disabled:
            return "Updates paused"
        }
    }

    private var barOpacity: Double {
        switch status {
        case .loading:
            return 0.45
        case .ok:
            return 1
        case .error:
            return 0.3
        case .disabled:
            return 0.2
        }
    }
}

#Preview("Progress") {
    ProgressTemplate(
        icon: "battery.100",
        label: "Battery health",
        value: 86,
        accentColor: ColorToken.good.resolve(),
        status: .ok
    )
}

#Preview("Progress Loading") {
    ProgressTemplate(
        icon: "gauge.with.needle",
        label: "Codex usage",
        value: 32,
        accentColor: .effectiveAccent,
        status: .loading
    )
}

#Preview("Progress Error") {
    ProgressTemplate(
        icon: "cpu",
        label: "CPU load",
        value: 0,
        accentColor: ColorToken.warn.resolve(),
        status: .error("provider unavailable")
    )
}
