import Foundation
#if os(iOS)
import UIKit
#endif

enum WorkoutHapticEvent {
    case warmUpStart
    case prepareStart
    case exerciseStart
    case restStart
    case sectionStart
    case countdownTick
    case pause
    case resume
    case adjust
    case complete
}

@MainActor
final class WorkoutHaptics {
    static let shared = WorkoutHaptics()
    static let enabledKey = "workout_haptics_enabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    #if os(iOS)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    #endif

    private init() {}

    func prepare() {
        #if os(iOS)
        guard isEnabled else { return }
        heavy.prepare()
        medium.prepare()
        light.prepare()
        #endif
    }

    func play(_ event: WorkoutHapticEvent) {
        #if os(iOS)
        guard isEnabled else { return }
        switch event {
        case .warmUpStart, .prepareStart:
            soft.impactOccurred(intensity: 0.8)
        case .exerciseStart:
            heavy.impactOccurred()
            after(0.12) { [medium] in medium.impactOccurred(intensity: 0.7) }
        case .restStart:
            medium.impactOccurred(intensity: 0.6)
        case .sectionStart:
            notification.notificationOccurred(.warning)
        case .countdownTick:
            light.impactOccurred(intensity: 0.7)
        case .pause:
            selection.selectionChanged()
        case .resume:
            medium.impactOccurred(intensity: 0.5)
        case .adjust:
            selection.selectionChanged()
        case .complete:
            notification.notificationOccurred(.success)
            after(0.35) { [heavy] in heavy.impactOccurred() }
        }
        #endif
    }

    #if os(iOS)
    private func after(_ seconds: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
    #endif
}
