import Foundation
import TimeMasterCore

struct CoachRemoteProfileStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "coach_remote_profile_v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> EverAgentRemoteProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(EverAgentRemoteProfile.self, from: data)
    }

    func save(_ profile: EverAgentRemoteProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
