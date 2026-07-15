//
//  WorkshopWindow.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import SwiftUI

private enum WorkshopSection: String, CaseIterable, Identifiable {
    case browse
    case installed
    case mirror
    case shelf
    case calendar
    case media
    case customWidgets

    var id: Self { self }

    var title: String {
        switch self {
        case .browse: "Browse"
        case .installed: "Installed"
        case .mirror: "Mirror"
        case .shelf: "Shelf"
        case .calendar: "Calendar"
        case .media: "Media"
        case .customWidgets: "Custom Widgets"
        }
    }

    var systemImage: String {
        switch self {
        case .browse: "square.grid.2x2"
        case .installed: "checklist"
        case .mirror: "camera"
        case .shelf: "books.vertical"
        case .calendar: "calendar"
        case .media: "play.circle.fill"
        case .customWidgets: "sparkles.rectangle.stack"
        }
    }
}

struct WorkshopWindow: View {
    @State private var selectedSection: WorkshopSection = .browse
    @State private var widgetsLoaded = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("Widget Library") {
                    workshopSidebarItem(.browse)
                    workshopSidebarItem(.installed)
                }

                Section("Built-in Widgets") {
                    workshopSidebarItem(.mirror)
                    workshopSidebarItem(.shelf)
                    workshopSidebarItem(.calendar)
                    workshopSidebarItem(.media)
                }
                Section("Beta") {
                    workshopSidebarItem(.customWidgets)
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
                case .mirror:
                    MirrorSettings()
                case .shelf:
                    Shelf()
                case .calendar:
                    CalendarSettings()
                case .media:
                    Media()
                case .customWidgets:
                    CustomWidgetsSettingsView()
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
        .task {
            guard !widgetsLoaded else { return }
            widgetsLoaded = true
            WidgetLaunchLoader().loadWidgets()
        }
    }

    @ViewBuilder
    private func workshopSidebarItem(_ section: WorkshopSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .tag(section)
    }
}

#Preview {
    WorkshopWindow()
}
