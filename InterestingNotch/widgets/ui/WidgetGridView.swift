//
//  WidgetGridView.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

struct WidgetGridView<Content: View>: View {
    let widgets: [Widget]
    let emptyIcon: String
    let emptyTitle: String
    let emptyMessage: String
    let content: (Widget) -> Content

    private let columns = [
        GridItem(.adaptive(minimum: 176, maximum: 220), spacing: 12, alignment: .top),
    ]

    init(
        widgets: [Widget],
        emptyIcon: String,
        emptyTitle: String,
        emptyMessage: String,
        @ViewBuilder content: @escaping (Widget) -> Content
    ) {
        self.widgets = widgets
        self.emptyIcon = emptyIcon
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.content = content
    }

    var body: some View {
        ScrollView {
            if widgets.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(widgets, id: \.id) { widget in
                        content(widget)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
            }
        }
        .scrollIndicators(.never)
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1.5, dash: [8]))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.03))
            )
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: emptyIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.effectiveAccent.opacity(0.9))

                    Text(emptyTitle)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(emptyMessage)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
    }
}
