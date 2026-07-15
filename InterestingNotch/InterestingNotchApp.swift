//
//  InterestingNotchApp.swift
//  InterestingNotchApp
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//

import AVFoundation
import AppKit
import Combine
import Defaults
import KeyboardShortcuts
import Sparkle
import SwiftUI

@main
struct DynamicNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Default(.menubarIcon) var showMenuBarIcon
    @Environment(\.openWindow) var openWindow

    private let sparkleUpdaterDelegate: InterestingSparkleUpdaterDelegate
    let updaterController: SPUStandardUpdaterController

    init() {
        let sparkleUpdaterDelegate = InterestingSparkleUpdaterDelegate()
        self.sparkleUpdaterDelegate = sparkleUpdaterDelegate
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: sparkleUpdaterDelegate, userDriverDelegate: nil)
        SoftwareUpdateStore.updater = updaterController.updater

        // Initialize the settings window controller with the updater controller
        SettingsWindowController.shared.setUpdaterController(updaterController)
    }

    var body: some Scene {
        MenuBarExtra("InterestingNotch", systemImage: "sparkle", isInserted: $showMenuBarIcon) {
            Button("Workshop") {
                DispatchQueue.main.async {
                    WorkshopWindowController.shared.showWindow()
                }
            }
            Button("Settings") {
                DispatchQueue.main.async {
                    SettingsWindowController.shared.showWindow()
                }
            }
            .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            CheckForUpdatesView(updater: updaterController.updater)
            Divider()
            Button("Restart InterestingNotch") {
                ApplicationRelauncher.restart()
            }
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(self)
            }
            .keyboardShortcut(KeyEquivalent("Q"), modifiers: .command)
        }
    }
}

@MainActor
enum SoftwareUpdateStore {
    static var updater: SPUUpdater?
}

@MainActor
final class InterestingSparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool {
        false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windows: [String: NSWindow] = [:] // UUID -> NSWindow
    var viewModels: [String: InterestingViewModel] = [:] // UUID -> InterestingViewModel
    var window: NSWindow?
    let vm: InterestingViewModel = .init()
    @ObservedObject var coordinator = InterestingViewCoordinator.shared
    var quickShareService = QuickShareService.shared
    var whatsNewWindow: NSWindow?
    var timer: Timer?
    var closeNotchTask: Task<Void, Never>?
    private var previousScreens: [NSScreen]?
    private var onboardingWindowController: NSWindowController?
    private var screenLockedObserver: Any?
    private var screenUnlockedObserver: Any?
    private var isScreenLocked: Bool = false
    private var windowScreenDidChangeObserver: Any?
    private var dragDetectors: [String: DragDetector] = [:] // UUID -> DragDetector
    private var observers: [Any] = []
    private var hasPresentedAccessibilityPrompt = false

    @MainActor
    private var selectedDisplayUUIDs: Set<String> {
        let available = Set(NSScreen.screens.compactMap(\.displayUUID))
        if Defaults[.showOnAllDisplays] {
            return available
        }

        let explicit = Set(Defaults[.enabledDisplayUUIDs]).intersection(available)
        if !explicit.isEmpty {
            return explicit
        }

        if let preferred = coordinator.preferredScreenUUID, available.contains(preferred) {
            return [preferred]
        }

        return Set([NSScreen.main?.displayUUID].compactMap { $0 })
    }

