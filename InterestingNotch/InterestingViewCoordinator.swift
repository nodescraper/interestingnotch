//
//  InterestingViewCoordinator.swift
//  InterestingNotch
//
//  Created by Alexander on 2024-11-20.
//

import AppKit
import Combine
import Defaults
import SwiftUI

enum SneakContentType {
    case brightness
    case volume
    case backlight
    case music
    case colorPicker
    case timer
    case systemMonitor
    case voiceRecorder
    case mic
    case battery
    case download
    case caffeine
}

struct sneakPeek {
    var show: Bool = false
    var type: SneakContentType = .music
    var value: CGFloat = 0
    var icon: String = ""
    var accent: Color? = nil
    var targetScreenUUID: String? = nil
    var message: String = ""
}

struct SharedSneakPeek: Codable {
    var show: Bool
    var type: String
    var value: String
    var icon: String
}

enum BrowserType {
    case chromium
    case safari
}

struct ExpandedItem {
    var show: Bool = false
    var type: SneakContentType = .battery
    var value: CGFloat = 0
    var browser: BrowserType = .chromium
}

/// Shared lifecycle for compact widget activities.
///
/// Widgets only publish whether they are active. This engine owns the visual
/// handoff: hide the activity while the notch opens, let the notch finish
/// closing, then reveal it with the same animation timing for every widget.
@MainActor
final class CompactSneakPeekEngine {
    private struct Input {
        let notchState: NotchState
        let isActive: Bool
        let activityID: String?
    }

    private var lastInputs: [String: Input] = [:]
    private var revealTasks: [String: Task<Void, Never>] = [:]
    private var removalTasks: [String: Task<Void, Never>] = [:]
    private(set) var revealedScreens: Set<String> = []
    private(set) var renderedScreens: Set<String> = []
    private var renderedActivityIDs: [String: String] = [:]
    var onRevealStateChanged: (() -> Void)?

    func update(
        screenUUID: String?,
        notchState: NotchState,
        isActive: Bool,
        activityID: String?
    ) {
        guard let screenUUID else { return }

        let previousInput = lastInputs[screenUUID]
        let input = Input(notchState: notchState, isActive: isActive, activityID: activityID)
        guard previousInput?.notchState != input.notchState
                || previousInput?.isActive != input.isActive
                || previousInput?.activityID != input.activityID
        else {
            return
        }
        lastInputs[screenUUID] = input
        revealTasks[screenUUID]?.cancel()

        if !isActive {
            setRevealed(false, for: screenUUID)
            scheduleRemoval(for: screenUUID)
            return
        }

        removalTasks[screenUUID]?.cancel()
        setRendered(true, for: screenUUID)

        let activityChanged = previousInput?.isActive == true
            && previousInput?.activityID != activityID
        if renderedActivityIDs[screenUUID] == nil || previousInput?.isActive != true {
            setRenderedActivityID(activityID, for: screenUUID)
        }

        switch notchState {
        case .open:
            setRevealed(false, for: screenUUID)
            // Once the notch opens, compact content should unmount immediately
            // so the full notch UI never shares space with the closed-notch
            // sneak peek during hover/open transitions.
            setRendered(false, for: screenUUID)
            setRenderedActivityID(activityID, for: screenUUID)

        case .closed:
            // Closing the notch or replacing one compact activity with another
            // always collapses first, then reveals the new activity through the
            // same engine animation.
            let needsHandoff = previousInput?.notchState == .open || activityChanged
            if needsHandoff {
                setRevealed(false, for: screenUUID)
                // Do not keep the outgoing view mounted while the full player
                // is being removed. Matched artwork geometry can otherwise
                // animate the compact player into view during the close.
                setRendered(false, for: screenUUID)
            } else {
                setRevealed(true, for: screenUUID)
            }

            let revealDelay = max(0.12, 0.45 / max(Defaults[.animationSpeedMultiplier], 0.1))
            revealTasks[screenUUID] = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(revealDelay))
                guard !Task.isCancelled, let self else { return }
                guard self.lastInputs[screenUUID]?.notchState == .closed,
                      self.lastInputs[screenUUID]?.isActive == true,
                      self.lastInputs[screenUUID]?.activityID == activityID else { return }
                // Mount only after the close animation has finished, while the
                // incoming activity is still hidden, then reveal it together.
                self.setRenderedActivityID(activityID, for: screenUUID)
                self.setRendered(true, for: screenUUID)
                self.setRevealed(true, for: screenUUID)
            }
        }
    }

    func shouldReveal(on screenUUID: String?) -> Bool {
        guard let screenUUID else { return false }
        return revealedScreens.contains(screenUUID)
    }

    func shouldRender(on screenUUID: String?) -> Bool {
        guard let screenUUID else { return false }
        return renderedScreens.contains(screenUUID)
    }

    func renderedActivityID(on screenUUID: String?) -> String? {
        guard let screenUUID else { return nil }
        return renderedActivityIDs[screenUUID]
    }

    private func scheduleRemoval(for screenUUID: String) {
        removalTasks[screenUUID]?.cancel()
        guard renderedScreens.contains(screenUUID) else { return }

        let closeDuration = Defaults[.enableOpeningAnimation]
            ? max(0.12, 0.5 / max(Defaults[.animationSpeedMultiplier], 0.1))
            : 0
        removalTasks[screenUUID] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(closeDuration))
            guard !Task.isCancelled, let self else { return }
            guard self.lastInputs[screenUUID]?.isActive == false else { return }
            self.setRendered(false, for: screenUUID)
        }
    }

    private func setRevealed(_ revealed: Bool, for screenUUID: String) {
        let changed: Bool
        if revealed {
            changed = revealedScreens.insert(screenUUID).inserted
        } else {
            changed = revealedScreens.remove(screenUUID) != nil
        }
        guard changed else { return }
        withAnimation(StandardAnimations.close) {
            onRevealStateChanged?()
        }
    }

    private func setRendered(_ rendered: Bool, for screenUUID: String) {
        let changed: Bool
        if rendered {
            changed = renderedScreens.insert(screenUUID).inserted
        } else {
            changed = renderedScreens.remove(screenUUID) != nil
        }
        guard changed else { return }
        onRevealStateChanged?()
    }

    private func setRenderedActivityID(_ activityID: String?, for screenUUID: String) {
        guard let activityID, renderedActivityIDs[screenUUID] != activityID else { return }
        renderedActivityIDs[screenUUID] = activityID
        onRevealStateChanged?()
    }
}

