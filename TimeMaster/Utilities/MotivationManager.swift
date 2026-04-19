import Foundation

/// Manages the motivational quotes pool and fires random TTS during workouts.
final class MotivationManager {

    static let shared = MotivationManager()
    private init() {}

    private let key = "motivation_quotes_v1"
    private let enabledKey = "motivation_quotes_enabled"
    private let intervalKey = "motivation_quotes_interval"

    static let defaultQuotes: [String] = [
        "Keep pushing — you're stronger than you think!",
        "Every rep counts. Don't stop now.",
        "Pain is temporary. Pride is forever.",
        "You didn't come this far to only come this far.",
        "One more. Always one more.",
        "Breathe. Focus. Finish strong.",
        "Champions are made when nobody is watching.",
        "Your only competition is who you were yesterday.",
        "Dig deep — the best is still ahead.",
        "Stay hungry. Stay focused."
    ]

    // MARK: - Persistence

    var quotes: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let list = try? JSONDecoder().decode([String].self, from: data)
            else { return Self.defaultQuotes }
            return list.isEmpty ? Self.defaultQuotes : list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    /// Whether motivational quotes are spoken during workouts.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Minimum seconds between quotes (30–120).
    var interval: Int {
        get { UserDefaults.standard.object(forKey: intervalKey) as? Int ?? 60 }
        set { UserDefaults.standard.set(newValue, forKey: intervalKey) }
    }

    // MARK: - Random quote

    func randomQuote() -> String {
        quotes.randomElement() ?? Self.defaultQuotes[0]
    }
}
