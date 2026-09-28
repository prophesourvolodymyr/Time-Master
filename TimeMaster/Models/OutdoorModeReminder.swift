#if os(iOS)
import Foundation
import UIKit

@MainActor
final class OutdoorModeReminder: NSObject {
    enum Prompt: String, Identifiable {
        case choose
        case confirm

        var id: String { rawValue }
    }

    private enum Phase: String {
        case needsChoice
        case needsConfirmation
        case confirmed
    }

    static let shared = OutdoorModeReminder()
    private static let phaseKey = "outdoor.modeReminder.phase"
    private static let awayKey = "outdoor.modeReminder.awayAt"
    private static let activeKey = "outdoor.modeReminder.activeAt"
    private let defaults: UserDefaults
    private var phase: Phase

    init(defaults: UserDefaults = .standard, at date: Date = Date(), observesLifecycle: Bool = true) {
        self.defaults = defaults
        self.phase = defaults.string(forKey: Self.phaseKey).flatMap(Phase.init(rawValue:)) ?? .needsChoice
        super.init()
        let lastSeen = defaults.object(forKey: Self.awayKey) as? Date
            ?? defaults.object(forKey: Self.activeKey) as? Date
        if let lastSeen, date.timeIntervalSince(lastSeen) >= 3_600 {
            phase = .needsChoice
        }
        becameActive(at: date)
        if observesLifecycle {
            NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func requestPrompt(at date: Date = Date()) -> Prompt? {
        becameActive(at: date)
        switch phase {
        case .needsChoice:
            phase = .needsConfirmation
            persist()
            return .choose
        case .needsConfirmation:
            return .confirm
        case .confirmed:
            return nil
        }
    }

    func confirm(at date: Date = Date()) {
        phase = .confirmed
        defaults.set(date, forKey: Self.activeKey)
        persist()
    }

    func wentAway(at date: Date = Date()) {
        defaults.set(date, forKey: Self.awayKey)
    }

    func becameActive(at date: Date = Date()) {
        if let away = defaults.object(forKey: Self.awayKey) as? Date,
           date.timeIntervalSince(away) >= 3_600 {
            phase = .needsChoice
        }
        defaults.removeObject(forKey: Self.awayKey)
        defaults.set(date, forKey: Self.activeKey)
        persist()
    }

    private func persist() {
        defaults.set(phase.rawValue, forKey: Self.phaseKey)
    }

    @objc private func willResignActive() {
        wentAway()
    }

    @objc private func didBecomeActive() {
        becameActive()
    }
}
#endif
