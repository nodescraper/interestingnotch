//
//  WidgetTabResolver.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation

struct WidgetTabDescriptor: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let icon: String

    var view: NotchViews {
        .widget(id: id)
    }
}

struct WidgetTabSource: Equatable, Hashable {
    let id: String
    let title: String
    let icon: String
}

enum WidgetTabResolver {
    static func descriptors(
        pinnedWidgetIDs: [String],
        availableWidgets: [WidgetTabSource]
    ) -> [WidgetTabDescriptor] {
        let sourcesByID = Dictionary(uniqueKeysWithValues: availableWidgets.map { ($0.id, $0) })

        return pinnedWidgetIDs.compactMap { id in
            guard let source = sourcesByID[id] else { return nil }

            return WidgetTabDescriptor(
                id: source.id,
                title: source.title,
                icon: source.icon
            )
        }
    }

    @MainActor
    static func sources(from widgets: [Widget]) -> [WidgetTabSource] {
        widgets.map { widget in
            WidgetTabSource(
                id: widget.id,
                title: widget.manifest.name,
                icon: WidgetSlotRenderer.resolvedString(
                    forSlotNamed: "icon",
                    in: widget.manifest.render.slots,
                    value: widget.lastValue,
                    fallback: "square.grid.2x2"
                )
            )
        }
    }
}
