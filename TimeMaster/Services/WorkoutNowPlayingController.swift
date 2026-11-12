#if os(iOS)
import AVFoundation
import MediaPlayer
import UIKit

enum WorkoutRemoteCommand: Equatable {
    case pause
    case resume
    case toggle
    case next
    case previous
    case skip(seconds: Int)
    case seek(position: Int)
}

enum WorkoutLockScreenSettings {
    static let buttonsKey = "nowplaying_buttons"
    static let skipSecondsKey = "nowplaying_skip_seconds"
    static let scrubKey = "nowplaying_scrub"
    static let skipChoices = [5, 10, 15, 30, 60]

    static var movesByExercise: Bool {
        (UserDefaults.standard.string(forKey: buttonsKey) ?? "exercises") == "exercises"
    }

    static var skipSeconds: Int {
        let value = UserDefaults.standard.object(forKey: skipSecondsKey) as? Int ?? 15
        return min(60, max(5, value))
    }

    static var scrubbingMovesWorkout: Bool {
        UserDefaults.standard.object(forKey: scrubKey) as? Bool ?? true
    }
}

struct WorkoutNowPlayingSnapshot: Equatable {
    var title: String
    var artist: String
    var album: String
    var phaseDuration: Int
    var elapsedInPhase: Int
    var isPaused: Bool
    var artworkURL: URL?
}

@MainActor
final class WorkoutNowPlayingController {
    static let shared = WorkoutNowPlayingController()

    static var isSupported: Bool {
        if #available(iOS 17.0, *) { return false }
        return true
    }

    private var handler: ((WorkoutRemoteCommand) -> Void)?
    private var silence: AVAudioPlayer?
    private var registrations: [(command: MPRemoteCommand, token: Any)] = []
    private var observers: [NSObjectProtocol] = []
    private var isActive = false
    private var artwork: MPMediaItemArtwork?
    private var artworkURL: URL?
    private var artworkTask: Task<Void, Never>?
    private var lastSnapshot: WorkoutNowPlayingSnapshot?

    private init() {}

    func begin(handler: @escaping (WorkoutRemoteCommand) -> Void) {
        guard Self.isSupported else { return }
        self.handler = handler
        guard !isActive else { return }
        isActive = true
        AudioManager.shared.setSessionMode(.exclusive)
        startSilence()
        registerCommands()
        observeSession()
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    func end() {
        guard isActive else { return }
        isActive = false
        handler = nil
        artworkTask?.cancel()
        artwork = nil
        artworkURL = nil
        lastSnapshot = nil
        silence?.stop()
        silence = nil
        for registration in registrations { registration.command.removeTarget(registration.token) }
        registrations = []
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        let center = MPRemoteCommandCenter.shared()
        for command in allCommands(center) { command.isEnabled = false }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        UIApplication.shared.endReceivingRemoteControlEvents()
        AudioManager.shared.setSessionMode(.mixing)
    }

    func update(_ snapshot: WorkoutNowPlayingSnapshot) {
        guard isActive else { return }
        refreshCommands()
        if snapshot.isPaused {
            silence?.pause()
        } else if silence?.isPlaying == false {
            silence?.play()
        }
        if snapshot.artworkURL != artworkURL { loadArtwork(snapshot.artworkURL) }
        lastSnapshot = snapshot
        publish()
    }

    private func publish() {
        guard let snapshot = lastSnapshot else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: snapshot.title,
            MPMediaItemPropertyArtist: snapshot.artist,
            MPMediaItemPropertyAlbumTitle: snapshot.album,
            MPMediaItemPropertyPlaybackDuration: Double(max(1, snapshot.phaseDuration)),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(max(0, min(snapshot.elapsedInPhase, snapshot.phaseDuration))),
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.isPaused ? 0.0 : 1.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(_ url: URL?) {
        artworkTask?.cancel()
        artworkURL = url
        guard let url else {
            artwork = nil
            publish()
            return
        }
        artworkTask = Task { [weak self] in
            let image = await PhotoManager.shared.asyncLoadImage(from: url, maxPixelSize: 600)
            guard !Task.isCancelled, let self, self.artworkURL == url else { return }
            self.artwork = image.map { image in
                MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
            self.publish()
        }
    }

    private func startSilence() {
        guard let player = try? AVAudioPlayer(data: Self.silentWAV()) else { return }
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        player.play()
        silence = player
    }

    private func allCommands(_ center: MPRemoteCommandCenter) -> [MPRemoteCommand] {
        [
            center.playCommand, center.pauseCommand, center.togglePlayPauseCommand, center.nextTrackCommand,
            center.previousTrackCommand, center.skipForwardCommand, center.skipBackwardCommand,
            center.changePlaybackPositionCommand,
        ]
    }

    private func registerCommands() {
        let center = MPRemoteCommandCenter.shared()
        func add(_ command: MPRemoteCommand, _ event: @escaping (MPRemoteCommandEvent) -> WorkoutRemoteCommand?) {
            let token = command.addTarget { [weak self] remote in
                guard let mapped = event(remote) else { return .commandFailed }
                Task { @MainActor in self?.handler?(mapped) }
                return .success
            }
            registrations.append((command, token))
        }
        add(center.playCommand) { _ in .resume }
        add(center.pauseCommand) { _ in .pause }
        add(center.togglePlayPauseCommand) { _ in .toggle }
        add(center.nextTrackCommand) { _ in .next }
        add(center.previousTrackCommand) { _ in .previous }
        add(center.skipForwardCommand) { remote in
            .skip(seconds: Int((remote as? MPSkipIntervalCommandEvent)?.interval ?? Double(WorkoutLockScreenSettings.skipSeconds)))
        }
        add(center.skipBackwardCommand) { remote in
            .skip(seconds: -Int((remote as? MPSkipIntervalCommandEvent)?.interval ?? Double(WorkoutLockScreenSettings.skipSeconds)))
        }
        add(center.changePlaybackPositionCommand) { remote in
            (remote as? MPChangePlaybackPositionCommandEvent).map { .seek(position: Int($0.positionTime.rounded())) }
        }
        refreshCommands()
    }

    private func refreshCommands() {
        let center = MPRemoteCommandCenter.shared()
        let byExercise = WorkoutLockScreenSettings.movesByExercise
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = byExercise
        center.previousTrackCommand.isEnabled = byExercise
        center.skipForwardCommand.isEnabled = !byExercise
        center.skipBackwardCommand.isEnabled = !byExercise
        let interval = NSNumber(value: WorkoutLockScreenSettings.skipSeconds)
        center.skipForwardCommand.preferredIntervals = [interval]
        center.skipBackwardCommand.preferredIntervals = [interval]
        center.changePlaybackPositionCommand.isEnabled = WorkoutLockScreenSettings.scrubbingMovesWorkout
    }

    private func observeSession() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor in self?.handler?(.pause) }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.handler?(.pause) }
        })
    }

    private static func silentWAV(seconds: Int = 1, sampleRate: Int = 8000) -> Data {
        let samples = seconds * sampleRate
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: Array(value.utf8)) }
        func u32(_ value: Int) { withUnsafeBytes(of: UInt32(value).littleEndian) { data.append(contentsOf: $0) } }
        func u16(_ value: Int) { withUnsafeBytes(of: UInt16(value).littleEndian) { data.append(contentsOf: $0) } }
        text("RIFF"); u32(36 + samples * 2); text("WAVE")
        text("fmt "); u32(16); u16(1); u16(1); u32(sampleRate); u32(sampleRate * 2); u16(2); u16(16)
        text("data"); u32(samples * 2)
        data.append(Data(count: samples * 2))
        return data
    }
}
#endif
