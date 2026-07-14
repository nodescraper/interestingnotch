//
//  ContentView.swift
//  boringNotchApp
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

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared

    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var widgetEngine = WidgetEngine.shared
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

    @State private var haptics: Bool = false

    @Namespace var albumArtNamespace
    @Namespace private var widgetNamespace

    @Default(.showNotHumanFace) var showNotHumanFace
    @Default(.systemMonitorSneakPeekEnabled) private var systemMonitorSneakPeekEnabled
    @Default(.accessoryBatterySneakPeekEnabled) private var accessoryBatterySneakPeekEnabled

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
        } else if coordinator.expandingView.type == .colorPicker && coordinator.expandingView.show
            && vm.notchState == .closed
        {
            chinWidth = compactColorPickerWidth
        } else if coordinator.shouldShowSneakPeek(on: vm.screenUUID)
            && coordinator.sneakPeekState(for: vm.screenUUID).type == .systemMonitor
            && vm.notchState == .closed
        {
            chinWidth = compactSystemMonitorWidth
        } else if coordinator.shouldShowSneakPeek(on: vm.screenUUID)
            && coordinator.sneakPeekState(for: vm.screenUUID).type == .accessoryBattery
            && vm.notchState == .closed
        {
            chinWidth = compactAccessoryBatteryWidth
        } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, displayClosedNotchHeight - 12) + 20 + 2 * liveActivityEdgeMargin + 2)
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

    private var systemMonitorCompactMetricWidth: CGFloat {
        vm.hasNotch ? 88 : 78
    }

    private var compactSystemMonitorWidth: CGFloat {
        vm.closedNotchSize.width - 4
            + (2 * liveActivityEdgeMargin)
            + (systemMonitorCompactMetricCount * systemMonitorCompactMetricWidth)
    }

    private var accessoryBatteryCompactNameWidth: CGFloat {
        vm.hasNotch ? 112 : 96
    }

    private var accessoryBatteryCompactValueWidth: CGFloat {
        vm.hasNotch ? 60 : 52
    }

    private var compactAccessoryBatteryWidth: CGFloat {
        vm.closedNotchSize.width - 4
            + (2 * liveActivityEdgeMargin)
            + accessoryBatteryCompactNameWidth
            + accessoryBatteryCompactValueWidth
    }

    private var systemMonitorCompactMetricCount: CGFloat {
        let leftCount = Defaults[.systemMonitorSneakPeekLeftMetric] == .none ? 0 : 1
        let rightCount = Defaults[.systemMonitorSneakPeekRightMetric] == .none ? 0 : 1
        return CGFloat(leftCount + rightCount)
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
                    .frame(height: vm.notchState == .open ? vm.notchSize.height : nil)
                    .conditionalModifier(true) { view in
                        return view
                            .animation(vm.notchState == .open ? StandardAnimations.open : StandardAnimations.close, value: vm.notchState)
                            .animation(.smooth, value: gestureProgress)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
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
                    .conditionalModifier(Defaults[.closeGestureEnabled] && Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .up) { translation, phase in
                                handleUpGesture(translation: translation, phase: phase)
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
                        if vm.notchState == .open && !isHovering && !vm.isBatteryPopoverActive {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if self.vm.notchState == .open && !self.isHovering && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
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

                        syncSystemMonitorSneakPeek()
                        syncAccessoryBatterySneakPeek()
                    }
                    .onChange(of: vm.isBatteryPopoverActive) {
                        if !vm.isBatteryPopoverActive && !isHovering && vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if !self.vm.isBatteryPopoverActive && !self.isHovering && self.vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: coordinator.currentView) { _, _ in
                        syncSystemMonitorSneakPeek()
                        syncAccessoryBatterySneakPeek()
                    }
                    .onChange(of: systemMonitorSneakPeekEnabled) { _, _ in
                        syncSystemMonitorSneakPeek()
                    }
                    .onChange(of: accessoryBatterySneakPeekEnabled) { _, _ in
                        syncAccessoryBatterySneakPeek()
                    }
                    .onChange(of: widgetEngine.widgets.count) { _, _ in
                        syncSystemMonitorSneakPeek()
                        syncAccessoryBatterySneakPeek()
                    }
                    .onReceive(widgetEngine.objectWillChange) { _ in
                        syncSystemMonitorSneakPeek()
                        syncAccessoryBatterySneakPeek()
                    }
                    .onAppear {
                        syncSystemMonitorSneakPeek()
                        syncAccessoryBatterySneakPeek()
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
                if Defaults[.boringShelf] && vm.notchState == .closed {
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
                                BoringBatteryView(
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
                      } else if coordinator.shouldShowSneakPeek(on: vm.screenUUID) && coordinator.sneakPeekState(for: vm.screenUUID).type == .timer && vm.notchState == .closed {
                          TimerLiveActivity(animationNamespace: widgetNamespace)
                              .allowsHitTesting(false)
                              .frame(width: compactTimerWidth, height: displayClosedNotchHeight, alignment: .center)
                      } else if coordinator.shouldShowSneakPeek(on: vm.screenUUID) && coordinator.sneakPeekState(for: vm.screenUUID).type == .systemMonitor && vm.notchState == .closed {
                          SystemMonitorLiveActivity()
                              .allowsHitTesting(false)
                              .frame(width: compactSystemMonitorWidth, height: displayClosedNotchHeight, alignment: .center)
                      } else if coordinator.shouldShowSneakPeek(on: vm.screenUUID) && coordinator.sneakPeekState(for: vm.screenUUID).type == .accessoryBattery && vm.notchState == .closed {
                          AccessoryBatteryLiveActivity()
                              .allowsHitTesting(false)
                              .frame(width: compactAccessoryBatteryWidth, height: displayClosedNotchHeight, alignment: .center)
                      } else if coordinator.shouldShowSneakPeek(on: vm.screenUUID) && Defaults[.inlineOSD] && (coordinator.sneakPeekState(for: vm.screenUUID).type != .music) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .battery) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .timer) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .systemMonitor) && vm.notchState == .closed {
                          InlineOSD(
                              type: coordinator.binding(for: vm.screenUUID).type,
                              value: coordinator.binding(for: vm.screenUUID).value,
                              icon: coordinator.binding(for: vm.screenUUID).icon,
                              accent: coordinator.binding(for: vm.screenUUID).accent,
                              hoverAnimation: $isHovering,
                              gestureProgress: $gestureProgress
                          )
                              .transition(.opacity)
                      } else if coordinator.expandingView.type == .colorPicker && coordinator.expandingView.show && vm.notchState == .closed {
                          ColorPickerLiveActivity()
                              .allowsHitTesting(false)
                              .frame(width: compactColorPickerWidth, height: displayClosedNotchHeight, alignment: .center)
                      } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music) && vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle) && coordinator.musicLiveActivityEnabled && !vm.hideOnClosed {
                          MusicLiveActivity()
                              .frame(alignment: .center)
                      } else if !coordinator.expandingView.show && vm.notchState == .closed && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace] && !vm.hideOnClosed  {
                          BoringFaceAnimation()
                       } else if vm.notchState == .open {
                           BoringHeader()
                               .frame(height: max(24, displayClosedNotchHeight))
                               .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
                       }
                        // Use the resolved configured height on every display type.
                       else {
                           Rectangle().fill(.clear).frame(width: vm.closedNotchSize.width - 20, height: displayClosedNotchHeight)
                       }

                      if coordinator.shouldShowSneakPeek(on: vm.screenUUID) {
                          if (coordinator.sneakPeekState(for: vm.screenUUID).type != .music) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .battery) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .timer) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .systemMonitor) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .accessoryBattery) && !Defaults[.inlineOSD] && vm.notchState == .closed {
                              SystemEventIndicatorModifier(
                                  eventType: coordinator.binding(for: vm.screenUUID).type,
                                  value: coordinator.binding(for: vm.screenUUID).value,
                                  icon: coordinator.binding(for: vm.screenUUID).icon,
                                  accent: coordinator.binding(for: vm.screenUUID).accent,
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
              .conditionalModifier((coordinator.shouldShowSneakPeek(on: vm.screenUUID) && (coordinator.sneakPeekState(for: vm.screenUUID).type == .music) && vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard) || (coordinator.shouldShowSneakPeek(on: vm.screenUUID) && (coordinator.sneakPeekState(for: vm.screenUUID).type != .music) && (vm.notchState == .closed))) { view in
                  view
                      .fixedSize()
              }
              .zIndex(1)
            if vm.notchState == .open {
                VStack {
                    switch coordinator.currentView {
                    case .home:
                        NotchHomeView(
                            albumArtNamespace: albumArtNamespace,
                            horizontalMediaGestureFeedback: horizontalMediaGestureFeedback,
                            isHoveringMusicArea: $isHoveringMusicArea
                        )
                    case .calendar:
                        CalendarTabPageView()
                    case .shelf:
                        ShelfView()
                    case .widget(let id):
                        WidgetTabPageView(widgetID: id, animationNamespace: widgetNamespace)
                    }
                }
                .transition(
                    .scale(scale: 0.8, anchor: .top)
                    .combined(with: .opacity)
                    .animation(.smooth(duration: 0.35))
                )
                .zIndex(1)
                .allowsHitTesting(vm.notchState == .open)
                .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
            }
        }
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
    }

    @ViewBuilder
    func BoringFaceAnimation() -> some View {
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

            Image(nsImage: musicManager.albumArt)
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
                    displayClosedNotchHeight - 12
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
    func SystemMonitorLiveActivity() -> some View {
        if let widget = compactSystemMonitorWidget {
        SystemMonitorLiveActivityView(
            widget: widget,
            metricWidth: systemMonitorCompactMetricWidth,
            centerWidth: vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin),
                totalWidth: compactSystemMonitorWidth,
                height: displayClosedNotchHeight
            )
        }
    }

    @ViewBuilder
    func AccessoryBatteryLiveActivity() -> some View {
        if let device = compactAccessoryBatteryPrimaryDevice {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: device.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(device.isCritical ? .red : .white.opacity(0.78))

                    Text(device.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(width: accessoryBatteryCompactNameWidth, height: displayClosedNotchHeight, alignment: .leading)

                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 4 + (2 * liveActivityEdgeMargin))

                HStack(spacing: 4) {
                    if device.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Text(device.primaryDisplay)
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(device.isCritical ? .red : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: accessoryBatteryCompactValueWidth, height: displayClosedNotchHeight, alignment: .trailing)
                .padding(.trailing, 4)
            }
            .frame(width: compactAccessoryBatteryWidth, height: displayClosedNotchHeight, alignment: .center)
        }
    }

    @ViewBuilder
    var dragDetector: some View {
        if Defaults[.boringShelf] && vm.notchState == .closed {
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
                    
                    if self.vm.notchState == .open && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                        self.vm.close()
                        self.syncSystemMonitorSneakPeek()
                        self.syncAccessoryBatterySneakPeek()
                    }
                }
            }
        }
    }

    private var allowsHoverDuringSneakPeek: Bool {
        switch coordinator.sneakPeekState(for: vm.screenUUID).type {
        case .timer, .systemMonitor, .colorPicker, .accessoryBattery:
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

    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .open && !vm.isHoveringCalendar else { return }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * -20
        }

        if phase == .ended {
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
        }

        if translation > Defaults[.gestureSensitivity] {
            withAnimation(animationSpring) {
                isHovering = false
            }
            if !SharingStateManager.shared.preventNotchClose { 
                gestureProgress = .zero
                vm.close()
            }

            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
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

    private var compactSystemMonitorWidget: Widget? {
        widgetEngine.widgets.first(where: { $0.id == "system-monitor" })
    }

    private var compactAccessoryBatteryWidget: Widget? {
        widgetEngine.widgets.first(where: { $0.id == "accessory-battery" })
    }

    private var compactAccessoryBatteryPrimaryDevice: AccessoryBatteryDeviceSnapshot? {
        guard let widget = compactAccessoryBatteryWidget,
              let snapshot = AccessoryBatterySnapshot(widgetValue: widget.lastValue) else {
            return nil
        }

        return snapshot.primaryDevice(preferredID: Defaults[.accessoryBatteryPrimaryDeviceID])
    }

    private func syncSystemMonitorSneakPeek() {
        guard compactSystemMonitorWidget != nil, systemMonitorSneakPeekEnabled else {
            coordinator.toggleSneakPeek(status: false, type: .systemMonitor, targetScreenUUID: vm.screenUUID)
            return
        }

        coordinator.toggleSneakPeek(
            status: vm.notchState == .closed,
            type: .systemMonitor,
            duration: 0,
            targetScreenUUID: vm.screenUUID
        )
    }

    private func syncAccessoryBatterySneakPeek() {
        guard compactAccessoryBatteryPrimaryDevice != nil, accessoryBatterySneakPeekEnabled else {
            coordinator.toggleSneakPeek(status: false, type: .accessoryBattery, targetScreenUUID: vm.screenUUID)
            return
        }

        coordinator.toggleSneakPeek(
            status: vm.notchState == .closed,
            type: .accessoryBattery,
            duration: 0,
            targetScreenUUID: vm.screenUUID
        )
    }
}

private struct CalendarTabPageView: View {
    @EnvironmentObject var vm: BoringViewModel

    var body: some View {
        GeometryReader { geometry in
            HStack {
                let expandedCalendarWidth = max(CGFloat(215), geometry.size.width - 24)

                CalendarView(expandsToFill: true)
                    .frame(width: expandedCalendarWidth, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .onHover { isHovering in
                        vm.isHoveringCalendar = isHovering
                    }
                    .environmentObject(vm)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .padding(.top, 2)
        }
    }
}

private extension Widget {
    var compactSystemMonitorSnapshot: SystemMonitorSnapshot? {
        SystemMonitorSnapshot(widgetValue: lastValue)
    }
}

private struct SystemMonitorCompactMetricView: View {
    let label: String
    let symbolName: String
    let displayValue: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.56))

            Text(displayValue)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct SystemMonitorLiveActivityView: View {
    @ObservedObject var widget: Widget

    let metricWidth: CGFloat
    let centerWidth: CGFloat
    let totalWidth: CGFloat
    let height: CGFloat

    private var rightMetric: SystemMonitorSneakPeekMetric {
        Defaults[.systemMonitorSneakPeekRightMetric]
    }

    private var leftMetric: SystemMonitorSneakPeekMetric {
        Defaults[.systemMonitorSneakPeekLeftMetric]
    }

    private var snapshot: SystemMonitorSnapshot? {
        widget.compactSystemMonitorSnapshot
    }

    var body: some View {
        HStack(spacing: 0) {
            if leftMetric != .none {
                SystemMonitorCompactMetricView(
                    label: leftMetric.title,
                    symbolName: leftMetric.symbolName,
                    displayValue: snapshot?.displayValue(for: leftMetric) ?? "--%"
                )
                .frame(width: metricWidth, height: height, alignment: .leading)
            }

            Rectangle()
                .fill(.black)
                .frame(width: centerWidth)

            if rightMetric != .none {
                SystemMonitorCompactMetricView(
                    label: rightMetric.title,
                    symbolName: rightMetric.symbolName,
                    displayValue: snapshot?.displayValue(for: rightMetric) ?? "--%"
                )
                .frame(width: metricWidth, height: height, alignment: .trailing)
            }
        }
        .frame(width: totalWidth, height: height, alignment: .center)
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
    let vm = BoringViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
