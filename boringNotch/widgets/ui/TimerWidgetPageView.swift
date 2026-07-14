//
//  TimerWidgetPageView.swift
//  InterestingNotch
//

import SwiftUI
import AppKit

struct TimerWidgetPageView: View {
    let widget: Widget

    @ObservedObject var model: TimerWidgetModel
    let animationNamespace: Namespace.ID?

    private let orange = Color(red: 0.96, green: 0.58, blue: 0.24)
    private let orangeSurface = Color(red: 0.19, green: 0.10, blue: 0.04)
    // Reset button: muted neutral surface + softer orange text (iPhone secondary-button feel).
    private let resetSurface = Color(red: 0.16, green: 0.16, blue: 0.17)

    // Ruler scale, in minutes.
    private let minMinute = 0
    private let maxMinute = 60
    private let pointsPerMinute: CGFloat = 9.5   // horizontal spacing between ticks

    // Sensitivity (higher = less sensitive / more precise).
    private let dragSensitivity: CGFloat = 90    // pts of click-drag travel per minute
    private let scrollSensitivity: CGFloat = 90  // accumulated scroll units per minute

    // Live scrub offset while dragging (in minutes, fractional). nil = not dragging.
    @State private var dragMinutes: Double?

    // Last whole-minute value we fired a haptic tick on, to avoid repeats.
    @State private var lastHapticMinute: Int?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                // Mode picker pinned near the top in a fixed-height slot so it never
                // shifts between Timer and Stopwatch. Fades out (space kept) while a
                // timer is actively counting, where switching isn't allowed.
                modePicker
                    .opacity(showsTimerControls ? 0 : 1)
                    .allowsHitTesting(!showsTimerControls)
                    .frame(height: pickerHeight)
                    .animation(.easeInOut(duration: 0.25), value: showsTimerControls)

