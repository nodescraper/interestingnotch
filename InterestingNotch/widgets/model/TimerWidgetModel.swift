//
//  TimerWidgetModel.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-13.
//

import Defaults
import Foundation
import SwiftUI

private let defaultTimerPreset = TimerPreset(minutes: 30)
private let timerPresets: [TimerPreset] = [
    .init(minutes: 5),
    .init(minutes: 10),
    .init(minutes: 15),
    .init(minutes: 30),
    .init(minutes: 50),
]

enum TimerWidgetPhase: String, Equatable, Sendable {
    case idle
    case running
    case paused
    case finished
}

/// Which mode the widget is showing.
enum TimerWidgetMode: String, Equatable, Sendable {
    case timer
    case stopwatch
}

struct TimerPreset: Equatable, Hashable, Identifiable, Sendable {
    let minutes: Int

    var id: Int { minutes }
    var duration: TimeInterval { TimeInterval(minutes * 60) }
    var label: String { "\(minutes)m" }
}

struct TimerCountdownState: Equatable, Sendable {
    var duration: TimeInterval
    var remaining: TimeInterval
    var phase: TimerWidgetPhase
    var scheduledEndDate: Date?

    init(
        duration: TimeInterval = defaultTimerPreset.duration,
        remaining: TimeInterval? = nil,
        phase: TimerWidgetPhase = .idle,
        scheduledEndDate: Date? = nil
    ) {
        self.duration = max(1, duration)
        self.remaining = max(0, remaining ?? duration)
        self.phase = phase
        self.scheduledEndDate = scheduledEndDate
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(1 - (remaining / duration), 0), 1)
    }

    var remainingFraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(remaining / duration, 0), 1)
    }

    var isActive: Bool {
        phase == .running || phase == .paused
    }

    var shouldShowCompletionBanner: Bool {
        phase == .finished
    }

    mutating func selectPreset(_ preset: TimerPreset) {
        duration = preset.duration
        remaining = preset.duration
        phase = .idle
        scheduledEndDate = nil
    }

    mutating func start(now: Date) {
        if phase == .finished || remaining <= 0 {
            remaining = duration
        }

        guard phase != .running else { return }

        phase = .running
        scheduledEndDate = now.addingTimeInterval(remaining)
    }

    mutating func pause(now: Date) {
        guard phase == .running else { return }
        tick(now: now)
        phase = .paused
        scheduledEndDate = nil
    }

    mutating func reset() {
        remaining = duration
        phase = .idle
        scheduledEndDate = nil
    }

    mutating func tick(now: Date) {
        guard phase == .running else { return }
        guard scheduledEndDate != nil else {
            phase = .paused
            return
        }

        let updatedRemaining = max(0, scheduledEndDate?.timeIntervalSince(now) ?? 0)
        remaining = updatedRemaining

        if updatedRemaining <= 0 {
            phase = .finished
            scheduledEndDate = nil
        }
    }
}

/// Minimal count-up state for the stopwatch mode.
struct StopwatchState: Equatable, Sendable {
    var elapsed: TimeInterval
    var phase: TimerWidgetPhase          // reuses idle/running/paused
    var startedAt: Date?

    init(elapsed: TimeInterval = 0, phase: TimerWidgetPhase = .idle, startedAt: Date? = nil) {
        self.elapsed = max(0, elapsed)
        self.phase = phase
        self.startedAt = startedAt
    }

    mutating func start(now: Date) {
        guard phase != .running else { return }
        phase = .running
        startedAt = now.addingTimeInterval(-elapsed)
    }

    mutating func pause(now: Date) {
        guard phase == .running else { return }
        tick(now: now)
        phase = .paused
        startedAt = nil
    }

    mutating func reset() {
        elapsed = 0
        phase = .idle
        startedAt = nil
    }

    mutating func tick(now: Date) {
        guard phase == .running, let startedAt else { return }
        elapsed = max(0, now.timeIntervalSince(startedAt))
    }
}

@MainActor
protocol TimerSneakPeekControlling {
    func showTimer(progress: CGFloat, duration: TimeInterval)
    func hideTimer()
}

@MainActor
protocol TimerCompletionPresenting {
    func presentTimerCompletion(widgetID: String)
    func dismissTimerCompletion(widgetID: String)
}

@MainActor
struct SystemTimerSneakPeekController: TimerSneakPeekControlling {
    func showTimer(progress: CGFloat, duration: TimeInterval) {
        InterestingViewCoordinator.shared.toggleSneakPeek(
            status: true,
            type: .timer,
            duration: duration,
            value: progress
        )
    }

    func hideTimer() {
        InterestingViewCoordinator.shared.toggleSneakPeek(
            status: false,
            type: .timer
        )
    }
}

@MainActor
struct SystemTimerCompletionPresenter: TimerCompletionPresenting {
    func presentTimerCompletion(widgetID: String) {
        InterestingViewCoordinator.shared.presentTimerCompletion(widgetID: widgetID)
    }

    func dismissTimerCompletion(widgetID: String) {
        InterestingViewCoordinator.shared.dismissTemporaryOpenContext(for: widgetID)
    }
}

@MainActor
final class TimerWidgetModel: ObservableObject, InteractiveWidgetRuntime {
    static let defaultPreset = defaultTimerPreset
    static let presets: [TimerPreset] = timerPresets

    let interactiveKind: WidgetManifest.Interactive.Kind = .timer
    let widgetID: String

    @Published private(set) var countdownState: TimerCountdownState
    @Published private(set) var stopwatchState: StopwatchState = StopwatchState()
    @Published private(set) var mode: TimerWidgetMode = .timer

