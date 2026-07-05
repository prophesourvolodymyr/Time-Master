import AVFoundation
import Combine

/// Manages background workout music playback from Documents/Music/.
final class MusicManager: ObservableObject {

    static let shared = MusicManager()
    private init() {
        createMusicDirIfNeeded()
        loadFilenames()
    }

    // MARK: - Paths

    private let musicDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Music", isDirectory: true)
    }()

    private func createMusicDirIfNeeded() {
        try? FileManager.default.createDirectory(at: musicDir,
                                                  withIntermediateDirectories: true)
    }

    // MARK: - Published State

    @Published var trackFilenames: [String] = []
    @Published var isPlaying: Bool = false
    /// 0.0 – 1.0 volume stored in UserDefaults, applied whenever playback starts.
    @Published var volume: Float = 0.7 {
        didSet {
            UserDefaults.standard.set(volume, forKey: volumeKey)
            player.volume = volume
        }
    }

    // MARK: - Persistence keys

    private let filenamesKey = "music_track_filenames_v1"
    private let volumeKey    = "music_volume_v1"

    // MARK: - AVFoundation

    private var player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var endObserver: Any?

    // MARK: - Init helpers

    private func loadFilenames() {
        let saved = UserDefaults.standard.stringArray(forKey: filenamesKey) ?? []
        // Only keep files that still exist on disk
        trackFilenames = saved.filter {
            FileManager.default.fileExists(atPath: musicDir.appendingPathComponent($0).path)
        }
        volume = UserDefaults.standard.object(forKey: volumeKey) as? Float ?? 0.7
    }

    // MARK: - Import / Delete

    /// Copies a file into Documents/Music/ and registers it.
    func importTrack(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let filename = UUID().uuidString + "_" + url.lastPathComponent
        let dest = musicDir.appendingPathComponent(filename)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            trackFilenames.append(filename)
            UserDefaults.standard.set(trackFilenames, forKey: filenamesKey)
        } catch {}
    }

    func deleteTrack(at offsets: IndexSet) {
        for i in offsets {
            let fn = trackFilenames[i]
            try? FileManager.default.removeItem(at: musicDir.appendingPathComponent(fn))
        }
        trackFilenames.remove(atOffsets: offsets)
        UserDefaults.standard.set(trackFilenames, forKey: filenamesKey)
        if isPlaying { rebuildAndPlay() }
    }

    /// User-visible display name (strips the UUID prefix we added).
    func displayName(for filename: String) -> String {
        guard let idx = filename.firstIndex(of: "_") else { return filename }
        let after = filename.index(after: idx)
        return String(filename[after...])
    }

    // MARK: - Playback control

    func startPlayback() {
        guard !trackFilenames.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        rebuildAndPlay()
        isPlaying = true
    }

    func stopPlayback() {
        player.pause()
        isPlaying = false
    }

    func togglePlayback() {
        if isPlaying { stopPlayback() } else { startPlayback() }
    }

    func startPlayback(tracks: [String]? = nil) {
        guard tracks != nil || !trackFilenames.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        if let tracks = tracks, !tracks.isEmpty {
            rebuildAndPlay(filenames: tracks)
        } else {
            rebuildAndPlay()
        }
        isPlaying = true
    }

    func setPlaylist(_ filenames: [String]) {
        guard !filenames.isEmpty else { return }
        let valid = filenames.filter {
            FileManager.default.fileExists(atPath: musicDir.appendingPathComponent($0).path)
        }
        guard !valid.isEmpty else { return }
        trackFilenames = valid
        if isPlaying { rebuildAndPlay() }
    }

    // MARK: - Queue management

    private func rebuildAndPlay(filenames: [String]? = nil) {
        // Tear down old observer / looper
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        looper = nil
        player.pause()
        player.removeAllItems()

        let source = filenames ?? trackFilenames
        let urls = source.compactMap { fn -> URL? in
            let u = musicDir.appendingPathComponent(fn)
            return FileManager.default.fileExists(atPath: u.path) ? u : nil
        }
        guard !urls.isEmpty else { return }

        if urls.count == 1 {
            // Single track — loop via AVPlayerLooper.
            // IMPORTANT: the template item must NOT be pre-loaded into the player's
            // queue; AVPlayerLooper manages the queue internally.
            let item = AVPlayerItem(url: urls[0])
            player = AVQueuePlayer()          // empty queue — looper fills it
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            // Multiple tracks — re-queue when exhausted
            for url in urls {
                player.insert(AVPlayerItem(url: url), after: nil)
            }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                // One item left means the last one just finished (it's still currentItem)
                if self.player.items().count <= 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.reloadMultiQueue()
                    }
                }
            }
        }

        player.volume = volume
        player.play()
    }

    private func reloadMultiQueue() {
        let urls = trackFilenames.compactMap { fn -> URL? in
            let u = musicDir.appendingPathComponent(fn)
            return FileManager.default.fileExists(atPath: u.path) ? u : nil
        }
        player.removeAllItems()
        for url in urls { player.insert(AVPlayerItem(url: url), after: nil) }
        if isPlaying { player.play() }
    }
}
