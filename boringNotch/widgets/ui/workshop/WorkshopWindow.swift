//
//  WorkshopWindow.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

private enum WorkshopSection: String, CaseIterable, Identifiable {
    case browse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browse:
            return "Browse"
        }
    }

    var icon: String {
        switch self {
        case .browse:
            return "square.grid.2x2"
        }
    }
}

struct WorkshopWindow: View {
    @State private var selection: WorkshopSection? = .browse

    var body: some View {
        NavigationSplitView {
            List(WorkshopSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selection ?? .browse {
            case .browse:
                WorkshopBrowseView()
            }
        }
        .frame(minWidth: 820, idealWidth: 920, minHeight: 540, idealHeight: 620)
    }
}

#Preview {
    WorkshopWindow()
}
