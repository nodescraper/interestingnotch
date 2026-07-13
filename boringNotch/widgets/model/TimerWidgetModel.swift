//
//  TimerWidgetModel.swift
//  boringNotch
//
//  Created by Codex on 2026-07-13.
//

import Defaults
import Foundation
import SwiftUI

private let defaultTimerPreset = TimerPreset(minutes: 25)
private let timerPresets: [TimerPreset] = [
    .init(minutes: 5),
    .init(minutes: 10),
    .init(minutes: 15),
    .init(minutes: 25),
    .init(minutes: 50),
]

enum TimerWidgetPhase: String, Equatable, Sendable {
    case idle
    case running
    case paused
    case finished
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

@MainActor
protocol TimerSneakPeekControlling {
    func showTimer(progress: CGFloat, duration: TimeInterval)
    func hideTimer()
}

@MainActor
struct SystemTimerSneakPeekController: TimerSneakPeekControlling {
    func showTimer(progress: CGFloat, duration: TimeInterval) {
        BoringViewCoordinator.shared.toggleSneakPeek(
            status: true,
            type: .timer,
            duration: duration,
            value: progress
        )
    }

    func hideTimer() {
        BoringViewCoordinator.shared.toggleSneakPeek(
            status: false,
            type: .timer
        )
    }
}

@MainActor
final class TimerWidgetModel: ObservableObject, InteractiveWidgetRuntime {
    static let defaultPreset = defaultTimerPreset
    static let presets: [TimerPreset] = timerPresets

    let interactiveKind: WidgetManifest.Interactive.Kind = .timer
    let widgetID: String

    @Published private(set) var countdownState: TimerCountdownState

    private let now: @Sendable () -> Date
    private let sneakPeekController: any TimerSneakPeekControlling
    private var tickerTask: Task<Void, Never>?

    init(
        widgetID: String,
        initialPreset: TimerPreset = defaultTimerPreset,
        countdownState: TimerCountdownState? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        sneakPeekController: (any TimerSneakPeekControlling)? = nil
    ) {
        self.widgetID = widgetID
        self.now = now
        self.sneakPeekController = sneakPeekController ?? SystemTimerSneakPeekController()
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

    var displayTime: String {
        let totalSeconds = max(0, Int(countdownState.remaining.rounded(.up)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var phaseTitle: String {
        switch countdownState.phase {
        case .idle:
            return "Ready"
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        case .finished:
            return "Time's up"
        }
    }

    var accessibilitySummary: String {
        "\(phaseTitle), \(displayTime) remaining"
    }

    func selectPreset(_ preset: TimerPreset) {
        countdownState.selectPreset(preset)
        syncTicker()
        publishSneakPeek()
    }

    func toggleStartPause() {
        switch countdownState.phase {
        case .idle, .paused, .finished:
            countdownState.start(now: now())
        case .running:
            countdownState.pause(now: now())
        }

        syncTicker()
        publishSneakPeek()
    }

    func reset() {
        countdownState.reset()
        syncTicker()
        publishSneakPeek()
    }

    func refresh() {
        let previousPhase = countdownState.phase
        countdownState.tick(now: now())

        if previousPhase != .finished && countdownState.phase == .finished {
            tickerTask?.cancel()
            tickerTask = nil
            publishCompletionSneakPeek()
        } else {
            publishSneakPeek()
        }
    }

    private func syncTicker() {
        tickerTask?.cancel()
        tickerTask = nil

        guard countdownState.phase == .running else { return }

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
    }

    private func publishCompletionSneakPeek() {
        sneakPeekController.showTimer(
            progress: CGFloat(countdownState.progress),
            duration: Defaults[.sneakPeekStyles] == .inline ? 2.8 : 2.8
        )
    }
}
