//
//  InterestingHeader.swift
//  InterestingNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import SwiftUI

struct InterestingHeader: View {
    @EnvironmentObject var vm: InterestingViewModel
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = InterestingViewCoordinator.shared
    @ObservedObject var caffeineManager = CaffeineManager.shared
    @StateObject var tvm = ShelfStateViewModel.shared
    @AppStorage("caffeineEnabled") private var caffeineEnabled = true
    @Default(.pinnedWidgetIDs) private var pinnedWidgetIDs
    @Default(.showPinButton) private var showPinButton
    @Default(.pinNotchOpen) private var pinNotchOpen
    @State private var headerSwipeTriggered = false
    @State private var lastHeaderSwipeDate: Date = .distantPast
    @State private var haptics = false

    private var shouldShowTabs: Bool {
        (!tvm.isEmpty && Defaults[.interestingShelf])
            || !pinnedWidgetIDs.isEmpty
            || coordinator.alwaysShowTabs
    }

    private var orderedTabs: [TabModel] {
        TabSelectionModelBuilder.allTabs(
            interestingShelf: Defaults[.interestingShelf],
            pinnedWidgetIDs: pinnedWidgetIDs,
            availableWidgets: WidgetEngine.shared.widgets
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                if shouldShowTabs {
                    TabSelectionView()
                } else if vm.notchState == .open {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)

            if vm.notchState == .open {
                Rectangle()
                    .fill(NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask {
                        NotchShape()
                    }
            }

            HStack(spacing: 4) {
                if vm.notchState == .open {
                    if isOSDType(coordinator.sneakPeekState(for: vm.screenUUID).type) && coordinator.shouldShowSneakPeek(on: vm.screenUUID) && Defaults[.showOpenNotchOSD] {
                        OpenNotchOSD(
                             type: coordinator.binding(for: vm.screenUUID).type,
                             value: coordinator.binding(for: vm.screenUUID).value,
                             icon: coordinator.binding(for: vm.screenUUID).icon,
                             accent: coordinator.binding(for: vm.screenUUID).accent
                        )
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        if Defaults[.showMirror] {
                            headerIconButton(systemName: "web.camera") {
                                vm.toggleCameraPreview()
                            }
                        }
                        if caffeineEnabled {
                            caffeineButton
                        }
                        headerIconButton(systemName: "square.grid.2x2") {
                            DispatchQueue.main.async {
                                WorkshopWindowController.shared.showWindow()
                            }
                        }
                        if showPinButton {
                            headerIconButton(
                                systemName: pinNotchOpen ? "pin.fill" : "pin",
                                isSelected: pinNotchOpen
                            ) {
                                pinNotchOpen.toggle()
                            }
                        }
                        if Defaults[.settingsIconInNotch] {
                            headerIconButton(systemName: "gear") {
                                DispatchQueue.main.async {
                                    SettingsWindowController.shared.showWindow()
                                }
                            }
                        }
                        if Defaults[.showBatteryIndicator] {
                            InterestingBatteryView(
                                batteryWidth: 30,
                                isCharging: batteryModel.isCharging,
                                isInLowPowerMode: batteryModel.isInLowPowerMode,
                                isPluggedIn: batteryModel.isPluggedIn,
                                levelBattery: batteryModel.levelBattery,
                                maxCapacity: batteryModel.maxCapacity,
                                timeToFullCharge: batteryModel.timeToFullCharge,
                                timeToDischarge: batteryModel.timeToDischarge,
                                isForNotification: false
                            )
                        }
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
        .contentShape(Rectangle())
        .conditionalModifier(vm.notchState == .open && shouldShowTabs && Defaults[.enableGestures]) { view in
            view
                .panGesture(direction: .left) { translation, phase in
                    handleHeaderTabSwipe(translation: translation, phase: phase, step: -1)
                }
                .panGesture(direction: .right) { translation, phase in
                    handleHeaderTabSwipe(translation: translation, phase: phase, step: 1)
                }
        }
        .onChange(of: caffeineEnabled) {
            if !caffeineEnabled {
                caffeineManager.deactivate()
            }
        }
        .sensoryFeedback(.alignment, trigger: haptics)
    }

    private var caffeineButton: some View {
        Button {
            caffeineManager.toggle()
        } label: {
            Image(systemName: caffeineManager.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .foregroundColor(caffeineManager.isActive ? .effectiveAccent : .gray)
                .imageScale(.medium)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("15 minutes") { caffeineManager.activate(for: 15 * 60) }
            Button("1 hour") { caffeineManager.activate(for: 60 * 60) }
            Button("2 hours") { caffeineManager.activate(for: 2 * 60 * 60) }
            Divider()
            Button("Until off") { caffeineManager.activate() }
            Button("Turn off", role: .destructive) { caffeineManager.deactivate() }
        }
        .help(caffeineManager.isActive ? "Caffeine on" : "Keep Mac awake")
    }

    private func headerIconButton(
        systemName: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Capsule()
                .fill(isSelected ? Color(nsColor: .secondarySystemFill) : .black)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: systemName)
                        .foregroundColor(.white)
                        .padding()
                        .imageScale(.medium)
                }
        }
        .buttonStyle(PlainButtonStyle())
    }

    func isOSDType(_ type: SneakContentType) -> Bool {
        switch type {
        case .volume, .brightness, .backlight, .mic:
            return true
        default:
            return false
        }
    }

    private func handleHeaderTabSwipe(translation: CGFloat, phase: NSEvent.Phase, step: Int) {
        guard shouldShowTabs else { return }

        if phase == .ended {
            headerSwipeTriggered = false
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastHeaderSwipeDate) > 0.35 else { return }
        guard !headerSwipeTriggered else { return }
        guard translation > Defaults[.gestureSensitivity] else { return }

        guard let currentIndex = orderedTabs.firstIndex(where: { $0.view == coordinator.currentView }) else {
            return
        }

        let nextIndex = min(max(currentIndex + step, 0), orderedTabs.count - 1)
        guard nextIndex != currentIndex else { return }

        headerSwipeTriggered = true
        lastHeaderSwipeDate = now
        withAnimation(.smooth) {
            coordinator.currentView = orderedTabs[nextIndex].view
        }

        if Defaults[.enableHaptics] {
            haptics.toggle()
        }
    }
}

#Preview {
    InterestingHeader().environmentObject(InterestingViewModel())
}
