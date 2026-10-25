#if os(macOS)
import Foundation

struct MacVideoSource: Identifiable {
    let id: UUID
    let url: URL
    let managedDirectory: URL?
    private let resource: Resource

    init(url: URL, managedDirectory: URL? = nil) {
        id = UUID()
        self.url = url
        self.managedDirectory = managedDirectory
        resource = Resource(url: url, managedDirectory: managedDirectory)
    }

    func discardManagedFiles() {
        resource.requestDiscard()
    }

    private final class Resource: @unchecked Sendable {
        let url: URL
        let managedDirectory: URL?
        let hasSecurityAccess: Bool
        private let lock = NSLock()
        private var discardRequested = false

        init(url: URL, managedDirectory: URL?) {
            self.url = url
            self.managedDirectory = managedDirectory
            hasSecurityAccess = managedDirectory == nil && url.startAccessingSecurityScopedResource()
        }

        func requestDiscard() {
            lock.lock()
            discardRequested = true
            lock.unlock()
        }

        deinit {
            if hasSecurityAccess { url.stopAccessingSecurityScopedResource() }
            if discardRequested, let managedDirectory {
                MacVideoDownloadService.removeManagedDownload(at: managedDirectory)
            }
        }
    }
}
#endif
