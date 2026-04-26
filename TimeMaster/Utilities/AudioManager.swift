import Foundation
import AVFoundation
import AudioToolbox

/// Singleton that owns both system-sound beeps and TTS speech synthesis.
/// Audio session is configured at init time AND re-activated on interruption end
/// so the synthesizer stays alive throughout a workout.
final class AudioManager {
    static let shared = AudioManager()

    // Synthesizer is created FIRST; the session is configured afterwards so iOS 16+
    // properly attaches the synthesizer to the application audio session.
    private let synthesizer = AVSpeechSynthesizer()

    private init() {
        // Configure and activate the shared session AFTER creating the synthesizer.
        // On iOS 16+, AVSpeechSynthesizer uses the application audio session, but
        // the binding only works reliably when the synthesizer exists first.
        configureSession()

        // Re-activate after any audio interruption (phone call, Siri, etc.)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            guard
                let info = notification.userInfo,
                let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                type == .ended
            else { return }
            self.configureSession()
        }
    }

    // MARK: - Session

    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .default, options: [.mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Explicitly (re-)activates the audio session. Call from WorkoutPlayerView.onAppear.
    func activateSession() {
        configureSession()
    }

    // MARK: - Beeps

    /// Countdown tick at 3, 2, 1 seconds.
    func playCountdownBeep() {
        AudioServicesPlaySystemSound(1057)
    }

    func playFinishSound() {
        AudioServicesPlaySystemSound(1016)
    }

    // MARK: - Speech

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Stop any current speech before queuing a new utterance.
        // Do NOT call setActive here — toggling the session mid-synthesis
        // can silently abort the utterance on iOS 17+.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate   = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice  = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
