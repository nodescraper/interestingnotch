//
//  WidgetLaunchLoader.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import Foundation

@MainActor
protocol WidgetStoreLoading {
    @discardableResult
    func loadAll() -> WidgetStoreLoadResult
}

extension WidgetStore: WidgetStoreLoading {}

@MainActor
struct WidgetLaunchLoader {
    private let store: any WidgetStoreLoading

    init(store: (any WidgetStoreLoading)? = nil) {
        self.store = store ?? WidgetStore.shared
    }

    @discardableResult
    func loadWidgets() -> WidgetStoreLoadResult {
        store.loadAll()
    }
}
