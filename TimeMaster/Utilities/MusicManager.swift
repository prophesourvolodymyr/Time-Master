import AVFoundation
import Combine
import SwiftMP3

enum MusicPlaybackUnavailableReason: Equatable {
    case noPlayableSource
    case missingLocalFile
    case providerUnavailable(MusicProvider)
    case unsupportedSource
}

enum MusicPlaybackAvailability: Equatable {
    case idle
    case playable
    case unavailable(MusicPlaybackUnavailableReason)
}

enum MusicPlaybackResult: Equatable {
    case started
    case unavailable(MusicPlaybackUnavailableReason)
}

/// Manages background workout music playback from Documents/Music/.
final class MusicManager: ObservableObject {

    enum ImportError: LocalizedError {
        case noAudioTrack
        case readerFailed

        var errorDescription: String? {
            switch self {
            case .noAudioTrack: return "The selected video has no audio track."
            case .readerFailed: return "The video audio could not be read."
            }
        }
    }

    static let shared = MusicManager()
    private init() {
        createMusicDirIfNeeded()
        loadFilenames()
        installTimeObserver()
    }

    // MARK: - Paths

    private let musicDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Music", isDirectory: true)
    }()
    var localMusicDirectoryURL: URL { musicDir }

    private func createMusicDirIfNeeded() {
        try? FileManager.default.createDirectory(at: musicDir,
                                                  withIntermediateDirectories: true)
    }

    // MARK: - Published State

    @Published var trackFilenames: [String] = []
    @Published var isPlaying: Bool = false
    @Published private(set) var activePlaylist: [String] = []
    @Published private(set) var currentFilename: String?
    @Published private(set) var currentTrack: MusicPlaybackTrack?
    @Published private(set) var playbackAvailability: MusicPlaybackAvailability = .idle
    @Published private(set) var playbackProgress: Double = 0
    @Published var repeatOne = false
    @Published var volume: Float = 0.7 {
        didSet {
            UserDefaults.standard.set(volume, forKey: volumeKey)
            player.volume = volume
        }
    }
    var currentTrackID: String? { currentTrack?.id }

    // MARK: - Persistence keys

    private let filenamesKey = "music_track_filenames_v1"
    private let volumeKey    = "music_volume_v1"

    // MARK: - AVFoundation

    private var player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var endObserver: Any?
    private var timeObserver: Any?
    private var trackDescriptorsByFilename: [String: MusicPlaybackTrack] = [:]

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

    func importTrackAsync(from url: URL) async throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let filename = UUID().uuidString + "_" + url.deletingPathExtension().lastPathComponent + ".mp3"
        let destination = musicDir.appendingPathComponent(filename)
        try await Task.detached(priority: .userInitiated) {
            try Self.convertVideoToMP3(sourceURL: url, destinationURL: destination)
        }.value

        await MainActor.run {
            trackFilenames.append(filename)
            UserDefaults.standard.set(trackFilenames, forKey: filenamesKey)
        }
    }

    private static func convertVideoToMP3(sourceURL: URL, destinationURL: URL) throws {
        let asset = AVAsset(url: sourceURL)
        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw ImportError.noAudioTrack
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ImportError.readerFailed }
        reader.add(output)
        guard reader.startReading() else { throw ImportError.readerFailed }

        var encoder = MP3Encoder(options: MP3EncoderOptions(
            sampleRate: 44_100,
            bitrateKbps: 192,
            mode: .stereo
        ))
        var audioData = Data()

        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
            var lengthAtOffset = 0
            var totalLength = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: &lengthAtOffset,
                totalLengthOut: &totalLength,
                dataPointerOut: &dataPointer
            )
            guard let dataPointer, totalLength > 0 else { continue }
            let sampleCount = totalLength / MemoryLayout<Float>.size
            let samples = UnsafeBufferPointer(
                start: UnsafeRawPointer(dataPointer).assumingMemoryBound(to: Float.self),
                count: sampleCount
            )
            audioData.append(encoder.appendSamples(Array(samples)))
        }

        guard reader.status == .completed else { throw ImportError.readerFailed }
        audioData.append(encoder.flush())

        var mp3Data = Data()
        mp3Data.append(encoder.makeXingHeader())
        mp3Data.append(audioData)
        try mp3Data.write(to: destinationURL, options: .atomic)
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
        startPlayback(tracks: trackFilenames)
    }

    func stopPlayback() {
        player.pause()
        player.removeAllItems()
        looper = nil
        removeEndObserver()
        removeTimeObserver()
        isPlaying = false
        activePlaylist = []
        currentFilename = nil
        currentTrack = nil
        trackDescriptorsByFilename = [:]
        playbackAvailability = .idle
        playbackProgress = 0
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else if player.currentItem != nil {
            player.play()
            isPlaying = true
        } else {
            startPlayback()
        }
    }

    func startPlayback(tracks: [String]? = nil, startingAt startIndex: Int = 0) {
        let requested = tracks?.isEmpty == false ? tracks! : trackFilenames
        guard !requested.isEmpty else {
            playbackAvailability = .unavailable(.noPlayableSource)
            return
        }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let descriptors = requested.map {
            MusicPlaybackTrack(id: $0, title: displayName(for: $0), localFilename: $0)
        }
        rebuildAndPlay(filenames: requested, startIndex: startIndex, descriptors: descriptors)
    }

    @discardableResult
    func play(_ item: MusicLibraryItem, startingAt startIndex: Int = 0) -> MusicPlaybackResult {
        var filenames: [String] = []
        var descriptors: [MusicPlaybackTrack] = []
        if item.isCollection {
            for track in item.tracks {
                guard let local = track.localReference?.filename else { continue }
                filenames.append(local)
                descriptors.append(MusicPlaybackTrack(id: track.id.uuidString.lowercased(), title: track.name, artworkReference: artworkString(track.artwork ?? item.artwork), localFilename: local))
            }
        } else if let local = item.localReference?.filename {
            filenames = [local]
            descriptors = [MusicPlaybackTrack(id: item.id.uuidString.lowercased(), title: item.name, artist: item.metadata["artist"], artworkReference: artworkString(item.artwork), localFilename: local)]
        }
        guard !filenames.isEmpty else {
            let reason: MusicPlaybackUnavailableReason
            if case .provider(let reference) = item.source {
                reason = .providerUnavailable(reference.provider)
            } else if item.source == .none {
                reason = .noPlayableSource
            } else {
                reason = .unsupportedSource
            }
            playbackAvailability = .unavailable(reason)
            return .unavailable(reason)
        }
        let playable = filenames.filter { FileManager.default.fileExists(atPath: musicDir.appendingPathComponent($0).path) }
        guard !playable.isEmpty else {
            playbackAvailability = .unavailable(.missingLocalFile)
            return .unavailable(.missingLocalFile)
        }
        let paired = zip(filenames, descriptors).filter { playable.contains($0.0) }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        rebuildAndPlay(filenames: paired.map { $0.0 }, startIndex: startIndex, descriptors: paired.map { $0.1 })
        return .started
    }

    @discardableResult
    func play(item: MusicLibraryItem, startingAt startIndex: Int = 0) -> MusicPlaybackResult {
        play(item, startingAt: startIndex)
    }
    @discardableResult
    func play(collection: MusicLibraryItem, startingAt startIndex: Int = 0) -> MusicPlaybackResult {
        play(collection, startingAt: startIndex)
    }

    @discardableResult
    func startPlayback(item: MusicLibraryItem, startingAt startIndex: Int = 0) -> MusicPlaybackResult {
        play(item, startingAt: startIndex)
    }


    func availability(for item: MusicLibraryItem) -> MusicPlaybackAvailability {
        if item.isCollection {
            if item.tracks.contains(where: { $0.localReference != nil }) {
                let anyExisting = item.tracks.contains { track in
                    guard let filename = track.localReference?.filename else { return false }
                    return FileManager.default.fileExists(atPath: musicDir.appendingPathComponent(filename).path)
                }
                return anyExisting ? .playable : .unavailable(.missingLocalFile)
            }
        } else if let filename = item.localReference?.filename {
            return FileManager.default.fileExists(atPath: musicDir.appendingPathComponent(filename).path) ? .playable : .unavailable(.missingLocalFile)
        }
        if case .provider(let reference) = item.source { return .unavailable(.providerUnavailable(reference.provider)) }
        return .unavailable(.noPlayableSource)
    }
    func isPlayable(_ item: MusicLibraryItem) -> Bool {
        availability(for: item) == .playable
    }

    func jumpToTrack(index: Int) {
        guard activePlaylist.indices.contains(index) else { return }
        rebuildAndPlay(filenames: activePlaylist, startIndex: index)
    }

    func skipForward() {
        guard !activePlaylist.isEmpty else { return }
        jumpToTrack(index: (currentPlaylistIndex + 1) % activePlaylist.count)
    }

    func skipBackward() {
        if playbackProgress > 0.04 {
            seek(to: 0)
            return
        }
        guard !activePlaylist.isEmpty else { return }
        jumpToTrack(index: (currentPlaylistIndex - 1 + activePlaylist.count) % activePlaylist.count)
    }

    func seek(to progress: Double) {
        guard let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 else { return }
        let clamped = min(max(progress, 0), 1)
        player.seek(to: CMTime(seconds: duration * clamped, preferredTimescale: 600))
        playbackProgress = clamped
    }

    func toggleRepeatOne() {
        repeatOne.toggle()
        guard isPlaying, !activePlaylist.isEmpty else { return }
        rebuildAndPlay(filenames: activePlaylist, startIndex: currentPlaylistIndex)
    }

    func setPlaylist(_ filenames: [String]) {
        guard !filenames.isEmpty else { return }
        let valid = filenames.filter {
            FileManager.default.fileExists(atPath: musicDir.appendingPathComponent($0).path)
        }
        guard !valid.isEmpty else { return }
        trackFilenames = valid
        if isPlaying { rebuildAndPlay(filenames: valid) }
    }


    // MARK: - Queue management

    private func rebuildAndPlay(filenames: [String]? = nil) {
        rebuildAndPlay(filenames: filenames, startIndex: 0, descriptors: nil)
    }

    private func rebuildAndPlay(filenames: [String]? = nil, startIndex: Int, descriptors: [MusicPlaybackTrack]? = nil) {
        removeEndObserver()
        removeTimeObserver()
        looper = nil
        player.pause()
        player.removeAllItems()

        let source = filenames ?? (activePlaylist.isEmpty ? trackFilenames : activePlaylist)
        if let descriptors {
            trackDescriptorsByFilename = Dictionary(zip(source, descriptors), uniquingKeysWith: { first, _ in first })
        } else {
            for filename in source where trackDescriptorsByFilename[filename] == nil {
                trackDescriptorsByFilename[filename] = MusicPlaybackTrack(id: filename, title: displayName(for: filename), localFilename: filename)
            }
        }
        let playable = source.filter {
            FileManager.default.fileExists(atPath: musicDir.appendingPathComponent($0).path)
        }
        guard !playable.isEmpty else {
            isPlaying = false
            currentFilename = nil
            currentTrack = nil
            playbackAvailability = .unavailable(.missingLocalFile)
            playbackProgress = 0
            return
        }
        activePlaylist = playable
        let boundedStartIndex = min(max(startIndex, 0), playable.count - 1)
        let orderedFilenames = Array(playable.dropFirst(boundedStartIndex)) + Array(playable.prefix(boundedStartIndex))

        if repeatOne {
            player = AVQueuePlayer()
            looper = AVPlayerLooper(
                player: player,
                templateItem: AVPlayerItem(url: musicDir.appendingPathComponent(orderedFilenames[0]))
            )
        } else {
            for filename in orderedFilenames {
                player.insert(AVPlayerItem(url: musicDir.appendingPathComponent(filename)), after: nil)
            }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                if self.player.items().count <= 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        guard self.isPlaying else { return }
                        self.rebuildAndPlay(filenames: self.activePlaylist)
                    }
                }
            }
        }

        player.volume = volume
        currentFilename = orderedFilenames[0]
        updateCurrentTrack(for: orderedFilenames[0])
        playbackAvailability = .playable
        playbackProgress = 0
        installTimeObserver()
        player.play()
        isPlaying = true
    }

    private var currentPlaylistIndex: Int {
        guard let currentFilename, let index = activePlaylist.firstIndex(of: currentFilename) else { return 0 }
        return index
    }

    private func installTimeObserver() {
        removeTimeObserver()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.refreshPlaybackState(at: time)
        }
    }

    private func removeTimeObserver() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    private func refreshPlaybackState(at time: CMTime) {
        if let asset = player.currentItem?.asset as? AVURLAsset {
            let filename = asset.url.lastPathComponent
            if currentFilename != filename {
                currentFilename = filename
                updateCurrentTrack(for: filename)
            }
        }
        guard let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 else {
            playbackProgress = 0
            return
        }
        playbackProgress = min(max(time.seconds / duration, 0), 1)
    }

    private func updateCurrentTrack(for filename: String) {
        currentTrack = trackDescriptorsByFilename[filename] ?? MusicPlaybackTrack(id: filename, title: displayName(for: filename), localFilename: filename)
    }

    private func artworkString(_ artwork: MusicArtworkReference?) -> String? {
        if let localFilename = artwork?.localFilename { return localFilename }
        if let remoteURL = artwork?.remoteURL { return remoteURL.absoluteString }
        return artwork?.placeholderSystemImage
    }

    private func removeEndObserver() {
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
    }
}
