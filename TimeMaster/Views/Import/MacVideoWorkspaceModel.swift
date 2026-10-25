#if os(macOS)
import AVFoundation
import AppKit
import Combine

@MainActor
final class MacVideoWorkspaceModel: ObservableObject {
    @Published private(set) var items: [MacVideoWorkspaceItem] = []
    @Published var selectedID: UUID?
    @Published private(set) var downloaderVersion: String?
    @Published private(set) var isCheckingDownloader = true
    @Published var message: String?

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var subscriptions: [UUID: AnyCancellable] = [:]
    private var didCheckDownloader = false
    private var isClosed = false

    init(sources: [MacVideoSource] = []) {
        for source in sources { append(source: source) }
    }

    var selectedItem: MacVideoWorkspaceItem? { items.first { $0.id == selectedID } }
    var isBusy: Bool { items.contains { $0.editor?.isBusy == true } }

    func checkDownloader() async {
        guard !didCheckDownloader else { return }
        didCheckDownloader = true
        downloaderVersion = await MacVideoDownloadService.installedVersion()
        isCheckingDownloader = false
    }

    @discardableResult
    func addLinks(in text: String) -> Bool {
        let links = ImportLinkParser.links(in: text)
        guard !links.isEmpty else {
            message = "No http or https links found. Paste a video link, with or without surrounding text."
            return false
        }
        var known = Set(items.map { ImportLinkParser.identity(for: $0.originURL) })
        var added = false
        for url in links where known.insert(ImportLinkParser.identity(for: url)).inserted {
            let item = MacVideoWorkspaceItem(originURL: url)
            items.append(item)
            if selectedID == nil { selectedID = item.id }
            added = true
        }
        if !added { message = "These links are already in this workspace." }
        startNext()
        return added
    }

    func addLocalFiles(_ urls: [URL]) {
        var known = Set(items.filter { $0.originURL.isFileURL }.map { $0.originURL.standardizedFileURL })
        for url in urls where known.insert(url.standardizedFileURL).inserted {
            append(source: MacVideoSource(url: url))
        }
        startNext()
    }

    func select(_ item: MacVideoWorkspaceItem) {
        guard selectedID != item.id else { return }
        selectedItem?.editor?.stopPlayback()
        selectedID = item.id
    }

    func retry(_ item: MacVideoWorkspaceItem) {
        guard item.status.canRetry, tasks[item.id] == nil, !isClosed else { return }
        item.status = .queued
        if item.originURL.isFileURL, item.source == nil { item.source = MacVideoSource(url: item.originURL) }
        startNext()
    }

    func cancel(_ item: MacVideoWorkspaceItem) {
        guard item.status.isActive || item.status == .queued else { return }
        item.status = .cancelled
        tasks[item.id]?.cancel()
    }

    @discardableResult
    func remove(_ item: MacVideoWorkspaceItem) -> Bool {
        guard item.editor?.isBusy != true else {
            message = "Finish the active export or save before removing this source."
            return false
        }
        tasks[item.id]?.cancel()
        item.editor?.stopPlayback()
        item.source?.discardManagedFiles()
        subscriptions.removeValue(forKey: item.id)
        let index = items.firstIndex { $0.id == item.id } ?? 0
        items.removeAll { $0.id == item.id }
        if selectedID == item.id {
            selectedID = items.isEmpty ? nil : items[min(index, items.count - 1)].id
        }
        return true
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        for task in tasks.values { task.cancel() }
        for item in items {
            item.editor?.stopPlayback()
            item.source?.discardManagedFiles()
        }
        subscriptions.removeAll()
        items.removeAll()
    }

    private func append(source: MacVideoSource) {
        let item = MacVideoWorkspaceItem(originURL: source.url, source: source)
        items.append(item)
        if selectedID == nil { selectedID = item.id }
    }

    func start() { startNext() }

    private func startNext() {
        guard !isClosed else { return }
        for item in items where item.status == .queued && tasks[item.id] == nil {
            guard tasks.count < 2 else { break }
            item.status = .validating
            tasks[item.id] = Task { [weak self, weak item] in
                guard let self, let item else { return }
                defer {
                    self.tasks.removeValue(forKey: item.id)
                    self.startNext()
                }
                do {
                    if !item.originURL.isFileURL {
                        let metadata = try await MacVideoDownloadService.validate(from: item.originURL)
                        try Task.checkCancellation()
                        if let title = metadata.title, !title.isEmpty { item.title = title }
                        item.status = .downloading
                        item.source = try await MacVideoDownloadService.download(from: item.originURL)
                    }
                    try Task.checkCancellation()
                    guard let source = item.source else { throw CocoaError(.fileNoSuchFile) }
                    let asset = AVURLAsset(url: source.url)
                    let duration = try await asset.load(.duration).seconds
                    let tracks = try await asset.loadTracks(withMediaType: .video)
                    let playable = try await asset.load(.isPlayable)
                    guard duration.isFinite, duration > 0, !tracks.isEmpty, playable else {
                        throw NSError(domain: "VideoImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "This file contains no playable video. Choose another file or open the original link."])
                    }
                    try Task.checkCancellation()
                    item.duration = duration
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = CGSize(width: 240, height: 150)
                    if let (image, _) = try? await generator.image(at: CMTime(seconds: min(1, duration / 10), preferredTimescale: 600)) {
                        item.thumbnail = NSImage(cgImage: image, size: .zero)
                    }
                    try Task.checkCancellation()
                    guard !self.isClosed, self.items.contains(where: { $0.id == item.id }) else {
                        source.discardManagedFiles()
                        return
                    }
                    let editor = MacVideoEditorModel(source: source)
                    item.editor = editor
                    self.subscriptions[item.id] = editor.objectWillChange.sink { [weak self] _ in
                        self?.objectWillChange.send()
                    }
                    item.status = .ready
                } catch {
                    item.source?.discardManagedFiles()
                    item.source = nil
                    if !self.isClosed, self.items.contains(where: { $0.id == item.id }) {
                        item.status = error is CancellationError || Task.isCancelled ? .cancelled : .failed(error.localizedDescription)
                    }
                }
            }
        }
    }
}
#endif
