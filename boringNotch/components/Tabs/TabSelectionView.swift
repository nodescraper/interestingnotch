//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    let label: String
    let icon: String
    let view: NotchViews

    var id: String { view.stableID }
}

private enum WidgetTabStripItem: Identifiable {
    case tab(TabModel)
    case previousPage
    case nextPage

    var id: String {
        switch self {
        case .tab(let model):
            return model.id
        case .previousPage:
            return "widget-page-previous"
        case .nextPage:
            return "widget-page-next"
        }
    }
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var widgetEngine = WidgetEngine.shared
    @Default(.pinnedWidgetIDs) var pinnedWidgetIDs
    @Default(.boringShelf) var boringShelf
    @State private var widgetPageIndex = 0
    @Namespace var animation

    private let maxWidgetTabsBeforePaging = 3

    private var primaryTabs: [TabModel] {
        [
            TabModel(label: "Home", icon: "house.fill", view: .home),
        ]
    }

    private var secondaryTabs: [TabModel] {
        var tabs: [TabModel] = []

        if boringShelf {
            tabs.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
        }

        let widgetTabs = WidgetTabResolver
            .descriptors(
                pinnedWidgetIDs: pinnedWidgetIDs,
                availableWidgets: WidgetTabResolver.sources(from: widgetEngine.widgets)
            )
            .map { descriptor in
                TabModel(label: descriptor.title, icon: descriptor.icon, view: descriptor.view)
            }

        tabs.append(contentsOf: widgetTabs)
        return tabs
    }

    private var widgetPageCount: Int {
        widgetPageStartIndices.count
    }

    private var normalizedWidgetPageIndex: Int {
        min(widgetPageIndex, max(0, widgetPageCount - 1))
    }

    private var widgetPageStartIndices: [Int] {
        guard !secondaryTabs.isEmpty else { return [0] }
        guard secondaryTabs.count > maxWidgetTabsBeforePaging else { return [0] }

        var starts = [0]
        var currentIndex = 3

        while currentIndex < secondaryTabs.count {
            starts.append(currentIndex)

            let remainingAfterThisPage = secondaryTabs.count - currentIndex
            currentIndex += remainingAfterThisPage > 3 ? 2 : 3
        }

        return starts
    }

    private var visibleWidgetItems: [WidgetTabStripItem] {
        guard !secondaryTabs.isEmpty else { return [] }
        guard secondaryTabs.count > maxWidgetTabsBeforePaging else {
            return secondaryTabs.map(WidgetTabStripItem.tab)
        }

        let pageIndex = normalizedWidgetPageIndex
        let isFirstPage = pageIndex == 0
        let isLastPage = pageIndex == widgetPageCount - 1
        let startIndex = widgetPageStartIndices[pageIndex]
        let visibleCount = isFirstPage || isLastPage ? 3 : 2
        let endIndex = min(startIndex + visibleCount, secondaryTabs.count)

        var items: [WidgetTabStripItem] = []

        if !isFirstPage {
            items.append(.previousPage)
        }

        items.append(contentsOf: secondaryTabs[startIndex..<endIndex].map(WidgetTabStripItem.tab))

        if !isLastPage {
            items.append(.nextPage)
        }

        return items
    }

    private var tabs: [WidgetTabStripItem] {
        primaryTabs.map(WidgetTabStripItem.tab) + visibleWidgetItems
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                switch tab {
                case .tab(let model):
                    TabButton(label: model.label, icon: model.icon, selected: coordinator.currentView == model.view) {
                        withAnimation(.smooth) {
                            coordinator.currentView = model.view
                        }
                    }
                    .frame(height: 26)
                    .foregroundStyle(model.view == coordinator.currentView ? .white : .gray)
                    .background {
                        if model.view == coordinator.currentView {
                            Capsule()
                                .fill(coordinator.currentView == model.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(coordinator.currentView == model.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
                case .previousPage:
                    pagerButton(icon: "chevron.left") {
                        withAnimation(.smooth) {
                            widgetPageIndex = max(0, normalizedWidgetPageIndex - 1)
                        }
                    }
                case .nextPage:
                    pagerButton(icon: "chevron.right") {
                        withAnimation(.smooth) {
                            widgetPageIndex = min(widgetPageCount - 1, normalizedWidgetPageIndex + 1)
                        }
                    }
                }
            }
        }
        .clipShape(Capsule())
        .onAppear {
            syncWidgetPageToSelection()
        }
        .onChange(of: pinnedWidgetIDs) { _, _ in
            widgetPageIndex = min(widgetPageIndex, max(0, widgetPageCount - 1))
            syncWidgetPageToSelection()
        }
        .onChange(of: coordinator.currentView) { _, _ in
            syncWidgetPageToSelection()
        }
    }

    private func pagerButton(icon: String, action: @escaping () -> Void) -> some View {
        TabButton(label: "", icon: icon, selected: false, onClick: action)
            .frame(height: 26)
            .foregroundStyle(.gray)
    }

    private func syncWidgetPageToSelection() {
        guard let selectedTabIndex = secondaryTabs.firstIndex(where: { $0.view == coordinator.currentView }) else { return }
        guard secondaryTabs.count > maxWidgetTabsBeforePaging else { return }

        let resolvedPage = widgetPageStartIndices.lastIndex(where: { $0 <= selectedTabIndex }) ?? 0
        widgetPageIndex = min(resolvedPage, max(0, widgetPageCount - 1))
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