@MainActor
class InterestingViewCoordinator: ObservableObject {
    static let shared = InterestingViewCoordinator()

    enum TemporaryOpenContext: Equatable {
        case timerCompletion(widgetID: String)
    }

    @Published var currentView: NotchViews = .home {
        didSet {
            guard let context = temporaryOpenContext else { return }

            switch context {
            case .timerCompletion(let widgetID):
                if currentView != .widget(id: widgetID) {
                    temporaryOpenContext = nil
                }
            }
        }
    }
    @Published var helloAnimationRunning: Bool = false
    @Published private(set) var temporaryOpenContext: TemporaryOpenContext?
    private var sneakPeekDispatch: DispatchWorkItem?
    private var expandingViewDispatch: DispatchWorkItem?
    private var osdEnableTask: Task<Void, Never>?

    @AppStorage("firstLaunch") var firstLaunch: Bool = true
    @AppStorage("musicLiveActivityEnabled") var musicLiveActivityEnabled: Bool = true
    @AppStorage("currentMicStatus") var currentMicStatus: Bool = true

    @AppStorage("alwaysShowTabs") var alwaysShowTabs: Bool = true {
        didSet {
            if !alwaysShowTabs {
                openLastTabByDefault = false
                if ShelfStateViewModel.shared.isEmpty || !Defaults[.openShelfByDefault] {
                    currentView = .home
                }
            }
        }
    }

    @AppStorage("openLastTabByDefault") var openLastTabByDefault: Bool = false {
        didSet {
            if openLastTabByDefault {
                alwaysShowTabs = true
            }
        }
    }
    
    // Legacy storage for migration
    @AppStorage("preferred_screen_name") private var legacyPreferredScreenName: String?
    
    // New UUID-based storage
    @AppStorage("preferred_screen_uuid") var preferredScreenUUID: String? {
        didSet {
            if let uuid = preferredScreenUUID {
                selectedScreenUUID = uuid
            }
            NotificationCenter.default.post(name: Notification.Name.selectedScreenChanged, object: nil)
        }
    }

    @Published var selectedScreenUUID: String = NSScreen.main?.displayUUID ?? ""

    @Published var optionKeyPressed: Bool = true
    private var accessibilityObserver: Any?
    private var osdReplacementCancellable: AnyCancellable?
    private var interestingShelfCancellable: AnyCancellable?
    private var pinnedWidgetsCancellable: AnyCancellable?
    private var osdSourceCancellables: [AnyCancellable] = []

