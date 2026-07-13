//
//  WidgetPinStore.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation

enum WidgetPinStore {
    static func isPinned(_ widgetID: String, in pinnedWidgetIDs: [String]) -> Bool {
        pinnedWidgetIDs.contains(widgetID)
    }

    static func pin(_ widgetID: String, in pinnedWidgetIDs: [String]) -> [String] {
        guard !isPinned(widgetID, in: pinnedWidgetIDs) else {
            return pinnedWidgetIDs
        }

        return pinnedWidgetIDs + [widgetID]
    }

    static func unpin(_ widgetID: String, in pinnedWidgetIDs: [String]) -> [String] {
        pinnedWidgetIDs.filter { $0 != widgetID }
    }

    static func toggle(_ widgetID: String, in pinnedWidgetIDs: [String]) -> [String] {
        isPinned(widgetID, in: pinnedWidgetIDs)
            ? unpin(widgetID, in: pinnedWidgetIDs)
            : pin(widgetID, in: pinnedWidgetIDs)
    }
}
