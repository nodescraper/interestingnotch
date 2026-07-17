//
//  ContentView.swift
//  InterestingNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI
import SwiftUIIntrospect

private enum CompactActivityKind: String {
    case recorder
    case timer
    case sports
    case bluetooth
    case caffeine
    case customPeek
    case music
}

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: InterestingViewModel
    @ObservedObject var webcamManager = WebcamManager.shared

    @ObservedObject var coordinator = InterestingViewCoordinator.shared
    @ObservedObject var widgetEngine = WidgetEngine.shared
    @ObservedObject var customPeekWatcher = CustomPeekWatcher.shared
    @ObservedObject var bluetoothDeviceMonitor = BluetoothDeviceMonitor.shared
    @ObservedObject var caffeineManager = CaffeineManager.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var brightnessManager = BrightnessManager.shared
    @ObservedObject var volumeManager = VolumeManager.shared
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var anyDropDebounceTask: Task<Void, Never>?
    @State private var gestureProgress: CGFloat = .zero
    @State private var horizontalMediaGestureTriggered = false
    @State private var horizontalMediaGestureFeedback: CGFloat = .zero
    @State private var isHoveringMusicArea = false
    @State private var bluetoothStartupTask: Task<Void, Never>?
    @State private var currentAccentColor: Color = .effectiveAccent
    @State private var lastCustomPeek: CustomPeek?
    @State private var lastCompactTimerModel: TimerWidgetModel?
    @State private var lastCompactRecorderModel: VoiceRecorderWidgetModel?
    @State private var lastCompactSportsGame: GameSnapshot?
    @State private var lastBluetoothConnectionEvent: BluetoothConnectionEvent?
    @State private var lastCompactActivityKind: CompactActivityKind?

    @State private var haptics: Bool = false

    @Namespace var albumArtNamespace
    @Namespace private var widgetNamespace
    private var widgetAccent: Color { currentAccentColor }

    @Default(.showNotHumanFace) var showNotHumanFace
    @AppStorage("customWidgetsEnabled") private var customWidgetsEnabled = false

    // Use standardized animations from StandardAnimations enum
    private let animationSpring = StandardAnimations.interactive

    private let extendedHoverPadding: CGFloat = 30
    private let zeroHeightHoverPadding: CGFloat = 10

    // MARK: - Corner Radius Scaling
    private var cornerRadiusScaleFactor: CGFloat? {
        guard Defaults[.cornerRadiusScaling] else { return nil }
        let effectiveHeight = displayClosedNotchHeight
        guard effectiveHeight > 0 else { return nil }
        return effectiveHeight / 38.0
    }
    
    private var topCornerRadius: CGFloat {
        // If the notch is open, return the opened radius.
        if vm.notchState == .open {
            return cornerRadiusInsets.opened.top
        }

        // For the closed notch, scale if enabled
        let baseClosedTop = cornerRadiusInsets.closed.top
        guard let scaleFactor = cornerRadiusScaleFactor else {
            return displayClosedNotchHeight > 0 ? baseClosedTop : 0
        }
        return max(0, baseClosedTop * scaleFactor)
    }

    private var currentNotchShape: NotchShape {
        // Scale bottom corner radius for closed notch shape when scaling is enabled.
        let baseClosedBottom = cornerRadiusInsets.closed.bottom
        let bottomCorner: CGFloat

        if vm.notchState == .open {
            bottomCorner = cornerRadiusInsets.opened.bottom
        } else if let scaleFactor = cornerRadiusScaleFactor {
            bottomCorner = max(0, baseClosedBottom * scaleFactor)
        } else {
            bottomCorner = displayClosedNotchHeight > 0 ? baseClosedBottom : 0
        }

        return NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCorner
        )
    }

    private var computedChinWidth: CGFloat {
        var chinWidth: CGFloat = vm.closedNotchSize.width

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
        {
            chinWidth = 640
        } else if let compactExtraWidth = expandedCompactActivityExtraWidth {
            chinWidth += compactExtraWidth
        } else if !coordinator.expandingView.show && vm.notchState == .closed
            && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace]
            && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, displayClosedNotchHeight - 12) + 20)
        }

        return chinWidth
    }

    // If the closed notch height is 0 (any display/setting), display a 10pt nearly-invisible notch
    // instead of fully hiding it. This preserves layout while avoiding visual artifacts.
    private var isNotchHeightZero: Bool { vm.effectiveClosedNotchHeight == 0 }

    private var displayClosedNotchHeight: CGFloat { isNotchHeightZero ? 10 : vm.effectiveClosedNotchHeight }

    private var colorPickerCompactSideSize: CGFloat {
        max(0, displayClosedNotchHeight - 12)
    }

    private var colorPickerCompactCodeWidth: CGFloat {
        // The built-in Mac notch needs a little more room for the full hex value;
        // keep external displays compact so their wings do not become oversized.
        vm.hasNotch ? 104 : 76
    }

    private var compactColorPickerWidth: CGFloat {
        vm.closedNotchSize.width - 4
            + (2 * liveActivityEdgeMargin)
            + colorPickerCompactSideSize
            + colorPickerCompactCodeWidth
    }

    private var timerCompactRingSize: CGFloat {
        max(0, displayClosedNotchHeight - 14)
    }

    private var timerCompactTextWidth: CGFloat {
        vm.hasNotch ? 92 : 82
    }

    private var compactTimerWidth: CGFloat {
        vm.closedNotchSize.width - 4
            + (2 * liveActivityEdgeMargin)
            + timerCompactRingSize
            + timerCompactTextWidth
    }

    private var nativeTimerVisualSize: CGFloat {
        max(0, displayClosedNotchHeight - 12)
    }

    private var compactTimerBadgeSize: CGFloat {
        max(0, nativeTimerVisualSize - 4)
    }

    private var nativeTimerTimeWidth: CGFloat {
        vm.hasNotch ? 58 : 54
    }

    private var nativeTimerCompactExtraWidth: CGFloat {
        nativeTimerVisualSize + nativeTimerTimeWidth + 10
    }

    private var nativeRecorderTimeWidth: CGFloat {
        vm.hasNotch ? 58 : 54
    }

    private var nativeRecorderCompactExtraWidth: CGFloat {
        nativeTimerVisualSize + nativeRecorderTimeWidth + 10
    }

    private var nativeRecorderCompactWidth: CGFloat {
        vm.closedNotchSize.width - 4
            + (2 * liveActivityEdgeMargin)
            + nativeRecorderCompactExtraWidth
    }

    private var nativeTimerCompactWidth: CGFloat {
        vm.closedNotchSize.width - 4
            + (2 * liveActivityEdgeMargin)
            + nativeTimerCompactExtraWidth
    }

    private func compactSportsLeadingWidth(for game: GameSnapshot) -> CGFloat {
        switch game.leagueDefinition.format {
        case .sets:
            return vm.hasNotch ? 60 : 54
        case .leaderboard:
            return vm.hasNotch ? 68 : 60
        case .teamScore, .innings:
            return vm.hasNotch ? 46 : 42
        }
    }

    private func compactSportsTrailingWidth(for game: GameSnapshot) -> CGFloat {
        switch game.leagueDefinition.format {
        case .sets:
            return vm.hasNotch ? 60 : 54
        case .leaderboard:
            return vm.hasNotch ? 76 : 66
        case .teamScore, .innings:
            return vm.hasNotch ? 56 : 50
        }
    }

    private func compactSportsWidth(for game: GameSnapshot) -> CGFloat {
        vm.closedNotchSize.width - 4
            + (2 * liveActivityEdgeMargin)
            + compactSportsLeadingWidth(for: game)
            + compactSportsTrailingWidth(for: game)
    }

    private var hasCompactTimerActivity: Bool {
        compactTimerLiveModel != nil
            && !vm.hideOnClosed
            && (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
    }

    private var hasCompactSportsActivity: Bool {
        compactSportsGame != nil
            && !vm.hideOnClosed
            && (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
    }

    private var hasCompactRecorderActivity: Bool {
        compactRecorderLiveModel != nil
            && !vm.hideOnClosed
            && (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
    }

    private var hasCompactCustomPeekActivity: Bool {
        customPeekWatcher.currentPeek != nil
            && !vm.hideOnClosed
            && (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
    }

    private var hasBluetoothConnectionActivity: Bool {
        bluetoothDeviceMonitor.currentEvent != nil
            && !vm.hideOnClosed
            && (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
    }

    private var hasCaffeineCompactActivity: Bool {
        caffeineManager.compactPeekVisible
            && !vm.hideOnClosed
            && (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
    }

    private var hasCompactMusicActivity: Bool {
        coordinator.musicLiveActivityEnabled
            && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && !vm.hideOnClosed
            && (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
    }

    private var activeCompactActivityKind: CompactActivityKind? {
        if hasCompactRecorderActivity { return .recorder }
        if hasCompactTimerActivity { return .timer }

        // Short-lived announcement peeks should pre-empt sports so the closed
        // notch can transition away from a live match and surface the alert.
        if hasBluetoothConnectionActivity { return .bluetooth }
        if hasCaffeineCompactActivity { return .caffeine }
        if hasCompactCustomPeekActivity { return .customPeek }
        if hasCompactSportsActivity { return .sports }
        if hasCompactMusicActivity { return .music }
        return nil
    }

    private var renderedCompactActivityKind: CompactActivityKind? {
        guard vm.notchState == .closed,
              coordinator.shouldRenderCompactSneakPeek(on: vm.screenUUID)
        else { return nil }

        if let activityID = coordinator.renderedCompactSneakPeekActivityID(on: vm.screenUUID),
           let renderedKind = CompactActivityKind(rawValue: activityID)
        {
            return renderedKind
        }
        return activeCompactActivityKind ?? lastCompactActivityKind
    }

    private var expandedCompactActivityExtraWidth: CGFloat? {
        guard vm.notchState == .closed,
              coordinator.shouldRevealCompactSneakPeek(on: vm.screenUUID),
              let kind = activeCompactActivityKind ?? lastCompactActivityKind
        else { return nil }

        switch kind {
        case .recorder:
            return nativeRecorderCompactExtraWidth
        case .timer:
            return nativeTimerCompactExtraWidth
        case .sports:
            if let game = compactSportsGame ?? lastCompactSportsGame {
                return max(0, compactSportsWidth(for: game) - vm.closedNotchSize.width)
            }
            return nativeTimerCompactExtraWidth
        case .bluetooth:
            return max(0, bluetoothCompactWidth - vm.closedNotchSize.width)
        case .caffeine:
            return max(0, caffeineCompactWidth - vm.closedNotchSize.width)
        case .customPeek:
            return max(0, customPeekCompactWidth - vm.closedNotchSize.width)
        case .music:
            return max(0, musicCompactWidth - vm.closedNotchSize.width)
        }
    }

    private var compactActivityCenterWidth: CGFloat {
        // Match the exact intrinsic width of the normal closed-state placeholder.
        // The surrounding NotchLayout applies its own horizontal corner padding.
        max(0, vm.closedNotchSize.width - 20)
    }

    private var renderedCompactActivityWidth: CGFloat {
        guard coordinator.shouldRevealCompactSneakPeek(on: vm.screenUUID),
              let kind = renderedCompactActivityKind
        else { return compactActivityCenterWidth }

        switch kind {
        case .recorder:
            return nativeRecorderCompactWidth
        case .timer:
            return nativeTimerCompactWidth
        case .sports:
            if let game = compactSportsGame ?? lastCompactSportsGame {
                return compactSportsWidth(for: game)
            }
            return nativeTimerCompactWidth
        case .bluetooth:
            return bluetoothCompactWidth
        case .caffeine:
            return caffeineCompactWidth
        case .customPeek:
            return customPeekCompactWidth
        case .music:
            return musicCompactWidth
        }
    }

    private func customPeekContentWidth(_ peek: CustomPeek, left: Bool) -> CGFloat {
        let text = left ? peek.title : (peek.message ?? "")
        return min(150, max(34, CGFloat(text.count * 7 + (left && peek.icon != nil ? 24 : 0) + 12)))
    }

    private var customPeekCompactWidth: CGFloat {
        guard let peek = customPeekWatcher.currentPeek ?? lastCustomPeek else { return vm.closedNotchSize.width }
        let left = peek.side == .right ? 0 : customPeekContentWidth(peek, left: true)
        let right = peek.side == .left ? 0 : customPeekContentWidth(peek, left: false)
        return vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin) + left + right
    }

    private var bluetoothDeviceNameWidth: CGFloat {
        guard let event = bluetoothDeviceMonitor.currentEvent ?? lastBluetoothConnectionEvent else { return 0 }
        return min(190, max(86, CGFloat(event.device.name.count * 7 + 36)))
    }

    private var bluetoothStatusWidth: CGFloat { 106 }

    private var bluetoothCompactWidth: CGFloat {
        vm.closedNotchSize.width - 4
            + (2 * liveActivityEdgeMargin)
            + bluetoothDeviceNameWidth
            + bluetoothStatusWidth
    }

    private var caffeineCompactVisualWidth: CGFloat {
        nativeTimerVisualSize + 6
    }

    private var caffeineCompactTextWidth: CGFloat {
        max(nativeTimerTimeWidth, caffeineCompactLabelWidth)
    }

    private var caffeineCompactWidth: CGFloat {
        vm.closedNotchSize.width - 4
            + (2 * liveActivityEdgeMargin)
            + caffeineCompactVisualWidth
            + caffeineCompactTextWidth
            + 10
    }

    private var caffeineCompactLabelWidth: CGFloat {
        if let message = caffeineManager.compactPeekMessage {
            return min(140, max(86, CGFloat(message.count * 7 + 12)))
        }
        return 72
    }

    private var musicCompactArtworkSize: CGFloat {
        if let scale = cornerRadiusScaleFactor {
            return max(0, displayClosedNotchHeight - 12 * scale)
        }
        return max(0, displayClosedNotchHeight - 12)
    }

    private var musicCompactSpectrumWidth: CGFloat {
        max(0, displayClosedNotchHeight - 12)
    }

    private var musicCompactWidth: CGFloat {
        musicCompactArtworkSize
            + (vm.closedNotchSize.width - 4 + 2 * liveActivityEdgeMargin)
            + musicCompactSpectrumWidth
    }

    private var tabSwitchTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8, anchor: .center)
                .combined(with: .opacity),
            removal: .scale(scale: 0.8, anchor: .center)
                .combined(with: .opacity)
        )
    }

    var body: some View {
        // Calculate scale based on gesture progress only
        let gestureScale: CGFloat = {
            guard gestureProgress != 0 else { return 1.0 }
            let scaleFactor = 1.0 + gestureProgress * 0.01
            return max(0.6, scaleFactor)
        }()
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                let mainLayout = NotchLayout()
                    .frame(alignment: .top)
                    .padding(
                        .horizontal,
                        vm.notchState == .open ? cornerRadiusInsets.opened.top : cornerRadiusInsets.closed.bottom
                    )
                    .padding([.horizontal, .bottom], vm.notchState == .open ? 12 : 0)
                    .background(.black)
                    .clipShape(currentNotchShape)
                          .overlay(alignment: .top) {
                              displayClosedNotchHeight.isZero && vm.notchState == .closed ? nil
                        : Rectangle()
                            .fill(.black)
                            .frame(height: 1)
                            .padding(.horizontal, topCornerRadius)
                    }
                    .shadow(
                        color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                            ? .black.opacity(0.7) : .clear, radius: 6
                    )
                    // Removed conditional bottom padding when using custom 0 notch to keep layout stable
                    .opacity((isNotchHeightZero && vm.notchState == .closed) ? 0.01 : 1)
                
                mainLayout
                    // Track the notch at its intrinsic rendered size. Some widget
                    // pages intentionally draw below the nominal openNotchSize
                    // into the window's reserved shadow area; attaching hover
                    // after the fixed frame makes that visible content behave as
                    // though the pointer already left the notch.
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .frame(height: vm.notchState == .open ? vm.notchSize.height : nil, alignment: .top)
                    .conditionalModifier(true) { view in
                        return view
                            .animation(vm.notchState == .open ? StandardAnimations.open : StandardAnimations.close, value: vm.notchState)
                            .animation(StandardAnimations.close, value: computedChinWidth)
                            .animation(.smooth, value: gestureProgress)
                    }
                    .onTapGesture {
                        doOpen()
                    }
                    .conditionalModifier(Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .down) { translation, phase in
                                handleDownGesture(translation: translation, phase: phase)
                            }
                    }
                    .conditionalModifier(Defaults[.enableHorizontalMediaGestures] && Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .left) { translation, phase in
                                handleNextTrackGesture(translation: translation, phase: phase)
                            }
                            .panGesture(direction: .right) { translation, phase in
                                handlePreviousTrackGesture(translation: translation, phase: phase)
                            }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .sharingDidFinish)) { _ in
                        if vm.notchState == .open && !isHovering && !vm.isBatteryPopoverActive && !coordinator.shouldKeepNotchOpenWithoutHover {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if self.vm.notchState == .open && !self.isHovering && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose && !self.coordinator.shouldKeepNotchOpenWithoutHover {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: vm.notchState) { _, newState in
                        if newState == .closed && isHovering {
                            withAnimation {
                                isHovering = false
                            }
                        }

                        syncCompactSneakPeekLifecycle()
                    }
                    .onChange(of: vm.isBatteryPopoverActive) {
                        if !vm.isBatteryPopoverActive && !isHovering && vm.notchState == .open && !SharingStateManager.shared.preventNotchClose && !coordinator.shouldKeepNotchOpenWithoutHover {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if !self.vm.isBatteryPopoverActive && !self.isHovering && self.vm.notchState == .open && !SharingStateManager.shared.preventNotchClose && !self.coordinator.shouldKeepNotchOpenWithoutHover {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: coordinator.temporaryOpenContext) { _, context in
                        guard context != nil else { return }
                        doOpen()
                    }
                    .onReceive(widgetEngine.objectWillChange) { _ in
                        DispatchQueue.main.async {
                            syncCompactSneakPeekLifecycle()
                        }
                    }
                    .onReceive(compactSportsModelPublisher) { _ in
                        DispatchQueue.main.async {
                            if let sportsGame = compactSportsGame {
                                lastCompactSportsGame = sportsGame
                            }
                            syncCompactSneakPeekLifecycle()
                        }
                    }
                    .onReceive(musicManager.objectWillChange) { _ in
                        DispatchQueue.main.async {
                            syncCompactSneakPeekLifecycle()
                        }
                    }
                    .onAppear {
                        currentAccentColor = .effectiveAccent
                        if customWidgetsEnabled { customPeekWatcher.enable() }
                        if !coordinator.firstLaunch && Defaults[.bluetoothNotificationsEnabled] {
                            bluetoothStartupTask?.cancel()
                            bluetoothStartupTask = Task { @MainActor in
                                try? await Task.sleep(for: .seconds(1.5))
                                guard !Task.isCancelled else { return }
                                bluetoothDeviceMonitor.enable()
                            }
                        }
                        syncCompactSneakPeekLifecycle()
                    }
                    .onChange(of: customWidgetsEnabled) { _, enabled in
                        if enabled { customPeekWatcher.enable() } else { customPeekWatcher.disable() }
                        syncCompactSneakPeekLifecycle()
                    }
                    .onReceive(customPeekWatcher.$currentPeek) { _ in
                        DispatchQueue.main.async {
                            if let currentPeek = customPeekWatcher.currentPeek {
                                lastCustomPeek = currentPeek
                            }
                            syncCompactSneakPeekLifecycle()
                        }
                    }
                    .onReceive(bluetoothDeviceMonitor.$currentEvent) { event in
                        DispatchQueue.main.async {
                            if let event {
                                lastBluetoothConnectionEvent = event
                            }
                            syncCompactSneakPeekLifecycle()
                        }
                    }
                    .onReceive(caffeineManager.objectWillChange) { _ in
                        DispatchQueue.main.async {
                            syncCompactSneakPeekLifecycle()
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .accentColorChanged)) { _ in
                        currentAccentColor = .effectiveAccent
                    }
                    .onReceive(Defaults.publisher(.useCustomAccentColor)) { _ in
                        currentAccentColor = .effectiveAccent
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            DispatchQueue.main.async {
                                SettingsWindowController.shared.showWindow()
                            }
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                        //                    Button("Edit") { // Doesnt work....
                        //                        let dn = DynamicNotch(content: EditPanelView())
                        //                        dn.toggle()
                        //                    }
                        //                    .keyboardShortcut("E", modifiers: .command)
                    }

                if vm.chinHeight > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.01))
                        .frame(width: computedChinWidth, height: vm.chinHeight)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)
        .ignoresSafeArea(.all)
        .compositingGroup()
        .scaleEffect(
            x: gestureScale,
            y: gestureScale,
            anchor: .top
        )
        .animation(.smooth, value: gestureProgress)
        .background(dragDetector)
        .preferredColorScheme(.dark)
        .environmentObject(vm)
        .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
            anyDropDebounceTask?.cancel()

            if isTargeted {
                if Defaults[.interestingShelf] && vm.notchState == .closed {
                    if doOpen() {
                        coordinator.currentView = .shelf
                    }
                }
                return
            }

            anyDropDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                if vm.dropEvent {
                    vm.dropEvent = false
                    return
                }

                vm.dropEvent = false
                if !SharingStateManager.shared.preventNotchClose {
                    vm.close()
                }
            }
        }
    }

    @ViewBuilder
    func NotchLayout() -> some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                if coordinator.helloAnimationRunning {
                    Spacer()
                    HelloAnimation(onFinish: {
                        vm.closeHello()
                    }).frame(
                        width: getClosedNotchSize().width,
                        height: 80
                    )
                    .padding(.top, 40)
                    Spacer()
                } else {
                    if coordinator.expandingView.type == .battery && coordinator.expandingView.show
                        && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
                    {
                        HStack(spacing: 0) {
                            HStack {
                                Text(batteryModel.statusText)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }

                            Rectangle()
                                .fill(.black)
                                .frame(width: vm.closedNotchSize.width + 10)

                            HStack {
                                InterestingBatteryView(
                                    batteryWidth: 30,
                                    isCharging: batteryModel.isCharging,
                                    isInLowPowerMode: batteryModel.isInLowPowerMode,
                                    isPluggedIn: batteryModel.isPluggedIn,
                                    levelBattery: batteryModel.levelBattery,
                                    isForNotification: true
                                )
                            }
                            .frame(width: 76, alignment: .trailing)
                        }
                        .frame(height: displayClosedNotchHeight, alignment: .center)
                      } else if coordinator.shouldShowSneakPeek(on: vm.screenUUID) && Defaults[.inlineOSD] && (coordinator.sneakPeekState(for: vm.screenUUID).type != .music) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .battery) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .voiceRecorder) && vm.notchState == .closed {
                          InlineOSD(
                              type: coordinator.binding(for: vm.screenUUID).type,
                              value: coordinator.binding(for: vm.screenUUID).value,
                              icon: coordinator.binding(for: vm.screenUUID).icon,
                              accent: coordinator.binding(for: vm.screenUUID).accent,
                              hoverAnimation: $isHovering,
                              gestureProgress: $gestureProgress
                          )
                              .transition(.opacity)
                      } else if renderedCompactActivityKind != nil {
                          CompactActivityContent()
                              .frame(
                                  width: renderedCompactActivityWidth,
                                  height: displayClosedNotchHeight,
                                  alignment: .center
                              )
                              .opacity(
                                  coordinator.shouldRevealCompactSneakPeek(on: vm.screenUUID) ? 1 : 0
                              )
                              .animation(
                                  StandardAnimations.close,
                                  value: coordinator.shouldRevealCompactSneakPeek(on: vm.screenUUID)
                              )
                      } else if !coordinator.expandingView.show && vm.notchState == .closed && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace] && !vm.hideOnClosed  {
                          InterestingFaceAnimation()
                       } else if vm.notchState == .open {
                           InterestingHeader()
                               .frame(height: max(24, displayClosedNotchHeight))
                               .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
                       }
                        // Use the resolved configured height on every display type.
                       else {
                           Rectangle().fill(.clear).frame(width: vm.closedNotchSize.width - 20, height: displayClosedNotchHeight)
                       }

                      if coordinator.shouldShowSneakPeek(on: vm.screenUUID) {
                          if (coordinator.sneakPeekState(for: vm.screenUUID).type != .music) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .battery) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .voiceRecorder) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .caffeine) && !Defaults[.inlineOSD] && vm.notchState == .closed {
                              SystemEventIndicatorModifier(
                                  eventType: coordinator.binding(for: vm.screenUUID).type,
                                  value: coordinator.binding(for: vm.screenUUID).value,
                                  icon: coordinator.binding(for: vm.screenUUID).icon,
                                  accent: coordinator.binding(for: vm.screenUUID).accent,
                                  message: coordinator.binding(for: vm.screenUUID).message,
                                  sendEventBack: { newVal in
                                      switch coordinator.sneakPeekState(for: vm.screenUUID).type {
                                      case .volume:
                                          VolumeManager.shared.setAbsolute(Float32(newVal))
                                      case .brightness:
                                          BrightnessManager.shared.setAbsolute(value: Float32(newVal))
                                      default:
                                          break
                                      }
                                  }
                              )
                              .padding(.bottom, 10)
                              .padding(.leading, 4)
                              .padding(.trailing, 8)
                          }
                          // Old sneak peek music
                          else if coordinator.sneakPeekState(for: vm.screenUUID).type == .music {
                              if vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard {
                                  HStack(alignment: .center) {
                                      Image(systemName: "music.note")
                                      GeometryReader { geo in
                                          MarqueeText(musicManager.songTitle + " - " + musicManager.artistName,  color: Defaults[.playerColorTinting] ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6) : .gray, delayDuration: 1.0, frameWidth: geo.size.width)
                                      }
                                  }
                                  .foregroundStyle(.gray)
                                  .padding(.bottom, 10)
                              }
                          }
                      }
                  }
              }
              .conditionalModifier((coordinator.shouldShowSneakPeek(on: vm.screenUUID) && (coordinator.sneakPeekState(for: vm.screenUUID).type == .music) && vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard) || (coordinator.shouldShowSneakPeek(on: vm.screenUUID) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .music) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .timer) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .systemMonitor) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .voiceRecorder) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .caffeine) && (vm.notchState == .closed))) { view in
                  view
                      .fixedSize()
              }
              .zIndex(1)
            if vm.notchState == .open {
                ZStack {
                    if coordinator.currentView == .home {
                        NotchHomeView(
                            albumArtNamespace: albumArtNamespace,
                            horizontalMediaGestureFeedback: horizontalMediaGestureFeedback,
                            isHoveringMusicArea: $isHoveringMusicArea
                        )
                        .transition(tabSwitchTransition)
                    }

                    if coordinator.currentView == .calendar {
                        CalendarTabPageView()
                            .transition(tabSwitchTransition)
                    }

                    if coordinator.currentView == .shelf {
                        ShelfView()
                            .transition(tabSwitchTransition)
                    }

                    if case .widget(let id) = coordinator.currentView {
                        WidgetTabPageView(widgetID: id, animationNamespace: widgetNamespace)
                            .transition(tabSwitchTransition)
                    }
                }
                .animation(.smooth(duration: 0.35), value: coordinator.currentView)
                .zIndex(1)
                .allowsHitTesting(vm.notchState == .open)
                .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
            }
        }
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
    }

    @ViewBuilder
    func InterestingFaceAnimation() -> some View {
        HStack {
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 20)
            let faceScale = min(1.0, displayClosedNotchHeight / 30.0)
            MinimalFaceFeatures(height: 24.0 * faceScale, width: 30.0 * faceScale)
        }.frame(
            height: displayClosedNotchHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func MusicLiveActivity() -> some View {
        HStack(spacing: 0) {
            // Closed-mode album art: scale padding and corner radius according to cornerRadiusScaleFactor
            let closedCornerRadius: CGFloat = {
                let base = MusicPlayerImageSizes.cornerRadiusInset.closed
                if let scale = cornerRadiusScaleFactor {
                    return max(0, base * scale)
                }
                return base
            }()

            Image(nsImage: musicManager.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: closedCornerRadius)
                )
                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                .frame(
                    width: musicCompactArtworkSize,
                    height: musicCompactArtworkSize
                )

            Rectangle()
                .fill(.black)
                .overlay(
                    HStack(alignment: .top) {
                        if coordinator.expandingView.show
                            && coordinator.expandingView.type == .music
                        {
                            MarqueeText(
                                musicManager.songTitle,
                                color: Defaults[.coloredSpectrogram]
                                    ? Color(nsColor: musicManager.avgColor) : Color.gray,
                                delayDuration: 0.4,
                                frameWidth: 100
                            )
                            .opacity(
                                (coordinator.expandingView.show
                                    && Defaults[.sneakPeekStyles] == .inline)
                                    ? 1 : 0
                            )
                            Spacer(minLength: vm.closedNotchSize.width)
                            // Song Artist
                            Text(musicManager.artistName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(
                                    Defaults[.coloredSpectrogram]
                                        ? Color(nsColor: musicManager.avgColor)
                                        : Color.gray
                                )
                                .opacity(
                                    (coordinator.expandingView.show
                                        && coordinator.expandingView.type == .music
                                        && Defaults[.sneakPeekStyles] == .inline)
                                        ? 1 : 0
                                )
                        }
                    }
                )
                .frame(
                    width: (coordinator.expandingView.show
                        && coordinator.expandingView.type == .music
                        && Defaults[.sneakPeekStyles] == .inline)
                        ? 380
                        : vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin)
                )

            HStack {
                AudioSpectrumView(
                    isPlaying: musicManager.isPlaying,
                    tintColor: Defaults[.coloredSpectrogram]
                    ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.5)
                    : Color.gray
                )
                .frame(width: 18, height: 12)
            }
            .frame(
                width: max(
                    0,
                    musicCompactSpectrumWidth
                        + gestureProgress / 2
                ),
                height: max(
                    0,
                    displayClosedNotchHeight - 12
                ),
                alignment: .center
            )
        }
        .frame(
            height: displayClosedNotchHeight,
            alignment: .center
        )
    }

    private func syncCompactSneakPeekLifecycle() {
        if let timer = compactTimerLiveModel {
            lastCompactTimerModel = timer
        }
        if let recorder = compactRecorderLiveModel {
            lastCompactRecorderModel = recorder
        }
        if let sportsGame = compactSportsGame {
            lastCompactSportsGame = sportsGame
        }
        if let peek = customPeekWatcher.currentPeek {
            lastCustomPeek = peek
        }
        if let event = bluetoothDeviceMonitor.currentEvent {
            lastBluetoothConnectionEvent = event
        }
        if let kind = activeCompactActivityKind {
            lastCompactActivityKind = kind
        }

        coordinator.updateCompactSneakPeekLifecycle(
            on: vm.screenUUID,
            notchState: vm.notchState,
            isActive: activeCompactActivityKind != nil,
            activityID: activeCompactActivityKind?.rawValue
        )
    }

    @ViewBuilder
    private func CompactActivityContent() -> some View {
        switch renderedCompactActivityKind {
        case .recorder:
            if let model = compactRecorderLiveModel ?? lastCompactRecorderModel {
                NativeRecorderCompactActivity(model: model)
                    .frame(width: nativeRecorderCompactWidth, height: displayClosedNotchHeight, alignment: .center)
            }
        case .timer:
            if let model = compactTimerLiveModel ?? lastCompactTimerModel {
                NativeTimerCompactActivity(model: model)
                    .frame(width: nativeTimerCompactWidth, height: displayClosedNotchHeight, alignment: .center)
            }
        case .sports:
            if let game = compactSportsGame ?? lastCompactSportsGame {
                SportsCompactActivity(game: game)
                    .frame(width: compactSportsWidth(for: game), height: displayClosedNotchHeight, alignment: .center)
            }
        case .bluetooth:
            if let event = bluetoothDeviceMonitor.currentEvent ?? lastBluetoothConnectionEvent {
                BluetoothConnectionCompactActivity(event: event)
                    .frame(width: bluetoothCompactWidth, height: displayClosedNotchHeight, alignment: .center)
            }
        case .caffeine:
            CaffeineCompactActivity()
                .frame(width: caffeineCompactWidth, height: displayClosedNotchHeight, alignment: .center)
        case .customPeek:
            if let peek = customPeekWatcher.currentPeek ?? lastCustomPeek {
                CustomPeekCompactActivity(peek: peek)
                    .frame(width: customPeekCompactWidth, height: displayClosedNotchHeight, alignment: .center)
            }
        case .music:
            MusicLiveActivity()
                .frame(width: musicCompactWidth, height: displayClosedNotchHeight, alignment: .center)
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func CaffeineCompactActivity() -> some View {
        HStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(caffeineCompactAccentColor.opacity(caffeineManager.isActive ? 0.18 : 0.12))

                Image(systemName: caffeineCompactSymbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(caffeineCompactAccentColor)
            }
            .frame(width: nativeTimerVisualSize, height: nativeTimerVisualSize)
            .frame(width: caffeineCompactVisualWidth, height: displayClosedNotchHeight, alignment: .leading)
            .padding(.leading, 4)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin))

            HStack(alignment: .center, spacing: 0) {
                Text(caffeineCompactPrimaryText)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(caffeineCompactAccentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .contentTransition(.numericText())
            }
            .frame(width: caffeineCompactTextWidth, height: displayClosedNotchHeight, alignment: .trailing)
            .padding(.trailing, 4)
        }
        .frame(width: caffeineCompactWidth, height: displayClosedNotchHeight, alignment: .center)
        .clipped()
    }

    private var caffeineCompactPrimaryText: String {
        caffeineManager.compactPeekMessage ?? caffeineCompactTimeLabel
    }

    private var caffeineCompactAccentColor: Color {
        caffeineManager.isActive ? Color.effectiveAccent : .white.opacity(0.72)
    }

    private var caffeineCompactSymbolName: String {
        caffeineManager.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
    }

    private var caffeineCompactTimeLabel: String {
        guard let remaining = caffeineManager.remaining else { return "Until off" }
        let totalMinutes = max(1, Int(ceil(remaining / 60)))
        if totalMinutes >= 60 { return "\(totalMinutes / 60)h \(totalMinutes % 60)m" }
        return "\(totalMinutes)m"
    }

    @ViewBuilder
    private func BluetoothConnectionCompactActivity(event: BluetoothConnectionEvent) -> some View {
        let statusColor: Color = event.isConnected ? .green : .red
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: event.device.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(event.device.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 5)
            .frame(width: bluetoothDeviceNameWidth, height: displayClosedNotchHeight, alignment: .leading)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin))

            HStack(spacing: 6) {
                Image(systemName: event.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(statusColor)
                Text(event.isConnected ? "Connected" : "Disconnected")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(event.isConnected ? statusColor : .white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 4)
            .frame(width: bluetoothStatusWidth, height: displayClosedNotchHeight, alignment: .trailing)
        }
    }

    @ViewBuilder
    func CustomPeekCompactActivity(peek: CustomPeek) -> some View {
        let leftWidth = peek.side == .right ? 0 : customPeekContentWidth(peek, left: true)
        let rightWidth = peek.side == .left ? 0 : customPeekContentWidth(peek, left: false)
        HStack(spacing: 0) {
            if peek.side != .right {
                customPeekLabel(peek, left: true)
                    .frame(width: leftWidth, height: displayClosedNotchHeight, alignment: .leading)
            }
            Rectangle().fill(.black)
                .frame(width: vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin))
            if peek.side != .left {
                customPeekLabel(peek, left: false)
                    .frame(width: rightWidth, height: displayClosedNotchHeight, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func customPeekLabel(_ peek: CustomPeek, left: Bool) -> some View {
        let text = left ? peek.title : (peek.message ?? "")
        HStack(spacing: 5) {
            if left, let icon = peek.icon, !icon.isEmpty { Image(systemName: icon).foregroundStyle(peek.accent) }
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(left ? .white : peek.accent)
                .lineLimit(1).minimumScaleFactor(0.7).allowsTightening(true)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    func NativeTimerCompactActivity(model: TimerWidgetModel) -> some View {
        TimelineView(.animation(minimumInterval: 0.2)) { _ in
                HStack(spacing: 0) {
                    compactTimerLeadingVisual(for: model)

                    Rectangle()
                        .fill(.black)
                        .frame(width: vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin))

                    HStack(alignment: .center, spacing: 0) {
                        Text(compactTimerPrimaryText(for: model))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(compactTimerAccentColor(for: model))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: true, vertical: false)
                            .transaction { transaction in
                                if model.mode == .timer {
                                    transaction.animation = nil
                                    transaction.disablesAnimations = true
                                }
                            }
                    }
                    .frame(width: nativeTimerTimeWidth, height: displayClosedNotchHeight, alignment: .trailing)
                    .padding(.trailing, 4)
                }
                .frame(width: nativeTimerCompactWidth, height: displayClosedNotchHeight, alignment: .center)
        }
    }

    @ViewBuilder
    func NativeRecorderCompactActivity(model: VoiceRecorderWidgetModel) -> some View {
        TimelineView(.animation(minimumInterval: 0.08)) { _ in
                HStack(spacing: 0) {
                    if showsCompactMusicArtwork {
                        compactClosedAlbumArt
                    } else {
                        CompactRecorderWaveformView(
                            levels: model.levels,
                            color: .red
                        )
                        .frame(width: nativeTimerVisualSize, height: displayClosedNotchHeight)
                    }

                    Rectangle()
                        .fill(.black)
                        .frame(width: vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin))

                    HStack(alignment: .center, spacing: 0) {
                        Text(model.displayTime)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .allowsTightening(true)
                    }
                    .frame(width: nativeRecorderTimeWidth, height: displayClosedNotchHeight, alignment: .trailing)
                    .padding(.trailing, 4)
                }
                .frame(width: nativeRecorderCompactWidth, height: displayClosedNotchHeight, alignment: .center)
        }
    }

    @ViewBuilder
    func ColorPickerLiveActivity() -> some View {
        let resolvedColor = compactColorPickerColor?.swiftUIColor ?? Color.effectiveAccent
        let hexValue = compactColorPickerColor?.hexString ?? "Pick Color"

        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(resolvedColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                }
                .frame(width: colorPickerCompactSideSize, height: colorPickerCompactSideSize)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin))

            HStack(alignment: .center) {
                Text(hexValue)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(width: colorPickerCompactCodeWidth, height: displayClosedNotchHeight, alignment: .trailing)
            .padding(.trailing, 3)
        }
        .frame(width: compactColorPickerWidth, height: displayClosedNotchHeight, alignment: .center)
    }

    @ViewBuilder
    func TimerLiveActivity(animationNamespace: Namespace.ID) -> some View {
        if let model = compactTimerModel {
            let isFinished = model.countdownState.shouldShowCompletionBanner

            HStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.16), lineWidth: 2)

                    Circle()
                        .trim(from: 0, to: max(0.02, 1 - model.countdownState.progress))
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: timerCompactRingSize, height: timerCompactRingSize)
                .matchedGeometryEffect(id: "timer-ring", in: animationNamespace)
                .padding(.trailing, 2)

                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin))

                HStack {
                    Text(isFinished ? "Time's up!" : model.displayTime)
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                .frame(width: timerCompactTextWidth, height: displayClosedNotchHeight, alignment: .trailing)
                .padding(.trailing, 4)
            }
            .frame(width: compactTimerWidth, height: displayClosedNotchHeight, alignment: .center)
        }
    }

    @ViewBuilder
    var dragDetector: some View {
        if Defaults[.interestingShelf] && vm.notchState == .closed {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
            vm.dropEvent = true
            ShelfStateViewModel.shared.load(providers)
            return true
        }
        } else {
            EmptyView()
        }
    }

    @discardableResult
    private func doOpen() -> Bool {
        var didOpen = false
        withAnimation(animationSpring) {
            didOpen = vm.open()
        }
        return didOpen
    }

    // MARK: - Hover Management

    private func handleHover(_ hovering: Bool) {
        if coordinator.firstLaunch { return }
        hoverTask?.cancel()
        
        if hovering {
            withAnimation(animationSpring) {
                isHovering = true
            }
            
            if vm.notchState == .closed && Defaults[.enableHaptics] {
                haptics.toggle()
            }
            
            guard vm.notchState == .closed,
                  (!coordinator.shouldShowSneakPeek(on: vm.screenUUID) || allowsHoverDuringSneakPeek),
                  Defaults[.openNotchOnHover] else { return }
            
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering,
                          (!self.coordinator.shouldShowSneakPeek(on: self.vm.screenUUID) || self.allowsHoverDuringSneakPeek) else { return }
                    
                    self.doOpen()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    withAnimation(animationSpring) {
                        self.isHovering = false
                    }

                    // Timer completion is a temporary expanded view. Once the
                    // pointer leaves, release its keep-open context so the
                    // normal notch close animation can run.
                    if self.coordinator.temporaryOpenContext != nil {
                        self.coordinator.dismissTemporaryOpenContext()
                    }
                    
                    if self.vm.notchState == .open && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose && !self.coordinator.shouldKeepNotchOpenWithoutHover {
                        self.vm.close()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func SportsCompactActivity(game: GameSnapshot) -> some View {
        TimelineView(.animation(minimumInterval: 0.2)) { _ in
            switch game.leagueDefinition.format {
            case .sets:
                compactSportsShell(game: game) {
                    HStack(spacing: 10) {
                        Text(compactTennisCode(for: game.home.name))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Text(game.home.score)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                } right: {
                    HStack(spacing: 10) {
                        Text(game.away.score)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                        Text(compactTennisCode(for: game.away.name))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        compactSportsExtraLiveBadge
                    }
                }
            case .leaderboard:
                if game.followedTeamID != "league", game.leagueDefinition.sport == "racing", let first = game.leaderboardEntries.first {
                    compactSportsShell(game: game) {
                        HStack(spacing: 10) {
                            Text("P\(first.position)")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.effectiveAccent)

                            Text(compactLeaderboardName(first.name))
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.92))
                                .lineLimit(1)
                        }
                    } right: {
                        if let second = game.leaderboardEntries.dropFirst().first {
                            HStack(spacing: 8) {
                                Text(compactLeaderboardName(second.name))
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                Text(compactLeaderboardTrailing(second))
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)

                                compactSportsExtraLiveBadge
                            }
                        }
                    }
                } else {
                    compactSportsShell(game: game) {
                        HStack(spacing: 10) {
                            Text(game.leagueDefinition.name == "Formula 1" ? "F1" : game.leagueDefinition.name)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.effectiveAccent)
                                .lineLimit(1)

                            Text(compactLeaderboardStatus(for: game))
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                        }
                    } right: {
                        if let leader = game.leaderboardEntries.first {
                            HStack(spacing: 10) {
                                Text("P\(leader.position)")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color.effectiveAccent)

                                Text(compactLeaderboardName(leader.name))
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                compactSportsExtraLiveBadge
                            }
                        }
                    }
                }
            case .teamScore, .innings:
                compactSportsShell(game: game) {
                    HStack(spacing: 8) {
                        RemoteSportsLogoView(urlString: game.home.logoURL)
                            .frame(width: 18, height: 18)

                        Text(game.home.score)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                } right: {
                    HStack(spacing: 8) {
                        Text(game.away.score)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                        RemoteSportsLogoView(urlString: game.away.logoURL)
                            .frame(width: 18, height: 18)

                        if let status = compactTeamScoreStatus(for: game) {
                            Text(status)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.effectiveAccent)
                                .lineLimit(1)
                        }

                        compactSportsExtraLiveBadge
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func compactSportsShell<Left: View, Right: View>(
        game: GameSnapshot,
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                left()
            }
            .padding(.leading, 2)
            .padding(.trailing, 1)
            .frame(width: compactSportsLeadingWidth(for: game), height: displayClosedNotchHeight, alignment: .leading)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin))

            HStack(spacing: 0) {
                right()
            }
            .padding(.leading, 1)
            .padding(.trailing, 2)
            .frame(width: compactSportsTrailingWidth(for: game), height: displayClosedNotchHeight, alignment: .trailing)
        }
        .frame(width: compactSportsWidth(for: game), height: displayClosedNotchHeight, alignment: .center)
        .clipped()
    }

    @ViewBuilder
    private var compactSportsExtraLiveBadge: some View {
        let additionalCount = compactSportsModel?.compactAdditionalLiveCount ?? 0
        if additionalCount > 0 {
            Text("+\(additionalCount)")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
        }
    }

    private func compactTeamScoreStatus(for game: GameSnapshot) -> String? {
        if let firstEvent = game.events.first, !firstEvent.minute.isEmpty {
            return firstEvent.minute
        }
        if !game.clock.isEmpty {
            return game.clock
        }
        if !game.statusDetail.isEmpty {
            return game.statusDetail
        }
        return nil
    }

    private func compactLeaderboardStatus(for game: GameSnapshot) -> String {
        let raw = !game.statusDetail.isEmpty ? game.statusDetail : game.clock
        guard !raw.isEmpty else { return "Live" }
        if let slashIndex = raw.firstIndex(of: "/") {
            return raw[..<slashIndex].trimmingCharacters(in: .whitespaces)
        }
        return raw
    }

    private func compactLeaderboardName(_ name: String) -> String {
        let parts = name.split(separator: " ")
        return String(parts.last ?? Substring(name))
    }

    private func compactLeaderboardTrailing(_ entry: SportsLeaderboardEntry) -> String {
        if let trailing = entry.trailingText, !trailing.isEmpty {
            return "P\(entry.position) \(trailing)"
        }
        return "P\(entry.position)"
    }

    private func compactTennisCode(for name: String) -> String {
        let parts = name.split(separator: " ")
        let source = parts.last.map(String.init) ?? name
        return String(source.prefix(3)).uppercased()
    }

	    private var allowsHoverDuringSneakPeek: Bool {
        switch coordinator.sneakPeekState(for: vm.screenUUID).type {
        case .colorPicker:
            return true
        default:
            return false
        }
    }

    // MARK: - Gesture Handling

    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .closed else { return }

        if phase == .ended {
            withAnimation(animationSpring) { gestureProgress = .zero }
            return
        }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * 20
        }

        if translation > Defaults[.gestureSensitivity] {
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
            doOpen()
        }
    }

    private func handleNextTrackGesture(translation: CGFloat, phase: NSEvent.Phase) {
        handleHorizontalMediaGesture(translation: translation, phase: phase, feedback: -1) {
            musicManager.nextTrack()
        }
    }

    private func handlePreviousTrackGesture(translation: CGFloat, phase: NSEvent.Phase) {
        handleHorizontalMediaGesture(translation: translation, phase: phase, feedback: 1) {
            musicManager.previousTrack()
        }
    }

    private func handleHorizontalMediaGesture(
        translation: CGFloat,
        phase: NSEvent.Phase,
        feedback: CGFloat,
        action: () -> Void
    ) {
        guard isHorizontalMediaGestureContext else {
            resetHorizontalMediaGesture()
            return
        }
        guard phase != .ended else {
            resetHorizontalMediaGesture()
            return
        }
        guard !horizontalMediaGestureTriggered else { return }
        guard translation > Defaults[.gestureSensitivity] else { return }

        horizontalMediaGestureTriggered = true
        triggerHorizontalMediaFeedback(feedback)
        action()

        if Defaults[.enableHaptics] {
            haptics.toggle()
        }
    }

    private func resetHorizontalMediaGesture() {
        horizontalMediaGestureTriggered = false
    }

    private func triggerHorizontalMediaFeedback(_ feedback: CGFloat) {
        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.62)) {
            horizontalMediaGestureFeedback = feedback
            if vm.notchState == .closed {
                gestureProgress = 2
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            withAnimation(animationSpring) {
                horizontalMediaGestureFeedback = .zero
                if vm.notchState == .closed {
                    gestureProgress = .zero
                }
            }
        }
    }

    private var isHorizontalMediaGestureContext: Bool {
        switch vm.notchState {
        case .closed:
            guard !vm.hideOnClosed else { return false }

            if coordinator.shouldShowSneakPeek(on: vm.screenUUID) {
                return coordinator.sneakPeekState(for: vm.screenUUID).type == .music
            }

            guard !coordinator.expandingView.show || coordinator.expandingView.type == .music else {
                return false
            }

            return coordinator.musicLiveActivityEnabled && (musicManager.isPlaying || !musicManager.isPlayerIdle)

        case .open:
            return coordinator.currentView == .home && !musicManager.isPlayerIdle && isHoveringMusicArea
        }
    }

    private var compactColorPickerColor: ColorPickerHSBAColor? {
        if
            let widget = widgetEngine.widgets.first(where: {
                $0.manifest.kind == .interactive && $0.manifest.interactive?.type == .colorPicker
            }),
            let model = widget.interactiveRuntime as? ColorPickerWidgetModel
        {
            return model.color
        }

        if let entry = Defaults[.colorPickerRecentHistory].first {
            return ColorPickerHistoryStore.restore(entry)
        }

        return nil
    }

    private var compactTimerModel: TimerWidgetModel? {
        guard
            let widget = widgetEngine.widgets.first(where: {
                $0.manifest.kind == .interactive && $0.manifest.interactive?.type == .timer
            }),
            let model = widget.interactiveRuntime as? TimerWidgetModel
        else {
            return nil
        }

        return model
    }

    private var compactTimerLiveModel: TimerWidgetModel? {
        guard let model = compactTimerModel else { return nil }

        switch model.mode {
        case .timer:
            switch model.countdownState.phase {
            case .running, .paused:
                return model
            case .idle, .finished:
                return nil
            }
        case .stopwatch:
            switch model.stopwatchState.phase {
            case .running, .paused:
                return model
            case .idle, .finished:
                return nil
            }
        }
    }

    private var compactRecorderLiveModel: VoiceRecorderWidgetModel? {
        guard
            let widget = widgetEngine.widgets.first(where: {
                $0.manifest.kind == .interactive && $0.manifest.interactive?.type == .voiceRecorder
            }),
            let model = widget.interactiveRuntime as? VoiceRecorderWidgetModel,
            model.isRecording
        else {
            return nil
        }

        return model
    }

    private var compactSportsModel: SportsWidgetModel? {
        guard
            let widget = widgetEngine.widgets.first(where: {
                $0.manifest.kind == .interactive && $0.manifest.interactive?.type == .sports
            }),
            let model = widget.interactiveRuntime as? SportsWidgetModel
        else {
            return nil
        }

        return model
    }

    private var compactSportsModelPublisher: AnyPublisher<Void, Never> {
        guard let model = compactSportsModel else {
            return Empty<Void, Never>(completeImmediately: false).eraseToAnyPublisher()
        }
        return model.objectWillChange.eraseToAnyPublisher()
    }

    private var compactSportsGame: GameSnapshot? {
        compactSportsModel?.compactGame
    }

    private var showsCompactMusicArtwork: Bool {
        coordinator.musicLiveActivityEnabled
            && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && !vm.hideOnClosed
    }

    private func compactTimerLeadingVisual(for model: TimerWidgetModel) -> some View {
        Group {
            if showsCompactMusicArtwork {
                compactClosedAlbumArt
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.16), lineWidth: 2)

                    Circle()
                        .trim(from: 0, to: compactTimerRingProgress(for: model))
                        .stroke(
                            compactTimerAccentColor(for: model),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: compactTimerBadgeSize, height: compactTimerBadgeSize)
            }
        }
        .frame(width: nativeTimerVisualSize + 6, height: displayClosedNotchHeight, alignment: .leading)
        .padding(.leading, 4)
    }

    private var compactClosedAlbumArt: some View {
        let baseArtSize = displayClosedNotchHeight - 12
        let scaledArtSize: CGFloat = {
            if let scale = cornerRadiusScaleFactor {
                return displayClosedNotchHeight - 12 * scale
            }
            return baseArtSize
        }()

        let closedCornerRadius: CGFloat = {
            let base = MusicPlayerImageSizes.cornerRadiusInset.closed
            if let scale = cornerRadiusScaleFactor {
                return max(0, base * scale)
            }
            return base
        }()

        return Image(nsImage: musicManager.albumArt)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: closedCornerRadius)
            )
            .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
            .frame(
                width: scaledArtSize,
                height: scaledArtSize
            )
    }

    private func compactTimerRingProgress(for model: TimerWidgetModel) -> CGFloat {
        guard model.mode == .timer else { return 1 }
        let progress = max(0.02, 1 - model.countdownState.progress)
        return CGFloat(min(max(progress, 0.02), 1))
    }

    private func compactTimerIconName(for model: TimerWidgetModel) -> String {
        if model.mode == .stopwatch { return "stopwatch" }
        return model.countdownState.phase == .finished ? "bell.fill" : "timer"
    }

    private func compactTimerPrimaryText(for model: TimerWidgetModel) -> String {
        return model.displayTime
    }

    private func compactTimerAccentColor(for model: TimerWidgetModel) -> Color {
        widgetAccent
    }

}

