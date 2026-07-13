//
//  WorkshopWindow.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

private enum WorkshopSection: String, CaseIterable, Identifiable {
    case browse
    case installed

    var id: Self { self }

    var title: String {
        switch self {
        case .browse: "Browse"
        case .installed: "Installed"
        }
    }

    var systemImage: String {
        switch self {
        case .browse: "square.grid.2x2"
        case .installed: "checklist"
        }
    }
}

struct WorkshopWindow: View {
    @State private var selectedSection: WorkshopSection = .browse

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(WorkshopSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .listStyle(SidebarListStyle())
            .tint(.effectiveAccent)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selectedSection {
                case .browse:
                    WorkshopBrowseView()
                case .installed:
                    WorkshopInstalledView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 760, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
        .tint(.effectiveAccent)
    }
}

#Preview {
    WorkshopWindow()
}
