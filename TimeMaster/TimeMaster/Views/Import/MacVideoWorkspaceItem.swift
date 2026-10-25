#if os(macOS)
import AppKit
import Combine

@MainActor
final class MacVideoWorkspaceItem: ObservableObject, Identifiable {
    let id = UUID()
    let originURL: URL
    @Published var source: MacVideoSource?
    @Published var title: String
    @Published var duration: Double?
    @Published var thumbnail: NSImage?
    @Published var status: ImportLinkStatus = .queued
    @Published var editor: MacVideoEditorModel?

    init(originURL: URL, source: MacVideoSource? = nil) {
        self.originURL = originURL
        self.source = source
        if originURL.isFileURL {
            title = originURL.deletingPathExtension().lastPathComponent
        } else {
            let host = originURL.host?.replacingOccurrences(of: "www.", with: "") ?? originURL.absoluteString
            title = host
        }
    }

    var host: String {
        originURL.isFileURL ? "This Mac" : (originURL.host?.replacingOccurrences(of: "www.", with: "") ?? "")
    }

    var symbolName: String {
        if originURL.isFileURL { return "film" }
        let host = (originURL.host ?? "").lowercased()
        if host.contains("youtube") || host.contains("youtu.be") { return "play.rectangle.fill" }
        if host.contains("instagram") { return "camera.fill" }
        if host.contains("tiktok") { return "music.note" }
        return "link"
    }
}
#endif