    @MainActor
    private var usesDisplaySet: Bool {
        Defaults[.showOnAllDisplays] || Defaults[.enabledDisplayUUIDs].count > 1
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush debounced shelf persistence to avoid losing recent changes
        ShelfStateViewModel.shared.flushSync()

        NotificationCenter.default.removeObserver(self)
        if let observer = screenLockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenLockedObserver = nil
        }
        if let observer = screenUnlockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenUnlockedObserver = nil
        }
        MusicManager.shared.destroy()
        cleanupDragDetectors()
        cleanupWindows()
        BetterDisplayManager.shared.stopObserving()
        LunarManager.shared.stopListening()
        LunarManager.shared.configureLunarOSD(hide: false)
        XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
        
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    @MainActor
    func onScreenLocked(_ notification: Notification) {
        isScreenLocked = true
        if !Defaults[.showOnLockScreen] {
            cleanupWindows()
        } else {
            enableSkyLightOnAllWindows()
        }
    }

    @MainActor
    func onScreenUnlocked(_ notification: Notification) {
        isScreenLocked = false
        if !Defaults[.showOnLockScreen] {
            adjustWindowPosition(changeAlpha: true)
        } else {
            disableSkyLightOnAllWindows()
        }
    }
    
    @MainActor
    private func enableSkyLightOnAllWindows() {
        if usesDisplaySet {
            windows.values.forEach { window in
                if let skyWindow = window as? InterestingNotchSkyLightWindow {
                    skyWindow.enableSkyLight()
                }
            }
        } else {
            if let skyWindow = window as? InterestingNotchSkyLightWindow {
                skyWindow.enableSkyLight()
            }
        }
    }
    
    @MainActor
    private func disableSkyLightOnAllWindows() {
        // Delay disabling SkyLight to avoid flicker during unlock transition
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run {
                if self.usesDisplaySet {
                    self.windows.values.forEach { window in
                        if let skyWindow = window as? InterestingNotchSkyLightWindow {
                            skyWindow.disableSkyLight()
                        }
                    }
                } else {
                    if let skyWindow = self.window as? InterestingNotchSkyLightWindow {
                        skyWindow.disableSkyLight()
                    }
                }
            }
        }
    }

    private func cleanupWindows(shouldInvert: Bool = false) {
        windows.values.forEach { window in
            window.close()
            NotchSpaceManager.shared.notchSpace.windows.remove(window)
        }
        windows.removeAll()
        viewModels.removeAll()

        if let window {
            window.close()
            NotchSpaceManager.shared.notchSpace.windows.remove(window)
        }
        if let obs = windowScreenDidChangeObserver {
            NotificationCenter.default.removeObserver(obs)
            windowScreenDidChangeObserver = nil
        }
        self.window = nil

        // ensure OSD integration reflects the current window state
        coordinator.applyOSDSources()
    }

    private func cleanupDragDetectors() {
        dragDetectors.values.forEach { detector in
            detector.stopMonitoring()
        }
        dragDetectors.removeAll()
    }

    private func setupDragDetectors() {
        cleanupDragDetectors()

        guard Defaults[.expandedDragDetection] else { return }

        if usesDisplaySet {
            for screen in NSScreen.screens where selectedDisplayUUIDs.contains(screen.displayUUID ?? "") {
                setupDragDetectorForScreen(screen)
            }
        } else {
            let preferredScreen: NSScreen? = window?.screen
                ?? NSScreen.screen(withUUID: coordinator.selectedScreenUUID)
                ?? NSScreen.main

            if let screen = preferredScreen {
                setupDragDetectorForScreen(screen)
            }
        }
    }

    private func setupDragDetectorForScreen(_ screen: NSScreen) {
        guard let uuid = screen.displayUUID else { return }
        
        let screenFrame = screen.frame
        let notchHeight = openNotchSize.height
        let notchWidth = openNotchSize.width
        
        // Create notch region at the top-center of the screen where an open notch would occupy
        let notchRegion = CGRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
        
        let detector = DragDetector(notchRegion: notchRegion)
        
        detector.onDragEntersNotchRegion = { [weak self] in
            Task { @MainActor in
                self?.handleDragEntersNotchRegion(onScreen: screen)
            }
        }
        
        dragDetectors[uuid] = detector
        detector.startMonitoring()
    }

    private func handleDragEntersNotchRegion(onScreen screen: NSScreen) {
        guard Defaults[.interestingShelf] else { return }
        guard let uuid = screen.displayUUID else { return }
        
        if usesDisplaySet, let viewModel = viewModels[uuid] {
            if viewModel.open() {
                coordinator.currentView = .shelf
            }
        } else if !usesDisplaySet, let windowScreen = window?.screen, screen == windowScreen {
            if vm.open() {
                coordinator.currentView = .shelf
            }
        }
    }

    private func createInterestingNotchWindow(for screen: NSScreen, with viewModel: InterestingViewModel) -> NSWindow {
        let rect = NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]
        
        let window = InterestingNotchSkyLightWindow(contentRect: rect, styleMask: styleMask, backing: .buffered, defer: false)
        
        // Enable SkyLight only when screen is locked
        if isScreenLocked {
            window.enableSkyLight()
        } else {
            window.disableSkyLight()
        }

        window.contentView = NSHostingView(
            rootView: ContentView()
                .environmentObject(viewModel)
        )

        window.orderFrontRegardless()
        NotchSpaceManager.shared.notchSpace.windows.insert(window)

        // Observe when the window's screen changes so we can update drag detectors
        windowScreenDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification,
            object: window,
            queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.setupDragDetectors()
                }
        }
        return window
    }

    @MainActor
    private func positionWindow(_ window: NSWindow, on screen: NSScreen, changeAlpha: Bool = false) {
        if changeAlpha {
            window.alphaValue = 0
        }

        let screenFrame = screen.frame
        window.setFrameOrigin(
            NSPoint(
                x: screenFrame.origin.x + (screenFrame.width / 2) - window.frame.width / 2,
                y: screenFrame.origin.y + screenFrame.height - window.frame.height
            ))
        window.alphaValue = 1
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            WidgetLaunchLoader().loadWidgets()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        observers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.selectedScreenChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition(changeAlpha: true)
                self?.setupDragDetectors()
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.notchHeightChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustWindowPosition()
                self?.setupDragDetectors()
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.automaticallySwitchDisplayChanged, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self = self, let window = self.window else { return }
            Task { @MainActor in
                window.alphaValue = self.coordinator.selectedScreenUUID == self.coordinator.preferredScreenUUID ? 1 : 0
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.showOnAllDisplaysChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.cleanupWindows(shouldInvert: true)
                self.adjustWindowPosition(changeAlpha: true)
                self.setupDragDetectors()
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.expandedDragDetectionChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setupDragDetectors()
            }
        })

        // Use closure-based observers for DistributedNotificationCenter and keep tokens for removal
        screenLockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenLocked(notification)
                }
        }

        screenUnlockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.onScreenUnlocked(notification)
                }
        }

        KeyboardShortcuts.onKeyDown(for: .toggleSneakPeek) { [weak self] in
            guard let self = self else { return }
            if Defaults[.sneakPeekStyles] == .inline {
                let newStatus = !self.coordinator.expandingView.show
                self.coordinator.toggleExpandingView(status: newStatus, type: .music)
                KeyboardShortcuts.onKeyUp(for: .toggleSneakPeek) {
                    self.coordinator.toggleSneakPeek(
                        status: !self.coordinator.isAnySneakPeekShowing,
                        type: .music
                    )
                }
            } else {
                self.coordinator.toggleSneakPeek(
                    status: !self.coordinator.isAnySneakPeekShowing,
                    type: .music,
                    duration: 3.0
                )
            }
        }

        KeyboardShortcuts.onKeyDown(for: .toggleNotchOpen) { [weak self] in
            Task { [weak self] in
                guard let self = self else { return }

                let mouseLocation = NSEvent.mouseLocation

                var viewModel = self.vm

                if self.usesDisplaySet {
                    for screen in NSScreen.screens {
                        if screen.frame.contains(mouseLocation) {
                            if let uuid = screen.displayUUID, let screenViewModel = self.viewModels[uuid] {
                                viewModel = screenViewModel
                                break
                            }
                        }
                    }
                }

                self.closeNotchTask?.cancel()
                self.closeNotchTask = nil

                switch viewModel.notchState {
                case .closed:
                    var didOpen = false
                    await MainActor.run {
                        didOpen = viewModel.open()
                    }
                    guard didOpen else { return }

                    let task = Task { [weak viewModel] in
                        do {
                            try await Task.sleep(for: .seconds(3))
                            await MainActor.run {
                                viewModel?.close()
                            }
                        } catch { }
                    }
                    self.closeNotchTask = task
                case .open:
                    await MainActor.run {
                        viewModel.close()
                    }
                }
            }
        }

        KeyboardShortcuts.onKeyDown(for: .colorPickerPickColor) {
            Task { @MainActor in
                guard let pickedColor = await ScreenColorPicker.shared.pickColor(),
                      let parsed = ColorPickerHSBAColor.from(nsColor: pickedColor) else {
                    return
                }

                if
                    let widget = WidgetEngine.shared.widgets.first(where: {
                        $0.manifest.kind == .interactive && $0.manifest.interactive?.type == .colorPicker
                    }),
                    let model = widget.interactiveRuntime as? ColorPickerWidgetModel
                {
                    model.applyPickedColor(parsed)
                } else {
                    Defaults[.colorPickerRecentHistory] = ColorPickerHistoryStore.push(
                        parsed,
                        into: Defaults[.colorPickerRecentHistory]
                    )
                }

                if Defaults[.sneakPeekStyles] == .inline {
                    self.coordinator.toggleExpandingView(status: true, type: .colorPicker)
                }
            }
        }

        KeyboardShortcuts.onKeyDown(for: .clipboardHistoryPanel) { [weak self] in
            Task { @MainActor in
                guard
                    let self,
                    Defaults[.pinnedWidgetIDs].contains("clipboard-history"),
                    WidgetEngine.shared.widgets.contains(where: { $0.id == "clipboard-history" })
                else {
                    return
                }

                _ = self.vm.open()
                self.coordinator.currentView = .widget(id: "clipboard-history")
            }
        }

        // Sync notch height with real value on app launch if mode is matchRealNotchSize
        syncNotchHeightIfNeeded()
        
        if !usesDisplaySet {
            let viewModel = self.vm
            let window = createInterestingNotchWindow(
                for: NSScreen.main ?? NSScreen.screens.first!, with: viewModel)
            self.window = window
            adjustWindowPosition(changeAlpha: true)
        } else {
            adjustWindowPosition(changeAlpha: true)
        }

        setupDragDetectors()

        if coordinator.firstLaunch {
            DispatchQueue.main.async {
                self.showOnboardingWindow()
            }
            playWelcomeSound()
        } else if MusicManager.shared.isNowPlayingDeprecated
            && Defaults[.mediaController] == .nowPlaying
        {
            DispatchQueue.main.async {
                self.showOnboardingWindow(step: .musicPermission)
            }
        }

        previousScreens = NSScreen.screens

        // make sure OSD subsystems are in the right state now that initial
        // notch windows have been created/cleaned up
        coordinator.applyOSDSources()

        // Existing installations do not go through onboarding again. Ask for
        // the permission up front so OSD replacement is usable immediately.
        if !coordinator.firstLaunch {
            Task { @MainActor [weak self] in
                await self?.showAccessibilityPromptIfNeeded()
            }
        }
    }

    @MainActor
    private func showAccessibilityPromptIfNeeded() async {
        guard !hasPresentedAccessibilityPrompt,
              Defaults[.osdBrightnessSource] == .builtin || Defaults[.osdVolumeSource] == .builtin
        else { return }

        guard !(await XPCHelperClient.shared.isAccessibilityAuthorized()) else { return }

        hasPresentedAccessibilityPrompt = true

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "InterestingNotch needs Accessibility access to replace the system volume and brightness OSD. Add the currently installed InterestingNotch app in System Settings, then enable it."
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Not Now")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            _ = await MediaKeyInterceptor.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func playWelcomeSound() {
        let audioPlayer = AudioPlayer()
        audioPlayer.play(fileName: "interesting", fileExtension: "m4a")
    }

    func deviceHasNotch() -> Bool {
        if #available(macOS 12.0, *) {
            for screen in NSScreen.screens {
                if screen.safeAreaInsets.top > 0 {
                    return true
                }
            }
        }
        return false
    }

    @objc func screenConfigurationDidChange() {
        let currentScreens = NSScreen.screens

        let screensChanged =
            currentScreens.count != previousScreens?.count
            || Set(currentScreens.compactMap { $0.displayUUID })
                != Set(previousScreens?.compactMap { $0.displayUUID } ?? [])
            || Set(currentScreens.map { $0.frame }) != Set(previousScreens?.map { $0.frame } ?? [])

        previousScreens = currentScreens

        if screensChanged {
            DispatchQueue.main.async { [weak self] in
                // Sync notch height with real value if mode is matchRealNotchSize
                syncNotchHeightIfNeeded()
                
                self?.cleanupWindows()
                self?.adjustWindowPosition()
                self?.setupDragDetectors()
            }
        }
    }

    @objc func adjustWindowPosition(changeAlpha: Bool = false) {
        if usesDisplaySet {
            let currentScreenUUIDs = Set(NSScreen.screens.compactMap { $0.displayUUID })

            let selectedUUIDs = selectedDisplayUUIDs

            // Remove windows for screens that no longer exist or are no longer selected.
            for uuid in windows.keys where !currentScreenUUIDs.contains(uuid) || !selectedUUIDs.contains(uuid) {
                if let window = windows[uuid] {
                    window.close()
                    NotchSpaceManager.shared.notchSpace.windows.remove(window)
                    windows.removeValue(forKey: uuid)
                    viewModels.removeValue(forKey: uuid)
                }
            }

            // Create or update windows only for the selected screens.
            for screen in NSScreen.screens where selectedUUIDs.contains(screen.displayUUID ?? "") {
                guard let uuid = screen.displayUUID else { continue }
                
                if windows[uuid] == nil {
                    let viewModel = InterestingViewModel(screenUUID: uuid)
                    let window = createInterestingNotchWindow(for: screen, with: viewModel)

                    windows[uuid] = window
                    viewModels[uuid] = viewModel
                }

                if let window = windows[uuid], let viewModel = viewModels[uuid] {
                    positionWindow(window, on: screen, changeAlpha: changeAlpha)

                    if viewModel.notchState == .closed {
                        viewModel.close()
                    }
                }
            }
        } else {
            let selectedScreen: NSScreen

            let explicitDisplay = Defaults[.enabledDisplayUUIDs].count == 1
                ? Defaults[.enabledDisplayUUIDs].first
                : nil

            if let explicitDisplay, let selected = NSScreen.screen(withUUID: explicitDisplay) {
                coordinator.selectedScreenUUID = explicitDisplay
                selectedScreen = selected
            } else if let preferredScreen = NSScreen.screen(withUUID: coordinator.preferredScreenUUID ?? "") {
                coordinator.selectedScreenUUID = coordinator.preferredScreenUUID ?? ""
                selectedScreen = preferredScreen
            } else if Defaults[.automaticallySwitchDisplay], let mainScreen = NSScreen.main,
                      let mainUUID = mainScreen.displayUUID {
                coordinator.selectedScreenUUID = mainUUID
                selectedScreen = mainScreen
            } else {
                if let window = window {
                    window.alphaValue = 0
                }
                return
            }

            vm.screenUUID = selectedScreen.displayUUID
            vm.notchSize = getClosedNotchSize(screenUUID: selectedScreen.displayUUID)

            if window == nil {
                window = createInterestingNotchWindow(for: selectedScreen, with: vm)
            }

            if let window = window {
                positionWindow(window, on: selectedScreen, changeAlpha: changeAlpha)

                if vm.notchState == .closed {
                    vm.close()
                }
            }
        }

        // windows might have been added/removed during the earlier logic –
        // update the OSD subsystems accordingly.
        coordinator.applyOSDSources()
    }

    @objc func togglePopover(_ sender: Any?) {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            window?.orderFrontRegardless()
        }
    }

    @objc func showMenu() {
        statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc func quitAction() {
        NSApplication.shared.terminate(self)
    }

    private func showOnboardingWindow(step: OnboardingStep = .welcome) {
        if onboardingWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Onboarding"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.level = .floating
            window.contentView = NSHostingView(
                rootView: OnboardingView(
                    step: step,
                    updater: SoftwareUpdateStore.updater,
                    onFinish: {
                        window.orderOut(nil)
//                        NSApp.setActivationPolicy(.accessory)
                        window.close()
                        NSApp.deactivate()
                    },
                    onOpenSettings: {
                        window.close()
                        SettingsWindowController.shared.showWindow()
                    }
                ))
            window.isRestorable = false
            window.identifier = NSUserInterfaceItemIdentifier("OnboardingWindow")

            onboardingWindowController = NSWindowController(window: window)
        }

//        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.level = .floating
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}