private struct CalendarTabPageView: View {
    @EnvironmentObject var vm: InterestingViewModel

    var body: some View {
        GeometryReader { geometry in
            HStack {
                let expandedCalendarWidth = max(CGFloat(215), geometry.size.width - 24)

                FullTabCalendarView()
                    .frame(width: expandedCalendarWidth, alignment: .topLeading)
                    .onHover { isHovering in
                        vm.isHoveringCalendar = isHovering
                    }
                    .environmentObject(vm)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .padding(.top, 2)
        }
    }
}

private struct CompactRecorderWaveformView: View {
    let levels: [Float]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard !levels.isEmpty else { return }

            let spacing: CGFloat = 1
            let barWidth = max(1, (size.width - spacing * CGFloat(levels.count - 1)) / CGFloat(levels.count))
            let centerY = size.height / 2
            let maxHeight = max(1, size.height * 0.42)

            for (index, level) in levels.enumerated() {
                let x = CGFloat(index) * (barWidth + spacing)
                let height = max(1.5, CGFloat(level) * maxHeight)
                let rect = CGRect(
                    x: x,
                    y: centerY - height,
                    width: barWidth,
                    height: height * 2
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(color.opacity(0.35 + 0.65 * Double(index) / Double(max(levels.count - 1, 1))))
                )
            }
        }
        .drawingGroup()
    }
}

struct FullScreenDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: () -> Void

    func dropEntered(info _: DropInfo) {
        isTargeted = true
    }

    func dropExited(info _: DropInfo) {
        isTargeted = false
    }

    func performDrop(info _: DropInfo) -> Bool {
        isTargeted = false
        onDrop()
        return true
    }

}

struct GeneralDropTargetDelegate: DropDelegate {
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        return false
    }
}

#Preview {
    let vm = InterestingViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
