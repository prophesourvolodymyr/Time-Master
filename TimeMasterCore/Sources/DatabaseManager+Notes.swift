import Foundation

// Note pages: a title and a Markdown document. Pictures inserted into the document live in the note's own
// `Attachments/` folder and are written into the Markdown as paths relative to the page folder
// (`![](<Attachments/UUID.jpg>)`). The folder is a plain subfolder of the page folder, so a move, a rename of
// the title, the trash, Device Sync and the backup archive all carry it along with the page.
extension DatabaseManager {
    public static let noteAttachmentsFolderName = "Attachments"
    public static let noteImageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp"]
    static let noteImageMaximumBytes: Int64 = 64 * 1024 * 1024

    /// The folder of a note's pictures. The folder itself exists only once the note holds a picture.
    public func noteAttachmentsURL(pageID: String) throws -> URL {
        try resolvePageFolder(id: pageID).appendingPathComponent(Self.noteAttachmentsFolderName, isDirectory: true)
    }

    /// Copies a local picture into the note's `Attachments/` folder under a fresh name and returns its path relative
    /// to the page folder, ready to be written into the Markdown.
    @discardableResult
    public func importNoteImage(pageID: String, sourceURL: URL) throws -> String {
        let page = try getPage(id: pageID)
        guard page.pageType == .note else {
            throw FileSystemHelper.Error.invalidPageKind("only note pages keep pictures in their Markdown")
        }
        let ext = sourceURL.pathExtension.lowercased()
        guard Self.noteImageExtensions.contains(ext) else {
            throw FileSystemHelper.Error.invalidPageKind("notes take jpg, png, heic, gif or webp pictures")
        }
        let size = (try? sourceURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard size > 0, Int64(size) <= Self.noteImageMaximumBytes else {
            throw FileSystemHelper.Error.invalidPageKind("a note picture must be between 1 byte and 64 MB")
        }
        let directory = try noteAttachmentsURL(pageID: pageID)
        try fs.ensureDirectory(directory)
        let name = UUID().uuidString + "." + ext
        try fs.copyItem(from: sourceURL, to: directory.appendingPathComponent(name))
        return Self.noteAttachmentsFolderName + "/" + name
    }

    /// The Markdown line that shows a note picture; `path` is relative to the page folder.
    public static func noteImageMarkdown(path: String, alt: String = "") -> String {
        let cleanAlt = alt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "\n", with: " ")
        return "![\(cleanAlt)](<\(path)>)"
    }

    /// Files in the note's `Attachments/` folder, by name.
    public func noteAttachmentNames(pageID: String) throws -> [String] {
        let directory = try noteAttachmentsURL(pageID: pageID)
        guard fs.directoryExists(at: directory) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { !$0.hasPrefix(".") }.sorted()
    }
}
