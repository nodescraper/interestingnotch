//
//  WorkshopWindow.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import Defaults
import SwiftUI

private enum WorkshopSection: String, CaseIterable, Identifiable {
    case browse
    case mirror
    case shelf
    case calendar
    case media
    case sports
    case customWidgets

    var id: Self { self }

    var title: String {
        switch self {
        case .browse: "Widgets"
        case .mirror: "Mirror"
        case .shelf: "Shelf"
        case .calendar: "Calendar"
        case .media: "Media"
        case .sports: "Sports"
        case .customWidgets: "Custom Widgets"
        }
    }

    var systemImage: String {
        switch self {
        case .browse: "square.grid.2x2"
        case .mirror: "camera"
        case .shelf: "books.vertical"
        case .calendar: "calendar"
        case .media: "play.circle.fill"
        case .sports: "sportscourt"
        case .customWidgets: "sparkles.rectangle.stack"
        }
    }
}

private enum WorkshopSelection: Hashable {
    case section(WorkshopSection)
    case installedWidget(String)
}

struct WorkshopWindow: View {
    @ObservedObject private var engine = WidgetEngine.shared
    @Default(.pinnedWidgetIDs) private var pinnedWidgetIDs
    @State private var selectedSection: WorkshopSelection = .section(.browse)
    @State private var browseResetID = UUID()
    @State private var widgetsLoaded = false

    private var installedWidgets: [Widget] {
        pinnedWidgetIDs.compactMap { id in
            engine.widgets.first(where: { $0.id == id })
        }
    }

    private var selectedWidgetTitle: String? {
        guard case .installedWidget(let widgetID) = selectedSection else { return nil }
        return engine.widgets.first(where: { $0.id == widgetID })?.manifest.name ?? "Widget"
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("Widget Library") {
                    workshopSidebarItem(.browse)
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
                case .section(.browse):
                    WorkshopBrowseView { widgetID in
                        selectedSection = .installedWidget(widgetID)
                    }
                    .id(browseResetID)
                case .section(.mirror):
                    MirrorSettings()
                case .section(.shelf):
                    Shelf()
                case .section(.calendar):
                    CalendarSettings()
                case .section(.media):
                    Media()
                case .section(.sports):
                    SportsSettingsView()
                case .section(.customWidgets):
                    CustomWidgetsSettingsView()
                case .installedWidget(let widgetID):
                    WorkshopInstalledWidgetDetailView(widgetID: widgetID)
                }
            }
            .navigationTitle("")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            if selectedWidgetTitle != nil {
                ToolbarItem(placement: .navigation) {
                    Button {
                        browseResetID = UUID()
                        selectedSection = .section(.browse)
                    } label: {
                        Label("Widgets", systemImage: "chevron.left")
                    }
                    .help("Back to Widgets")
                }
            }

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
        .onChange(of: pinnedWidgetIDs) { _, newPinnedWidgetIDs in
            if case .installedWidget(let widgetID) = selectedSection,
               !newPinnedWidgetIDs.contains(widgetID) {
                selectedSection = .section(.browse)
            }
        }
    }

    @ViewBuilder
    private func workshopSidebarItem(_ section: WorkshopSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .tag(WorkshopSelection.section(section))
    }
}

private struct WorkshopInstalledWidgetDetailView: View {
    @ObservedObject private var engine = WidgetEngine.shared
    @Default(.pinnedWidgetIDs) private var pinnedWidgetIDs

    let widgetID: String

    private var widget: Widget? {
        engine.widgets.first(where: { $0.id == widgetID })
    }

    var body: some View {
        Group {
            if widgetID == "sports" {
                SportsSettingsView()
            } else if let widget {
                Form {
                    WorkshopInstalledSettingsRegistry.settingsSection(
                        for: widget,
                        pinnedWidgetIDs: $pinnedWidgetIDs
                    )
                }
                .accentColor(.effectiveAccent)
                .navigationTitle(widget.manifest.name)
            } else {
                ContentUnavailableView(
                    "Widget Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This pinned widget is no longer available.")
                )
            }
        }
    }
}

#Preview {
    WorkshopWindow()
}
