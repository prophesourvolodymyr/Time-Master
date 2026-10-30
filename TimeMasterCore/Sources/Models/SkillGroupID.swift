import Foundation

/// The id a skill board group goes by wherever a page id is expected: `<board page id>~<section id>`.
///
/// `DatabaseManager` resolves it to the group's content (`resolvePageFolder`, `getPage`, the manifest writes), so
/// media uploads, media comments, notes, links and prerequisites work on groups as they do on pages, and
/// `createPage(parentID:)` with a group id creates a page inside the group. Page ids are UUIDs and never contain `~`.
///
/// The group's media live in `<board page folder>/Sections/<section id>/media/`. The folder is visible on purpose:
/// the library sync scan and the backup both skip hidden entries, and a visible folder without a `manifest.json` is
/// carried by both while every page walker ignores it (like a page's `Attachments/` folder of note pictures).
public enum SkillGroupID {
    public static let separator: Character = "~"
    /// Folder inside a board page's folder that holds its groups' content (`Sections/<section id>/media/`).
    public static let folderName = "Sections"

    public static func make(containerID: String, sectionID: String) -> String {
        "\(containerID)\(separator)\(sectionID)"
    }

    /// The board page and section ids inside `id`; nil for an ordinary page id.
    public static func split(_ id: String) -> (containerID: String, sectionID: String)? {
        let parts = id.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    public static func isGroup(_ id: String) -> Bool { split(id) != nil }

    /// True when `sectionID` can name a folder: no separators, no dot names, no control characters.
    public static func isUsableSectionID(_ sectionID: String) -> Bool {
        !sectionID.isEmpty && sectionID.utf8.count <= 255 && sectionID != "." && sectionID != ".."
            && !sectionID.hasPrefix(".") && !sectionID.contains("/") && !sectionID.contains("\\")
            && !sectionID.contains(separator) && !sectionID.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    /// Where a group's content folder lives under its board page's folder.
    public static func contentFolder(containerFolder: URL, sectionID: String) -> URL {
        containerFolder
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent(sectionID, isDirectory: true)
    }

    /// The group's media folder (`Sections/<section id>/media/`).
    public static func mediaFolder(containerFolder: URL, sectionID: String) -> URL {
        contentFolder(containerFolder: containerFolder, sectionID: sectionID)
            .appendingPathComponent("media", isDirectory: true)
    }

    /// The board page's folder and the section id when `folder` is a group's content folder.
    static func owner(ofContentFolder folder: URL) -> (containerFolder: URL, sectionID: String)? {
        let parent = folder.deletingLastPathComponent()
        guard parent.lastPathComponent == folderName, isUsableSectionID(folder.lastPathComponent) else { return nil }
        return (parent.deletingLastPathComponent(), folder.lastPathComponent)
    }
}

extension SkillBoardSection {
    /// The group as a page: what opens when its title is tapped. A skill page parented to the board page that holds
    /// the group's material; its cover is the strip picture.
    public func asPage(container: ExercisePageManifest, childIDs: [String]) -> ExercisePageManifest {
        ExercisePageManifest(
            id: SkillGroupID.make(containerID: container.id, sectionID: id),
            title: title,
            pageType: .skill,
            iconName: icon,
            iconType: iconType,
            coverMediaFilename: imageFilename,
            markdownBody: markdownBody,
            mediaFilenames: mediaFilenames,
            mediaComments: mediaComments,
            linkURLs: linkURLs,
            linkMetadata: linkMetadata,
            linkComments: linkComments,
            dependencyPageIDs: dependencyPageIDs,
            dependencyMediaFilenames: dependencyMediaFilenames,
            dependencyLinkURLs: dependencyLinkURLs,
            childIDs: childIDs,
            parentID: container.id,
            order: order,
            createdAt: container.createdAt,
            updatedAt: container.updatedAt
        )
    }

    /// Takes the group's own content back from an edited `asPage` result: the title and icon, notes, media and
    /// their comments, links and theirs, prerequisites and the strip picture (the page's cover).
    public mutating func adopt(_ page: ExercisePageManifest) {
        let newTitle = page.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newTitle.isEmpty { title = newTitle }
        icon = page.iconName
        iconType = page.iconName == nil ? nil : page.iconType
        markdownBody = page.markdownBody
        mediaFilenames = page.mediaFilenames
        mediaComments = page.mediaComments
        linkURLs = page.linkURLs
        linkMetadata = page.linkMetadata
        linkComments = page.linkComments
        dependencyPageIDs = page.dependencyPageIDs
        dependencyMediaFilenames = page.dependencyMediaFilenames
        dependencyLinkURLs = page.dependencyLinkURLs
        imageFilename = page.coverMediaFilename
    }
}