    private init() {
        // Perform migration from name-based to UUID-based storage
        if preferredScreenUUID == nil, let legacyName = legacyPreferredScreenName {
            // Try to find screen by name and migrate to UUID
            if let screen = NSScreen.screens.first(where: { $0.localizedName == legacyName }),
               let uuid = screen.displayUUID {
                preferredScreenUUID = uuid
                NSLog("✅ Migrated display preference from name '\(legacyName)' to UUID '\(uuid)'")
            } else {
                // Fallback to main screen if legacy screen not found
                preferredScreenUUID = NSScreen.main?.displayUUID
                NSLog("⚠️ Could not find display named '\(legacyName)', falling back to main screen")
            }
            // Clear legacy value after migration
            legacyPreferredScreenName = nil
        } else if preferredScreenUUID == nil {
            // No legacy value, use main screen
            preferredScreenUUID = NSScreen.main?.displayUUID
        }
        
        selectedScreenUUID = preferredScreenUUID ?? NSScreen.main?.displayUUID ?? ""
        // Observe changes to accessibility authorization and react accordingly
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.accessibilityAuthorizationChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if Defaults[.osdReplacement] {
                    await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
                }
            }
        }

        XPCHelperClient.shared.startMonitoringAccessibilityAuthorization()

        // Observe changes to osdReplacement
        osdReplacementCancellable = Defaults.publisher(.osdReplacement)
            .sink { [weak self] change in
                Task { @MainActor in
                    guard let self = self else { return }

                    self.osdEnableTask?.cancel()
                    self.osdEnableTask = nil

                    if change.newValue {
                        self.osdEnableTask = Task { @MainActor in
                            let granted = await MediaKeyInterceptor.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
                            guard !Task.isCancelled else { return }

                            if granted {
                                await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
                            }
                        }
                    } else {
                        MediaKeyInterceptor.shared.stop()
                    }
                    
                    self.applyOSDSources()
                }
            }
        // Observe changes to any of the OSD source selections
        osdSourceCancellables = [
            Defaults.publisher(.osdBrightnessSource).sink { [weak self] _ in Task { @MainActor in self?.applyOSDSources() } },
            Defaults.publisher(.osdVolumeSource).sink { [weak self] _ in Task { @MainActor in self?.applyOSDSources() } }
        ]
        interestingShelfCancellable = Defaults.publisher(.interestingShelf)
            .sink { [weak self] change in
                Task { @MainActor in
                    guard let self = self else { return }
                    if !change.newValue && self.currentView == .shelf {
                        self.currentView = .home
                    }
                }
            }
        pinnedWidgetsCancellable = Defaults.publisher(.pinnedWidgetIDs)
            .sink { [weak self] change in
                Task { @MainActor in
                    self?.sanitizeCurrentView(pinnedWidgetIDs: change.newValue)
                }
            }

        Task { @MainActor in
            if Defaults[.osdReplacement] {
                await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
            }
            self.applyOSDSources()
        }

        compactSneakPeekEngine.onRevealStateChanged = { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    @objc func sneakPeekEvent(_ notification: Notification) {
        let decoder = JSONDecoder()
        if let decodedData = try? decoder.decode(
            SharedSneakPeek.self, from: notification.userInfo?.first?.value as! Data)
        {
            let contentType =
                decodedData.type == "brightness"
                ? SneakContentType.brightness
                : decodedData.type == "volume"
                    ? SneakContentType.volume
                    : decodedData.type == "backlight"
                        ? SneakContentType.backlight
                        : decodedData.type == "mic"
                            ? SneakContentType.mic : SneakContentType.brightness

            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.numberStyle = .decimal
            let value = CGFloat((formatter.number(from: decodedData.value) ?? 0.0).floatValue)
            let icon = decodedData.icon

            print("Decoded: \(decodedData), Parsed value: \(value)")

            toggleSneakPeek(status: decodedData.show, type: contentType, value: value, icon: icon)

        } else {
            print("Failed to decode JSON data")
        }
    }

    // MARK: - Per-Screen Sneak Peek Management

    // Dictionary to hold sneak peek state for each screen UUID
    @Published var sneakPeekStates: [String: sneakPeek] = [:]
    
    // Dictionary to hold hide tasks for each screen UUID
    private var sneakPeekTasks: [String: Task<Void, Never>] = [:]
    let compactSneakPeekEngine = CompactSneakPeekEngine()
    
    // Default duration
    private var defaultSneakPeekDuration: TimeInterval = 1.5

    private func isDisabledWidgetSneakPeek(_ type: SneakContentType) -> Bool {
        switch type {
        case .timer, .systemMonitor:
            return true
        default:
            return false
        }
    }

    func toggleSneakPeek(
        status: Bool, type: SneakContentType, duration: TimeInterval = 1.5, value: CGFloat = 0,
        icon: String = "", accent: Color? = nil, targetScreenUUID: String? = nil, message: String = ""
    ) {
        if isDisabledWidgetSneakPeek(type) {
            Task { @MainActor in
                @MainActor
                func hideState(for uuid: String) {
                    var state = self.sneakPeekStates[uuid] ?? sneakPeek(targetScreenUUID: uuid)
                    withAnimation(.smooth) {
                        state.show = false
                        state.type = type
                        state.targetScreenUUID = uuid
                        self.sneakPeekStates[uuid] = state
                    }
                    self.sneakPeekTasks[uuid]?.cancel()
                    self.sneakPeekTasks[uuid] = nil
                }

                if let targetUUID = targetScreenUUID {
                    hideState(for: targetUUID)
                } else {
                    let screens = NSScreen.screens.compactMap { $0.displayUUID }
                    if screens.isEmpty, let mainUUID = NSScreen.main?.displayUUID {
                        hideState(for: mainUUID)
                    } else {
                        for uuid in screens {
                            hideState(for: uuid)
                        }
                    }
                }
            }
            return
        }

        if type != .music && type != .voiceRecorder && type != .caffeine {
            // close()
            if !Defaults[.osdReplacement] {
                return
            }
        }
        
        Task { @MainActor in
            // Helper to update state for a specific UUID
            @MainActor
            func updateState(for uuid: String) {
                // If we don't have a state for this screen yet, initialize it
                var state = self.sneakPeekStates[uuid] ?? sneakPeek(targetScreenUUID: uuid)
                
                withAnimation(.smooth) {
                    state.show = status
                    state.type = type
                    state.value = value
                    state.icon = icon
                    state.accent = accent
                    state.message = message
                    state.targetScreenUUID = uuid // Ensure UUID is set
                    self.sneakPeekStates[uuid] = state
                }
                
                if status {
                    if duration <= 0 {
                        self.sneakPeekTasks[uuid]?.cancel()
                        self.sneakPeekTasks[uuid] = nil
                    } else {
                        self.scheduleSneakPeekHide(for: uuid, duration: duration)
                    }
                } else {
                    self.sneakPeekTasks[uuid]?.cancel()
                    self.sneakPeekTasks[uuid] = nil
                }
            }
            
            if let targetUUID = targetScreenUUID {
                // Update specific screen
                updateState(for: targetUUID)
            } else {
                // Update ALL connected screens + the main screen as fallback
                // We use known screen UUIDs from NSScreen
                let screens = NSScreen.screens.compactMap { $0.displayUUID }
                if screens.isEmpty {
                    // Fallback if no screens detected (unlikely in UI app but safe)
                     if let mainUUID = NSScreen.main?.displayUUID {
                         updateState(for: mainUUID)
                     }
                } else {
                    for uuid in screens {
                        updateState(for: uuid)
                    }
                }
            }
        }

        if type == .mic {
            currentMicStatus = value == 1
        }
    }

     func applyOSDSources() {
        if NotchSpaceManager.shared.notchSpace.windows.isEmpty {
            BetterDisplayManager.shared.stopObserving()
            LunarManager.shared.stopListening()
            LunarManager.shared.configureLunarOSD(hide: false)
            MediaKeyInterceptor.shared.stop()
            return
        }

        guard Defaults[.osdReplacement] else {
            BetterDisplayManager.shared.stopObserving()
            LunarManager.shared.stopListening()
            LunarManager.shared.configureLunarOSD(hide: false)
            MediaKeyInterceptor.shared.stop()
            return
        }

        let brightness = Defaults[.osdBrightnessSource]
        let volume = Defaults[.osdVolumeSource]

        Task { @MainActor in
            await MediaKeyInterceptor.shared.start(promptIfNeeded: false)
        }
        // BetterDisplay is used when either brightness or volume is set to it
        if brightness == .betterDisplay || volume == .betterDisplay {
            BetterDisplayManager.shared.startObserving()
        } else {
            BetterDisplayManager.shared.stopObserving()
        }

        // Lunar only supports brightness; disable Lunar's OSD when we replace it, restore when we don't
        if brightness == .lunar {
            LunarManager.shared.configureLunarOSD(hide: true)
            LunarManager.shared.startListening()
        } else {
            LunarManager.shared.stopListening()
            LunarManager.shared.configureLunarOSD(hide: false)
        }
    }

    func shouldShowSneakPeek(on screenUUID: String?) -> Bool {
        guard let uuid = screenUUID else { return false }
        return sneakPeekStates[uuid]?.show == true
    }

    func updateCompactSneakPeekLifecycle(
        on screenUUID: String?, notchState: NotchState, isActive: Bool, activityID: String?
    ) {
        compactSneakPeekEngine.update(
            screenUUID: screenUUID,
            notchState: notchState,
            isActive: isActive,
            activityID: activityID
        )
        objectWillChange.send()
    }

    func shouldRevealCompactSneakPeek(on screenUUID: String?) -> Bool {
        compactSneakPeekEngine.shouldReveal(on: screenUUID)
    }

    func shouldRenderCompactSneakPeek(on screenUUID: String?) -> Bool {
        compactSneakPeekEngine.shouldRender(on: screenUUID)
    }

    func renderedCompactSneakPeekActivityID(on screenUUID: String?) -> String? {
        compactSneakPeekEngine.renderedActivityID(on: screenUUID)
    }
    
    var isAnySneakPeekShowing: Bool {
        return sneakPeekStates.values.contains { $0.show }
    }
    
    // Helper to get state safely for binding/reading
    func sneakPeekState(for screenUUID: String?) -> sneakPeek {
        guard let uuid = screenUUID else { return sneakPeek() }
        return sneakPeekStates[uuid] ?? sneakPeek(targetScreenUUID: uuid)
    }
    
    // Helper to get binding for SwiftUI views
    func binding(for screenUUID: String?) -> Binding<sneakPeek> {
        Binding(
            get: { [weak self] in
                guard let self = self, let uuid = screenUUID else { return sneakPeek() }
                return self.sneakPeekStates[uuid] ?? sneakPeek(targetScreenUUID: uuid)
            },
            set: { [weak self] newValue in
                guard let self = self, let uuid = screenUUID else { return }
                self.sneakPeekStates[uuid] = newValue
            }
        )
    }

    private func scheduleSneakPeekHide(for screenUUID: String, duration: TimeInterval) {
        sneakPeekTasks[screenUUID]?.cancel()

        sneakPeekTasks[screenUUID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self = self, !Task.isCancelled else { return }
            
            await MainActor.run {
                withAnimation {
                    // We only want to hide it, not reset everything instantly which might cause glitches
                    if var state = self.sneakPeekStates[screenUUID] {
                         state.show = false
                         // Optional: reset type to something default if needed, but keeping last state is often fine until next show
                         // keeping original logic:
                         state.type = .music 
                         self.sneakPeekStates[screenUUID] = state
                    }
                }
            }
        }
    }

    func toggleExpandingView(
        status: Bool,
        type: SneakContentType,
        value: CGFloat = 0,
        browser: BrowserType = .chromium
    ) {
        Task { @MainActor in
            withAnimation(.smooth) {
                self.expandingView.show = status
                self.expandingView.type = type
                self.expandingView.value = value
                self.expandingView.browser = browser
            }
        }
    }

    private var expandingViewTask: Task<Void, Never>?

    @Published var expandingView: ExpandedItem = .init() {
        didSet {
            if expandingView.show {
                expandingViewTask?.cancel()
                let duration: TimeInterval = (expandingView.type == .download ? 2 : 3)
                let currentType = expandingView.type
                expandingViewTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(duration))
                    guard let self = self, !Task.isCancelled else { return }
                    self.toggleExpandingView(status: false, type: currentType)
                }
            } else {
                expandingViewTask?.cancel()
            }
        }
    }
    
    func showEmpty() {
        currentView = .home
    }

    var shouldKeepNotchOpenWithoutHover: Bool {
        temporaryOpenContext != nil
    }

    func presentTimerCompletion(widgetID: String) {
        currentView = .widget(id: widgetID)
        temporaryOpenContext = .timerCompletion(widgetID: widgetID)
    }

    func dismissTemporaryOpenContext(for widgetID: String? = nil) {
        guard let context = temporaryOpenContext else { return }

        switch context {
        case .timerCompletion(let presentedWidgetID):
            guard widgetID == nil || widgetID == presentedWidgetID else { return }
            if currentView == .widget(id: presentedWidgetID) {
                currentView = .home
            }
            temporaryOpenContext = nil
        }
    }

    private func sanitizeCurrentView(pinnedWidgetIDs: [String]) {
        guard case .widget(let id) = currentView else { return }

        if !pinnedWidgetIDs.contains(id) {
            currentView = .home
        }
    }
}
