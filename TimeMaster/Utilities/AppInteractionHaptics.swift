import Foundation
#if os(iOS)
import UIKit
import CoreHaptics
#endif

@MainActor
final class AppInteractionHaptics {
    static let shared = AppInteractionHaptics()

    #if os(iOS)
    private let selection = UISelectionFeedbackGenerator()
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let firm = UIImpactFeedbackGenerator(style: .rigid)
    private let press = UIImpactFeedbackGenerator(style: .medium)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let reveal = RevealHapticPlayer()
    private var lastPress: TimeInterval = 0
    private var lastPressPrepare: TimeInterval = 0
    #endif

    func preparePress() {
        #if os(iOS)
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPressPrepare > 1 else { return }
        lastPressPrepare = now
        press.prepare()
        #endif
    }

    func pressed() {
        #if os(iOS)
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPress > 0.15 else { return }
        lastPress = now
        lastPressPrepare = now
        press.impactOccurred()
        press.prepare()
        #endif
    }

    func menuOpened() {
        #if os(iOS)
        press.impactOccurred()
        press.prepare()
        selection.prepare()
        #endif
    }

    func prepareSelection() {
        #if os(iOS)
        selection.prepare()
        light.prepare()
        #endif
    }

    func settled() {
        #if os(iOS)
        light.impactOccurred()
        light.prepare()
        #endif
    }

    func prepare() {
        #if os(iOS)
        selection.prepare()
        soft.prepare()
        firm.prepare()
        reveal.warm()
        #endif
    }

    func beganReveal() {
        prepare()
        #if os(iOS)
        soft.impactOccurred(intensity: 0.35)
        #endif
    }

    func crossedThreshold() {
        #if os(iOS)
        firm.impactOccurred(intensity: 0.45)
        firm.prepare()
        #endif
    }

    func opened() {
        #if os(iOS)
        reveal.play { [soft] in soft.impactOccurred(intensity: 0.7) }
        #endif
    }

    func selectionChanged() {
        #if os(iOS)
        selection.selectionChanged()
        selection.prepare()
        #endif
    }

    func dismissed() {
        #if os(iOS)
        reveal.stopPlayback()
        soft.impactOccurred(intensity: 0.35)
        #endif
    }

    func suspend() {
        #if os(iOS)
        reveal.suspend()
        #endif
    }
}

#if os(iOS)
private final class RevealHapticPlayer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.timemaster.reveal-haptics", qos: .userInitiated)
    private var supported: Bool?
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    private var pattern: CHHapticPattern?

    func warm() {
        queue.async { _ = self.runningEngine() }
    }

    func play(fallback: @escaping @MainActor () -> Void) {
        queue.async {
            guard let engine = self.runningEngine(), let pattern = self.revealPattern() else {
                Task { @MainActor in fallback() }
                return
            }
            do {
                try self.player?.stop(atTime: CHHapticTimeImmediate)
                let next = try engine.makePlayer(with: pattern)
                self.player = next
                try next.start(atTime: CHHapticTimeImmediate)
            } catch {
                self.player = nil
                self.engine = nil
                Task { @MainActor in fallback() }
            }
        }
    }

    func stopPlayback() {
        queue.async {
            try? self.player?.stop(atTime: CHHapticTimeImmediate)
            self.player = nil
        }
    }

    func suspend() {
        queue.async {
            try? self.player?.stop(atTime: CHHapticTimeImmediate)
            self.player = nil
            self.engine?.stop(completionHandler: nil)
        }
    }

    private func runningEngine() -> CHHapticEngine? {
        if supported == nil {
            supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        }
        guard supported == true else { return nil }
        do {
            let current: CHHapticEngine
            if let engine {
                current = engine
            } else {
                current = try CHHapticEngine()
                current.isAutoShutdownEnabled = true
                current.playsHapticsOnly = true
                current.resetHandler = { [weak self] in
                    self?.queue.async {
                        self?.player = nil
                        self?.engine = nil
                    }
                }
                engine = current
            }
            try current.start()
            return current
        } catch {
            engine = nil
            return nil
        }
    }

    private func revealPattern() -> CHHapticPattern? {
        if let pattern { return pattern }
        pattern = try? CHHapticPattern(events: [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.22),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.18)
            ], relativeTime: 0, duration: 0.12),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0.10)
        ], parameters: [])
        return pattern
    }
}
#endif
