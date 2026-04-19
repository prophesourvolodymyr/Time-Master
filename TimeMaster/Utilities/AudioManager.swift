import Foundation
import AVFoundation
import Speech

class AudioManager {
    static let shared = AudioManager()
    private var speechSynthesizer: AVSpeechSynthesizer?

    private init() {
        speechSynthesizer = AVSpeechSynthesizer()
    }

    func playCountdownBeep() {
        AudioServicesPlaySystemSound(1103)
    }

    func playFinishSound() {
        AudioServicesPlaySystemSound(1025)
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer?.speak(utterance)
    }

    func stopSpeaking() {
        speechSynthesizer?.stopSpeaking(at: .immediate)
    }
}