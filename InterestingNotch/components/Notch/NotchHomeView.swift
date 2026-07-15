//
//  NotchHomeView.swift
//  InterestingNotch
//
//  Home-screen composition for the built-in notch widgets.
//

import Defaults
import SwiftUI

struct NotchHomeView: View {
    @EnvironmentObject var vm: InterestingViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
    let albumArtNamespace: Namespace.ID
    let horizontalMediaGestureFeedback: CGFloat
    @Binding var isHoveringMusicArea: Bool

    var body: some View {
        mainContent
            .transition(.opacity)
    }

    private var shouldShowInlineCalendar: Bool {
        Defaults[.showCalendar]
    }

    private var shouldShowCamera: Bool {
        Defaults[.showMirror] && webcamManager.cameraAvailable && vm.isCameraExpanded
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: (shouldShowCamera && shouldShowInlineCalendar) ? 10 : 15) {
            MediaPlayerWidget(
                albumArtNamespace: albumArtNamespace,
                horizontalMediaGestureFeedback: horizontalMediaGestureFeedback,
                isHoveringMusicArea: $isHoveringMusicArea
            )

            if shouldShowInlineCalendar {
                CalendarView()
                    .frame(width: shouldShowCamera ? 170 : 215)
                    .onHover { isHovering in
                        vm.isHoveringCalendar = isHovering
                    }
                    .environmentObject(vm)
                    .transition(.opacity)
            }

            if shouldShowCamera {
                CameraPreviewView(webcamManager: webcamManager)
                    .scaledToFit()
                    .opacity(vm.notchState == .closed ? 0 : 1)
                    .blur(radius: vm.notchState == .closed ? 20 : 0)
                    .animation(
                        .interactiveSpring(response: 0.32, dampingFraction: 0.76, blendDuration: 0),
                        value: shouldShowCamera
                    )
            }
        }
        .blur(radius: vm.notchState == .closed ? 30 : 0)
    }
}
