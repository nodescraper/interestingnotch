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

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var widgetEngine = WidgetEngine.shared
    @Default(.pinnedWidgetIDs) var pinnedWidgetIDs
    @Default(.boringShelf) var boringShelf
    @Namespace var animation

    private var tabs: [TabModel] {
        var baseTabs = [
            TabModel(label: "Home", icon: "house.fill", view: .home),
        ]

        if boringShelf {
            baseTabs.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
        }

        let widgetTabs = WidgetTabResolver
            .descriptors(
                pinnedWidgetIDs: pinnedWidgetIDs,
                availableWidgets: WidgetTabResolver.sources(from: widgetEngine.widgets)
            )
            .map { descriptor in
                TabModel(label: descriptor.title, icon: descriptor.icon, view: descriptor.view)
            }

        return baseTabs + widgetTabs
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                    TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                        withAnimation(.smooth) {
                            coordinator.currentView = tab.view
                        }
                    }
                    .frame(height: 26)
                    .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                    .background {
                        if tab.view == coordinator.currentView {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
            }
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
