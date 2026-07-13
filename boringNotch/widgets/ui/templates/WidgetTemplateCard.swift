//
//  WidgetTemplateCard.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import AppKit
import SwiftUI

struct WidgetTemplateCard<Content: View>: View {
    let status: WidgetStatus
    let accentColor: Color
    let content: Content

    init(
        status: WidgetStatus,
        accentColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.status = status
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            content
        }
        .padding(14)
        .frame(width: 176, alignment: .topLeading)
        .frame(minHeight: 104, alignment: .topLeading)
        .background(backgroundFill)
        .overlay(borderOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: accentColor.opacity(status == .ok ? 0.12 : 0.06), radius: 14, y: 8)
        .opacity(contentOpacity)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusTint)
                .frame(width: 8, height: 8)

            Text(statusTitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer(minLength: 0)

            if case .error = status {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(statusTint)
            }
        }
    }

    private var backgroundFill: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor).opacity(0.98),
                Color(nsColor: .controlBackgroundColor).opacity(0.94),
                accentColor.opacity(status == .ok ? 0.08 : 0.04),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.28),
                        Color.white.opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var statusTitle: String {
        switch status {
        case .loading:
            return "Loading"
        case .ok:
            return "Live"
        case .error:
            return "Error"
        case .disabled:
            return "Disabled"
        }
    }

    private var statusTint: Color {
        switch status {
        case .loading:
            return .secondary
        case .ok:
            return accentColor
        case .error:
            return Color(nsColor: .systemRed)
        case .disabled:
            return Color(nsColor: .tertiaryLabelColor)
        }
    }

    private var contentOpacity: Double {
        switch status {
        case .loading:
            return 0.82
        case .ok:
            return 1
        case .error:
            return 0.94
        case .disabled:
            return 0.6
        }
    }
}
