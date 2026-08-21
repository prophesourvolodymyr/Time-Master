import Foundation
import AVFoundation
#if os(iOS)
import AudioToolbox
#endif

final class AudioManager {
    static let shared = AudioManager()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {
        #if os(iOS)
        configureSession()
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
        #endif
    }

    #if os(iOS)
    private func configureSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .default, options: [.mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    func activateSession() {
        configureSession()
    }
    #else
    func activateSession() {}
    #endif

    func playCountdownBeep() {
        #if os(iOS)
        AudioServicesPlaySystemSound(1057)
        #endif
    }

    func playFinishSound() {
        #if os(iOS)
        AudioServicesPlaySystemSound(1016)
        #endif
    }

    func speak(_ text: String, volume: Float = 1) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate   = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice  = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = min(max(volume, 0), 1)
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