                // Content below the picker changes per mode/state, centered vertically
                // in the remaining space so the running controls settle in the middle.
                ZStack {
                    if model.mode == .stopwatch {
                        controlsLayout(label: "Stopwatch", time: model.displayTime, isTimer: false)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity))
                    } else if showsTimerControls {
                        controlsLayout(label: "Timer", time: model.displayTime, isTimer: true)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity))
                    } else {
                        idleLayout(geometry: geometry)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: 128)
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showsTimerControls)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: model.mode)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timer")
        .accessibilityValue(model.accessibilitySummary)
    }

    /// True when the timer has been started and hasn't finished/been cancelled —
    /// i.e. running OR paused mid-countdown. Stays on the controls layout until reset.
    ///
    /// NOTE: adjust the right-hand side to your model. If TimerWidgetModel has an
    /// `isPaused` (or `hasStarted`/`isActive`) flag, OR it in here so pausing keeps
    /// this layout. With only `isRunning`, pausing will drop back to the ruler.
    private var showsTimerControls: Bool {
        model.isRunning
    }

    // MARK: - Idle layout (ruler + Start/Reset)

    private func idleLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 10) {
            // Top: mode picker + scrolling ruler
            scrollingRuler

            // Bottom: Start (left) ... time (right)
            HStack(alignment: .center, spacing: 10) {
                startButton

                Spacer(minLength: 12)

                Text(liveDisplayTime)
                    .font(.system(size: 34, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(orange)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Controls layout (round Pause/Resume + Reset/Cancel, big time)

    /// Shared round-button layout used by the running Timer and by the Stopwatch.
    private func controlsLayout(label: String, time: String, isTimer: Bool) -> some View {
        HStack(alignment: .center, spacing: 13) {
            pauseCircleButton
            cancelCircleButton(isTimer: isTimer)

            Spacer(minLength: 12)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(label)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(orange)

                Text(time)
                    .font(.system(size: 48, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(orange)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    private var pauseCircleButton: some View {
        Button {
            model.toggleStartPause()
        } label: {
            Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(orange)
                .frame(width: 58, height: 58)
                .background(orangeSurface, in: Circle())
        }
        .help(model.isRunning ? "Pause" : "Resume")
    }

    private func cancelCircleButton(isTimer: Bool) -> some View {
        Button {
            model.reset()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(resetSurface, in: Circle())
        }
        .help(isTimer ? "Cancel" : "Reset")
    }

    private var startButton: some View {
        Button {
            model.toggleStartPause()
        } label: {
            Text(model.isRunning
                 ? "Pause"
                 : "Start")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(orange)
                .frame(minWidth: 66, minHeight: 32)
                .background(orangeSurface, in: Capsule())
        }
        .help(model.isRunning ? "Pause" : "Start")
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        HStack(spacing: 0) {
            modeTab(title: "Timer", mode: .timer)
            modeTab(title: "Stopwatch", mode: .stopwatch)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .frame(width: 162)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func modeTab(title: String, mode tabMode: TimerWidgetMode) -> some View {
        let isActive = model.mode == tabMode
        return Button {
            model.setMode(tabMode)
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .foregroundStyle(isActive ? .white : .white.opacity(0.72))
                .background(
                    isActive ? Color.white.opacity(0.18) : .clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
    }

    // MARK: - Scrolling ruler

    // Fixed heights for the ruler window.
    private let pickerHeight: CGFloat = 24   // fixed slot so the picker never shifts
    private let rulerHeight: CGFloat = 46
    private let labelHeight: CGFloat = 14
    private let tickHeight: CGFloat = 19

    private var scrollingRuler: some View {
        VStack(spacing: 6) {
            if model.mode == .timer {
                GeometryReader { geo in
                    let width = geo.size.width
                    let center = width / 2

                    // Fractional value while scrubbing, else the model's duration.
                    let raw = dragMinutes ?? Double(model.durationMinutes)
                    let clamped = min(max(raw, Double(minMinute)), Double(maxMinute))
                    let highlightTo = clamped.rounded()

                    // Single Canvas draw for the whole ruler. Only visible ticks are
                    // drawn (offscreen ones are culled), so cost is constant regardless
                    // of maxMinute. No per-tick SwiftUI views = far cheaper scrubbing.
                    Canvas { ctx, size in
                        // x for a given minute, already accounting for the scroll shift.
                        func x(_ minute: Int) -> CGFloat {
                            center + CGFloat(Double(minute) - clamped) * pointsPerMinute
                        }
                        // Only iterate minutes that can land inside the visible window.
                        let first = max(minMinute, Int(clamped - Double(center / pointsPerMinute)) - 1)
                        let last  = min(maxMinute, Int(clamped + Double(center / pointsPerMinute)) + 1)
                        guard first <= last else { return }

                        for minute in first...last {
                            let px = x(minute)
                            let bright = Double(minute) <= highlightTo
                            let isMajor = minute % 5 == 0

                            // Tick
                            let tickColor = bright ? orange : orange.opacity(0.32)
                            var rect = Path()
                            let tx = px - 1
                            rect.addRect(CGRect(x: tx, y: labelHeight + 4, width: 2, height: tickHeight))
                            ctx.fill(rect, with: .color(tickColor))

                            // Label every 5 minutes
                            if isMajor {
                                let labelColor = bright ? orange : orange.opacity(0.45)
                                let text = Text("\(minute)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(labelColor)
                                ctx.draw(text, at: CGPoint(x: px, y: labelHeight / 2), anchor: .center)
                            }
                        }

                        // Fixed marker triangle just below the ticks, pointing up.
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
                        // Captures trackpad two-finger scroll / mouse wheel precisely.
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
                            .onEnded { _ in
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
            } else {
                // Stopwatch has no ruler — keep the row height stable.
                Color.clear.frame(height: rulerHeight)
            }
        }
    }

    /// Fires a subtle haptic tick when the scrubbed value crosses a new whole
    /// minute — like the detents on Apple's wheel pickers.
    private func hapticIfMinuteChanged(_ raw: Double) {
        let minute = Int(raw.rounded())
        guard minute != lastHapticMinute else { return }
        lastHapticMinute = minute
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment, performanceTime: .now
        )
    }

    /// While scrubbing, show the live (rounded) minute value; otherwise the model's own readout.
    private var liveDisplayTime: String {
        guard let dm = dragMinutes else { return model.displayTime }
        let minutes = max(1, min(max(Int(dm.rounded()), minMinute), maxMinute))
        return String(format: "%02d:00", minutes)
    }
}

/// Captures trackpad two-finger scroll and mouse-wheel events precisely on macOS,
/// where SwiftUI's DragGesture reports scroll as oversized translation values.
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

    final class ScrollCatcherView: NSView {
        var onScroll: ((CGFloat, CGFloat) -> Void)?
        var onEnded: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            // scrollingDeltaX/Y give smooth, precise values on trackpads.
            onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
            if event.phase == .ended || event.momentumPhase == .ended {
                onEnded?()
            }
        }
    }
}

#Preview("Timer Widget") {
    TimerWidgetPreviewHost()
        .frame(width: 1280, height: 360)
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