    private let now: @Sendable () -> Date
    private let sneakPeekController: any TimerSneakPeekControlling
    private let completionPresenter: any TimerCompletionPresenting
    private var tickerTask: Task<Void, Never>?

    init(
        widgetID: String,
        initialPreset: TimerPreset = defaultTimerPreset,
        countdownState: TimerCountdownState? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        sneakPeekController: (any TimerSneakPeekControlling)? = nil,
        completionPresenter: (any TimerCompletionPresenting)? = nil
    ) {
        self.widgetID = widgetID
        self.now = now
        self.sneakPeekController = sneakPeekController ?? SystemTimerSneakPeekController()
        self.completionPresenter = completionPresenter ?? SystemTimerCompletionPresenter()
        self.countdownState = countdownState ?? TimerCountdownState(duration: initialPreset.duration)
        syncTicker()
        publishSneakPeek()
    }

    deinit {
        tickerTask?.cancel()
    }

    var selectedPreset: TimerPreset? {
        Self.presets.first { Int($0.duration) == Int(countdownState.duration) }
    }

    /// Duration in whole minutes — used by the scrolling ruler.
    var durationMinutes: Int {
        max(0, Int((countdownState.duration / 60).rounded()))
    }

    var displayTime: String {
        let totalSeconds: Int
        switch mode {
        case .timer:
            switch countdownState.phase {
            case .idle:
                totalSeconds = max(0, Int(countdownState.remaining.rounded(.up)))
            case .running, .paused:
                totalSeconds = countdownState.remaining > 0
                    ? max(1, Int(countdownState.remaining.rounded(.down)))
                    : 0
            case .finished:
                totalSeconds = 0
            }
        case .stopwatch:
            totalSeconds = max(0, Int(stopwatchState.elapsed.rounded(.down)))
        }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var phaseTitle: String {
        let phase = mode == .timer ? countdownState.phase : stopwatchState.phase
        switch phase {
        case .idle:
            return mode == .timer ? "Ready" : "Stopwatch"
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        case .finished:
            return "Time's up"
        }
    }

    var accessibilitySummary: String {
        mode == .timer
            ? "\(phaseTitle), \(displayTime) remaining"
            : "\(phaseTitle), \(displayTime) elapsed"
    }

    /// True when the active mode is currently counting.
    var isRunning: Bool {
        mode == .timer
            ? countdownState.phase == .running
            : stopwatchState.phase == .running
    }

    func setMode(_ newMode: TimerWidgetMode) {
        guard newMode != mode else { return }
        dismissCompletionPresentationIfNeeded()
        mode = newMode
        syncTicker()
        publishSneakPeek()
    }

    func selectPreset(_ preset: TimerPreset) {
        dismissCompletionPresentationIfNeeded()
        countdownState.selectPreset(preset)
        syncTicker()
        publishSneakPeek()
    }

    func setDuration(minutes: Int) {
        dismissCompletionPresentationIfNeeded()
        let duration = TimeInterval(max(1, minutes) * 60)
        countdownState = TimerCountdownState(duration: duration)
        syncTicker()
        publishSneakPeek()
    }

    func toggleStartPause() {
        switch mode {
        case .timer:
            switch countdownState.phase {
            case .idle, .paused, .finished:
                dismissCompletionPresentationIfNeeded()
                countdownState.start(now: now())
                countdownState.tick(now: now())
            case .running:
                countdownState.pause(now: now())
            }
        case .stopwatch:
            switch stopwatchState.phase {
            case .running:
                stopwatchState.pause(now: now())
            default:
                stopwatchState.start(now: now())
            }
        }

        syncTicker()
        publishSneakPeek()
    }

    func reset() {
        dismissCompletionPresentationIfNeeded()
        switch mode {
        case .timer:
            countdownState.reset()
        case .stopwatch:
            stopwatchState.reset()
        }
        syncTicker()
        publishSneakPeek()
    }

    func refresh() {
        switch mode {
        case .timer:
            let previousPhase = countdownState.phase
            countdownState.tick(now: now())

            if previousPhase != .finished && countdownState.phase == .finished {
                tickerTask?.cancel()
                tickerTask = nil
                completionPresenter.presentTimerCompletion(widgetID: widgetID)
                publishCompletionSneakPeek()
            } else {
                publishSneakPeek()
            }
        case .stopwatch:
            stopwatchState.tick(now: now())
        }
    }

    private func syncTicker() {
        tickerTask?.cancel()
        tickerTask = nil

        guard isRunning else { return }

        tickerTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.refresh()
                }
            }
        }
    }

    private func publishSneakPeek() {
        switch mode {
        case .timer:
            switch countdownState.phase {
            case .running, .paused:
                sneakPeekController.showTimer(
                    progress: CGFloat(countdownState.progress),
                    duration: 0
                )
            case .idle:
                sneakPeekController.hideTimer()
            case .finished:
                break
            }
        case .stopwatch:
            switch stopwatchState.phase {
            case .running, .paused:
                // The compact view gets the count-up value from the live model;
                // the coordinator only needs the same timer lifecycle signal.
                sneakPeekController.showTimer(progress: 1, duration: 0)
            case .idle, .finished:
                sneakPeekController.hideTimer()
            }
        }
    }

    private func publishCompletionSneakPeek() {
        sneakPeekController.showTimer(
            progress: CGFloat(countdownState.progress),
            duration: Defaults[.sneakPeekStyles] == .inline ? 2.8 : 2.8
        )
    }

    private func dismissCompletionPresentationIfNeeded() {
        guard mode == .timer, countdownState.phase == .finished else { return }
        completionPresenter.dismissTimerCompletion(widgetID: widgetID)
    }
}
