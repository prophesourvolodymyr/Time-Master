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
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    private var revealPattern: CHHapticPattern?
    #endif

    func prepareSelection() {
        #if os(iOS)
        selection.prepare()
        #endif
    }


    func prepare() {
        #if os(iOS)
        selection.prepare()
        soft.prepare()
        firm.prepare()
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            if engine == nil {
                let newEngine = try CHHapticEngine()
                newEngine.isAutoShutdownEnabled = true
                newEngine.playsHapticsOnly = true
                newEngine.resetHandler = { [weak self] in
                    Task { @MainActor in
                        self?.player = nil
                        self?.engine = nil
                    }
                }
                engine = newEngine
            }
            try engine?.start()
        } catch {
            engine = nil
        }
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
        guard let engine else {
            soft.impactOccurred(intensity: 0.7)
            return
        }
        do {
            if revealPattern == nil {
                revealPattern = try CHHapticPattern(events: [
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.22),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.18)
                    ], relativeTime: 0, duration: 0.12),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ], relativeTime: 0.10)
                ], parameters: [])
            }
            guard let revealPattern else { return }
            try player?.stop(atTime: CHHapticTimeImmediate)
            player = try engine.makePlayer(with: revealPattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            self.engine = nil
            soft.impactOccurred(intensity: 0.7)
        }
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
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        soft.impactOccurred(intensity: 0.35)
        #endif
    }

    func suspend() {
        #if os(iOS)
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        engine?.stop(completionHandler: nil)
        #endif
    }
}
