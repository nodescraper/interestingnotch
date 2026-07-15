//
//  TimerWidgetPageView.swift
//  InterestingNotch
//
//  Shares the Voice Recorder's structure: a title row (title + caption on the
//  left, icon-only mode pill on the right), the ruler in the middle slot, and a
//  bottom row with a circular start button and the big time. View changes keep
//  the smooth asymmetric transitions.
//

import SwiftUI
import AppKit
import Defaults

struct TimerWidgetPageView: View {
    @EnvironmentObject private var vm: InterestingViewModel
    @ObservedObject private var coordinator = InterestingViewCoordinator.shared

    let widget: Widget

    @ObservedObject var model: TimerWidgetModel
    let animationNamespace: Namespace.ID?

    @State private var timerAccent = Color.effectiveAccent

    private var orange: Color { timerAccent }
    private var orangeSurface: Color { timerAccent.opacity(0.18) }
    private let resetSurface = Color(red: 0.16, green: 0.16, blue: 0.17)

    // Shared sizing with the recorder.
    private let circleButtonSize: CGFloat = 44
    private let bigTimeSize: CGFloat = 32

    // Ruler scale, in minutes.
    private let minMinute = 0
    private let maxMinute = 120
    private let pointsPerMinute: CGFloat = 9.5

    // Sensitivity (higher = less sensitive / more precise).
    private let dragSensitivity: CGFloat = 140
    private let scrollSensitivity: CGFloat = 90

    // Ruler heights.
    private let rulerHeight: CGFloat = 46
    private let labelHeight: CGFloat = 14
    private let tickHeight: CGFloat = 19

    // Live scrub offset while dragging (in minutes, fractional). nil = not dragging.
    @State private var dragMinutes: Double?
    // Last whole-minute value we fired a haptic tick on, to avoid repeats.
    @State private var lastHapticMinute: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow

