//
//  IconLabelTemplate.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import AppKit
import SwiftUI

struct IconLabelTemplate: View {
    let icon: String
    let label: String
    let accentColor: Color
    let status: WidgetStatus

    var body: some View {
        WidgetTemplateCard(status: status, accentColor: accentColor) {
            HStack(alignment: .center, spacing: 12) {
                iconBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryText)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(secondaryText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(primaryText))
        .accessibilityValue(Text(secondaryText))
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
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

    private var primaryText: String {
        if case .disabled = status {
            return "Widget disabled"
        }

        return label
    }

    private var secondaryText: String {
        switch status {
        case .loading:
            return "Waiting for first update"
        case .ok:
            return "Ready at a glance"
        case .error(let message):
            return message
        case .disabled:
            return "Enable it in Workshop"
        }
    }
}

#Preview("OK") {
    IconLabelTemplate(
        icon: "arrow.triangle.branch",
        label: "3 changes waiting",
        accentColor: .effectiveAccent,
        status: .ok
    )
}

#Preview("Loading") {
    IconLabelTemplate(
        icon: "arrow.triangle.branch",
        label: "Git status",
        accentColor: ColorToken.good.resolve(),
        status: .loading
    )
}

#Preview("Error") {
    IconLabelTemplate(
        icon: "shippingbox",
        label: "Brew updates",
        accentColor: ColorToken.warn.resolve(),
        status: .error("brew not found in PATH")
    )
}
