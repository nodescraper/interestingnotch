import Combine
import Foundation
import IOKit.pwr_mgt

@MainActor
final class CaffeineManager: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable, Hashable {
        case displayAwake
        case systemAwake

        var id: String { rawValue }

        var assertionType: CFString {
            switch self {
            case .displayAwake:
                return kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
            case .systemAwake:
                return kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
            }
        }
    }

    static let shared = CaffeineManager()

    @Published private(set) var isActive = false
    @Published var remaining: TimeInterval?
    @Published private(set) var compactPeekVisible = false
    @Published private(set) var compactPeekMessage: String?
    private(set) var mode: Mode = .displayAwake

    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false
    private var timerTask: Task<Void, Never>?
    private var compactPeekTask: Task<Void, Never>?
    private var endDate: Date?

    private init() {
        UserDefaults.standard.register(defaults: [
            "caffeineDefaultDuration": 3600.0,
            "caffeineDefaultMode": Mode.displayAwake.rawValue,
        ])
    }

    private var defaultDuration: TimeInterval? {
        let duration = UserDefaults.standard.double(forKey: "caffeineDefaultDuration")
        return duration > 0 ? duration : nil
    }

    private var defaultMode: Mode {
        let rawValue = UserDefaults.standard.string(forKey: "caffeineDefaultMode")
        return Mode(rawValue: rawValue ?? "") ?? .displayAwake
    }

    func activate(mode: Mode = .displayAwake) {
        activate(mode: mode, showConfirmation: true)
    }

    private func activate(mode: Mode, showConfirmation: Bool) {
        if hasAssertion {
            deactivate(showEndedPeek: false)
        }

        var newAssertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            mode.assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "InterestingNotch Caffeine" as CFString,
            &newAssertionID
        )
        guard result == kIOReturnSuccess else { return }

        assertionID = newAssertionID
        hasAssertion = true
        self.mode = mode
        isActive = true
        remaining = nil
        endDate = nil
        timerTask?.cancel()
        timerTask = nil
        showCompactPeek()
    }

    func activate(for seconds: TimeInterval, mode: Mode = .displayAwake) {
        guard seconds > 0 else {
            activate(mode: mode)
            return
        }

        activate(mode: mode, showConfirmation: false)
        let endDate = Date().addingTimeInterval(seconds)
        self.endDate = endDate
        remaining = seconds
        showPeek(message: Self.durationLabel(seconds))

        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                let left = endDate.timeIntervalSinceNow
                if left <= 0 { break }
                self?.remaining = left
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled, let self, self.isActive else { return }
            self.deactivate(showEndedPeek: true)
        }
    }

    func deactivate() {
        deactivate(showEndedPeek: false)
    }

    func toggle() {
        if isActive {
            deactivate()
        } else if let defaultDuration {
            activate(for: defaultDuration, mode: defaultMode)
        } else {
            activate(mode: defaultMode)
        }
    }

    deinit {
        timerTask?.cancel()
        compactPeekTask?.cancel()
        if hasAssertion {
            IOPMAssertionRelease(assertionID)
        }
    }

    private func deactivate(showEndedPeek: Bool) {
        guard hasAssertion || isActive else { return }
        if hasAssertion {
            IOPMAssertionRelease(assertionID)
        }
        assertionID = 0
        hasAssertion = false
        isActive = false
        remaining = nil
        endDate = nil
        timerTask?.cancel()
        timerTask = nil
        if showEndedPeek {
            showCompactPeek(message: "Caffeine ended", duration: 2)
        } else {
            compactPeekTask?.cancel()
            compactPeekTask = nil
            compactPeekVisible = false
            compactPeekMessage = nil
        }
    }

    private func showCompactPeek(message: String? = nil, duration: TimeInterval = 5) {
        compactPeekTask?.cancel()
        compactPeekMessage = message
        compactPeekVisible = true
        compactPeekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.compactPeekVisible = false
            self?.compactPeekMessage = nil
        }
    }

    private static func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 { return "\(minutes / 60)h" }
        return "\(minutes)m"
    }
}
