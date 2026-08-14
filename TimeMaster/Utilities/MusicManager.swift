import AVFoundation
import Combine
import SwiftMP3

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
    @Published private(set) var activePlaylist: [String] = []
    @Published var repeatOne = false
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
        guard !trackFilenames.isEmpty else { return }
        #if os(iOS)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        #endif
        rebuildAndPlay()
        isPlaying = true
    }

    func stopPlayback() {
        player.pause()
        player.removeAllItems()
        looper = nil
        removeEndObserver()
        isPlaying = false
        activePlaylist = []
    }

    func togglePlayback() {
        if isPlaying { stopPlayback() } else { startPlayback() }
    }

    func startPlayback(tracks: [String]? = nil) {
        let requested = tracks?.isEmpty == false ? tracks! : trackFilenames
        guard !requested.isEmpty else { return }
        #if os(iOS)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        #endif
        rebuildAndPlay(filenames: requested)
        isPlaying = true
    }

    func jumpToTrack(index: Int) {
        guard activePlaylist.indices.contains(index) else { return }
        rebuildAndPlay(filenames: activePlaylist, startIndex: index)
        isPlaying = true
    }

    func toggleRepeatOne() {
        repeatOne.toggle()
        guard isPlaying, !activePlaylist.isEmpty else { return }
        rebuildAndPlay(filenames: activePlaylist)
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
        rebuildAndPlay(filenames: filenames, startIndex: 0)
    }

    private func rebuildAndPlay(filenames: [String]? = nil, startIndex: Int) {
        removeEndObserver()
        looper = nil
        player.pause()
        player.removeAllItems()

        let source = filenames ?? (activePlaylist.isEmpty ? trackFilenames : activePlaylist)
        let urls = source.compactMap { fn -> URL? in
            let u = musicDir.appendingPathComponent(fn)
            return FileManager.default.fileExists(atPath: u.path) ? u : nil
        }
        guard !urls.isEmpty else { return }
        activePlaylist = source
        let orderedURLs = startIndex > 0
            ? Array(urls.dropFirst(startIndex)) + Array(urls.prefix(startIndex))
            : urls

        if repeatOne {
            // Single track — loop via AVPlayerLooper.
            // IMPORTANT: the template item must NOT be pre-loaded into the player's
            // queue; AVPlayerLooper manages the queue internally.
            let item = AVPlayerItem(url: orderedURLs[0])
            player = AVQueuePlayer()          // empty queue — looper fills it
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            // Queue all selected tracks, then rebuild from track zero when exhausted.
            for url in orderedURLs {
                player.insert(AVPlayerItem(url: url), after: nil)
            }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                // One item left means the final selected track just finished.
                if self.player.items().count <= 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        guard self.isPlaying else { return }
                        self.rebuildAndPlay(filenames: self.activePlaylist)
                    }
                }
            }
        }

        player.volume = volume
        player.play()
    }

    private func removeEndObserver() {
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
    }
}