            // Middle slot swaps between the ruler and the running/finished controls,
            // with the same smooth transitions as before.
            ZStack {
                if isFinishedTimer {
                    finishedControls
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity))
                } else if showsTimerControls {
                    runningControls
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity))
                } else {
                    idleControls
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showsTimerControls)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isFinishedTimer)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: model.mode)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timer")
        .accessibilityValue(model.accessibilitySummary)
        .onAppear { timerAccent = .effectiveAccent }
        .onReceive(NotificationCenter.default.publisher(for: .accentColorChanged)) { _ in
            timerAccent = .effectiveAccent
        }
        .onReceive(Defaults.publisher(.useCustomAccentColor)) { _ in
            timerAccent = .effectiveAccent
        }
    }

    private var showsTimerControls: Bool {
        switch model.mode {
        case .timer:
            return model.countdownState.isActive || model.countdownState.phase == .finished
        case .stopwatch:
            return model.stopwatchState.phase != .idle
        }
    }

    private var isFinishedTimer: Bool {
        model.mode == .timer && model.countdownState.phase == .finished
    }

    // MARK: - Title row (recorder style: title + caption, pill on the right)

    private var titleRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(showsTimerControls ? orange : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(captionText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            // Mode pill only shows when idle (can't switch mid-run).
            if !showsTimerControls {
                modePill
                    .transition(.opacity)
            }
        }
    }

    private var titleText: String {
        model.mode == .stopwatch ? "Stopwatch" : "Timer"
    }

    private var captionText: String {
        if isFinishedTimer { return "Time's up" }
        if showsTimerControls { return model.mode == .stopwatch ? "Counting up" : "Counting down" }
        return model.mode == .stopwatch ? "Track elapsed time" : "Scroll to set the duration"
    }

    // MARK: - Idle controls (ruler + circle start + big time)

    private var idleControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if model.mode == .timer {
                    scrollingRuler
                } else {
                    Color.clear.frame(height: rulerHeight)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(alignment: .center, spacing: 12) {
                startButton
                Spacer(minLength: 12)
                Text(liveDisplayTime)
                    .font(.system(size: bigTimeSize, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(orange)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Running / finished controls

    private var runningControls: some View {
        HStack(alignment: .center, spacing: 12) {
            pauseCircleButton
            cancelCircleButton(isTimer: model.mode == .timer)
            Spacer(minLength: 12)
            Text(model.displayTime)
                .font(.system(size: bigTimeSize, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(orange)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(height: rulerHeight + 44 + 8, alignment: .center)
    }

    private var finishedControls: some View {
        HStack(alignment: .center, spacing: 12) {
            resetCircleButton
            dismissCircleButton
            Spacer(minLength: 12)
            Text("00:00")
                .font(.system(size: bigTimeSize, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(orange)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(height: rulerHeight + 44 + 8, alignment: .center)
    }

    // MARK: - Mode pill (icon-only)

    private var modePill: some View {
        HStack(spacing: 0) {
            modeTab(symbol: "timer", mode: .timer, help: "Timer")
            modeTab(symbol: "stopwatch", mode: .stopwatch, help: "Stopwatch")
        }
        .padding(3)
        .background(Color.white.opacity(0.07), in: Capsule())
    }

    private func modeTab(symbol: String, mode tabMode: TimerWidgetMode, help: String) -> some View {
        let isActive = model.mode == tabMode
        return Button {
            model.setMode(tabMode)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? .white : .white.opacity(0.6))
                .frame(width: 32, height: 22)
                .background(
                    isActive ? Color.white.opacity(0.18) : .clear,
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .help(help)
    }

    // MARK: - Circle buttons

    private var startButton: some View {
        Button {
            model.toggleStartPause()
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(orange)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .background(orangeSurface, in: Circle())
                .contentShape(Circle())
        }
        .help("Start")
    }

    private var pauseCircleButton: some View {
        Button {
            model.toggleStartPause()
        } label: {
            Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(orange)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .background(orangeSurface, in: Circle())
                .contentShape(Circle())
        }
        .help(model.isRunning ? "Pause" : "Resume")
    }

    private func cancelCircleButton(isTimer: Bool) -> some View {
        Button {
            model.reset()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .background(resetSurface, in: Circle())
                .contentShape(Circle())
        }
        .help(isTimer ? "Cancel" : "Reset")
    }

    private var resetCircleButton: some View {
        Button {
            model.reset()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(orange)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .background(orangeSurface, in: Circle())
                .contentShape(Circle())
        }
        .help("Reset timer")
    }

    private var dismissCircleButton: some View {
        Button {
            coordinator.dismissTemporaryOpenContext(for: model.widgetID)
            vm.close()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .background(resetSurface, in: Circle())
                .contentShape(Circle())
        }
        .help("Dismiss")
    }

    // MARK: - Scrolling ruler

    private var scrollingRuler: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let center = width / 2

            let raw = dragMinutes ?? Double(model.durationMinutes)
            let clamped = min(max(raw, Double(minMinute)), Double(maxMinute))
            let highlightTo = clamped.rounded()

            Canvas { ctx, size in
                func x(_ minute: Int) -> CGFloat {
                    center + CGFloat(Double(minute) - clamped) * pointsPerMinute
                }
                let first = max(minMinute, Int(clamped - Double(center / pointsPerMinute)) - 1)
                let last  = min(maxMinute, Int(clamped + Double(center / pointsPerMinute)) + 1)
                guard first <= last else { return }

                for minute in first...last {
                    let px = x(minute)
                    let bright = Double(minute) <= highlightTo
                    let isMajor = minute % 5 == 0

                    let tickColor = bright ? orange : orange.opacity(0.32)
                    var rect = Path()
                    let tx = px - 1
                    rect.addRect(CGRect(x: tx, y: labelHeight + 4, width: 2, height: tickHeight))
                    ctx.fill(rect, with: .color(tickColor))

                    if isMajor {
                        let labelColor = bright ? orange : orange.opacity(0.45)
                        let text = Text("\(minute)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(labelColor)
                        ctx.draw(text, at: CGPoint(x: px, y: labelHeight / 2), anchor: .center)
                    }
                }

                var tri = Path()
                let mW: CGFloat = 11, mH: CGFloat = 7
                let tickBottom = labelHeight + 4 + tickHeight
                let baseY = tickBottom + mH
                tri.move(to: CGPoint(x: center, y: baseY - mH))
                tri.addLine(to: CGPoint(x: center + mW / 2, y: baseY))
                tri.addLine(to: CGPoint(x: center - mW / 2, y: baseY))
                tri.closeSubpath()
                ctx.fill(tri, with: .color(orange))
            }
            .frame(width: width, height: rulerHeight)
            .contentShape(Rectangle())
            .overlay(
                ScrollCatcher { deltaX, deltaY in
                    let raw = abs(deltaX) > abs(deltaY) ? deltaX : deltaY
                    let base = dragMinutes ?? Double(model.durationMinutes)
                    let deltaMinutes = Double(raw / scrollSensitivity)
                    let next = min(max(base + deltaMinutes, Double(minMinute)), Double(maxMinute))
                    dragMinutes = next
                    hapticIfMinuteChanged(next)
                } onEnded: {
                    if let dm = dragMinutes {
                        model.setDuration(minutes: max(1, min(max(Int(dm.rounded()), minMinute), maxMinute)))
                    }
                    dragMinutes = nil
                    lastHapticMinute = nil
                }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let base = dragMinutes ?? Double(model.durationMinutes)
                        let deltaMinutes = Double(-value.translation.width / dragSensitivity)
                        let next = min(max(base + deltaMinutes, Double(minMinute)), Double(maxMinute))
                        dragMinutes = next
                        hapticIfMinuteChanged(next)
                    }
                    .onEnded { value in
                        // Tap (no real movement) → jump to the minute under the cursor.
                        if abs(value.translation.width) < 4 {
                            let tappedOffset = value.location.x - center
                            let tappedMinute = clamped + Double(tappedOffset / pointsPerMinute)
                            let snapped = min(max(Int(tappedMinute.rounded()), minMinute), maxMinute)
                            model.setDuration(minutes: max(1, snapped))
                            hapticIfMinuteChanged(Double(snapped))
                            dragMinutes = nil
                            lastHapticMinute = nil
                            return
                        }

                        // Drag → settle on the scrubbed value.
                        if let dm = dragMinutes {
                            let snapped = min(max(Int(dm.rounded()), minMinute), maxMinute)
                            model.setDuration(minutes: max(1, snapped))
                        }
                        dragMinutes = nil
                        lastHapticMinute = nil
                    }
            )
        }
        .frame(height: rulerHeight)
    }

    /// Fires a subtle haptic tick when the scrubbed value crosses a new whole minute.
    private func hapticIfMinuteChanged(_ raw: Double) {
        let minute = Int(raw.rounded())
        guard minute != lastHapticMinute else { return }
        lastHapticMinute = minute
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    /// While scrubbing, show the live (rounded) minute value; otherwise the model's own readout.
    private var liveDisplayTime: String {
        guard let dm = dragMinutes else { return model.displayTime }
        let minutes = max(1, min(max(Int(dm.rounded()), minMinute), maxMinute))
        return String(format: "%02d:00", minutes)
    }
}

/// Captures trackpad two-finger scroll and mouse-wheel events anywhere inside
/// the ruler, even when another view is frontmost, via a window-level monitor.
/// Transparent to mouse clicks so the drag gesture underneath still works.
private struct ScrollCatcher: NSViewRepresentable {
    let onScroll: (_ deltaX: CGFloat, _ deltaY: CGFloat) -> Void
    let onEnded: () -> Void

    func makeNSView(context: Context) -> ScrollCatcherView {
        let view = ScrollCatcherView()
        view.onScroll = onScroll
        view.onEnded = onEnded
        return view
    }

    func updateNSView(_ nsView: ScrollCatcherView, context: Context) {
        nsView.onScroll = onScroll
        nsView.onEnded = onEnded
    }

    static func dismantleNSView(_ nsView: ScrollCatcherView, coordinator: ()) {
        nsView.teardownMonitor()
    }

    final class ScrollCatcherView: NSView {
        var onScroll: ((CGFloat, CGFloat) -> Void)?
        var onEnded: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil { installMonitor() } else { teardownMonitor() }
        }

        private func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window == window else { return event }

                // Only handle scroll when the cursor is within this view's bounds.
                let pointInView = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(pointInView) else { return event }

                self.onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
                if event.phase == .ended || event.momentumPhase == .ended {
                    self.onEnded?()
                }
                return nil   // swallow so nothing else double-reacts
            }
        }

        func teardownMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        // Transparent to clicks so the DragGesture underneath receives them.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

#Preview("Timer Widget") {
    TimerWidgetPreviewHost()
        .frame(width: 620, height: 180)
        .background(.black)
}

private struct TimerWidgetPreviewHost: View {
    @MainActor
    private let model = TimerWidgetModel(widgetID: "timer-preview")

    var body: some View {
        if let widget = previewWidget {
            TimerWidgetPageView(widget: widget, model: model, animationNamespace: nil)
        }
    }

    @MainActor
    private var previewWidget: Widget? {
        try? Widget(
            manifest: WidgetManifest(
                schema: 1,
                kind: .interactive,
                id: "timer",
                name: "Timer",
                author: "Preview",
                source: nil,
                extract: nil,
                render: .init(template: .iconLabel, slots: [
                    "icon": .string("timer"),
                    "label": .string("Countdown timer"),
                    "color": .string("accent"),
                ]),
                onTap: nil,
                permissions: nil,
                interactive: .init(type: .timer)
            ),
            interactiveRuntime: model,
            status: .ok
        )
    }
}
