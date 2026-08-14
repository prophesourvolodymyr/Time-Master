#if os(macOS)
import Foundation

struct MacVideoSource: Identifiable {
    let id = UUID()
    let url: URL
    let managedDirectory: URL?

    init(url: URL, managedDirectory: URL? = nil) {
        self.url = url
        self.managedDirectory = managedDirectory
    }

    func discardManagedFiles() {
        guard let managedDirectory else { return }
        MacVideoDownloadService.removeManagedDownload(at: managedDirectory)
    }
}
#endif
