import SwiftUI
import TimeMasterCore

/// Which of a page's files and links a part shows.
enum PageAttachmentRole: Equatable {
    /// The page's own attachments (on a skill or a tutorial, those not needed first).
    case attachments
    /// What a skill or a tutorial needs in hand first ("Files & links" under Dependencies).
    case dependencies
}

/// What the media cards of a page can do. The page owns the viewer, the importers and the sheets, so every part that
/// shows the page's files hands its taps back here.
struct PageMediaActions {
    let open: (URL) -> Void
    let openNotes: (URL) -> Void
    let cardActions: (URL) -> [MediaCardAction]
    /// The plus of a part's heading.
    let add: (PageAttachmentRole) -> Void
    /// The file importer for a part.
    let addFiles: (PageAttachmentRole) -> Void
    /// The photo library (iPhone and iPad); nil where files are the way in.
    let addPhotos: (() -> Void)?
    let attachPage: () -> Void
}

/// A page's attachments, first wherever the page stacks its parts: its clips and files as Tmax's media strip (a video
/// plays in its card, a double click grows the viewer out of it, the card's menu trims it, makes it the cover and so
/// on), then on a skill or a tutorial its links, and the pages attached to it. With `.dependencies` it is the "Files &
/// links" part of a skill's Dependencies: the files and links to have first. A skill or a tutorial that needs no skills
/// has no Dependencies, so its attachments hold every file and link it has.
struct PageAttachmentsSection: View {
    let page: ExercisePage
    let role: PageAttachmentRole
    let marksCover: Bool
    let playback: MediaInlinePlayback
    let linkedPages: [ExercisePage]
    let actions: PageMediaActions

    var body: some View {
        let urls = mediaURLs
        let links = linkCount
        VStack(alignment: .leading, spacing: SkillMetrics.s3) {
            if urls.isEmpty {
                PageSectionHeader(symbol: symbol, title: title, count: links) {
                    PageSectionAddButton(label: addLabel) { actions.add(role) }
                }
                if links == 0, linkedPages.isEmpty {
                    emptyCard
                }
            } else {
                MediaStrip(
                    title: title,
                    urls: urls,
                    marksCover: marksCover && urls.first == page.coverImageURL,
                    comments: page.mediaCommentsByURL,
                    onOpen: { actions.open(urls[$0]) },
                    onOpenNotes: { actions.openNotes(urls[$0]) },
                    playback: playback,
                    cardActions: { actions.cardActions(urls[$0]) },
                    onAdd: { actions.add(role) },
                    headerSymbol: symbol,
                    headerCount: urls.count + links
                )
            }
            if page.isSkillLike {
                SkillLinksSection(
                    materialID: page.manifest.id,
                    scope: splitsDependencies ? (role == .attachments ? .reference : .dependencies) : .all,
                    showsHeader: false
                )
            }
            if role == .attachments, !linkedPages.isEmpty {
                attachedPages
            }
        }
    }

    /// A skill or a tutorial that keeps what to learn first: its files and links split between Attachments and
    /// Dependencies.
    private var splitsDependencies: Bool { page.isSkillLike && !page.manifest.hidesSkills }

    /// The files this part shows: on a skill or a tutorial they split between its attachments and what it needs first.
    private var mediaURLs: [URL] {
        guard splitsDependencies else { return role == .attachments ? page.mediaURLs : [] }
        let flagged = Set(page.manifest.dependencyMediaFilenames)
        return page.mediaURLs.filter { flagged.contains($0.lastPathComponent) == (role == .dependencies) }
    }

    /// The links listed under the files (a skill's or a tutorial's; other pages have a Links part of their own).
    private var linkCount: Int {
        guard page.isSkillLike else { return 0 }
        guard splitsDependencies else { return role == .attachments ? page.manifest.linkURLs.count : 0 }
        let flagged = Set(page.manifest.dependencyLinkURLs)
        return page.manifest.linkURLs.filter { flagged.contains($0) == (role == .dependencies) }.count
    }

    private var title: String { role == .attachments ? PageTab.attachments.title : "Files & links" }

    private var symbol: String { role == .attachments ? PageTab.attachments.symbol : "doc.on.doc" }

    private var addLabel: String { role == .attachments ? "Add attachments" : "Add files to have first" }

    // MARK: Empty

    private var emptyCard: some View {
        PageEmptyCard(symbol: role == .attachments ? "tray.and.arrow.down" : "doc.on.doc", title: emptyTitle, detail: emptyDetail) {
            HStack(spacing: SkillMetrics.s2) {
                if role == .attachments, let addPhotos = actions.addPhotos {
                    quickAdd("Photos", symbol: "photo.on.rectangle", action: addPhotos)
                }
                quickAdd("Files", symbol: "folder") { actions.addFiles(role) }
            }
        }
    }

    private var emptyTitle: String {
        if role == .dependencies { return "No files or links needed first" }
        return page.isExercise ? "No clips yet" : "Nothing attached yet"
    }

    private var emptyDetail: String {
        if role == .dependencies {
            return "Add what you need in hand to learn this: a document, a video, a link, a photo of the gear."
        }
        if page.isExercise { return "Add the videos, photos and files that show this exercise." }
        if page.isSkillLike { return "Photos, videos, PDFs or a link: whatever helps you learn this." }
        return "Videos, photos and files that belong with what is inside."
    }

    private func quickAdd(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(TimeMasterFont.rowTitle())
        }
        .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 40, horizontalPadding: 14))
    }

    // MARK: Attached pages

    private var attachedPages: some View {
        LazyVStack(alignment: .leading, spacing: SkillMetrics.s2) {
            PageSectionHeader(symbol: "rectangle.stack", title: "Attached pages", count: linkedPages.count) {
                PageSectionTextButton(title: "Attach", action: actions.attachPage)
                    .help("Attach pages")
            }
            ForEach(linkedPages) { linked in
                NavigationLink(value: DatabasePageRoute(pageID: linked.manifest.id)) {
                    PageCardView(page: linked)
                        .padding(SkillMetrics.s3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, flat: true))
                }
                .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: SkillMetrics.fieldRadius))
            }
        }
    }
}

/// The Dependencies of a skill or a tutorial, in Skillmax's layout: "Learn first", the pages and groups to learn before
/// this one in order, then "Files & links", what to have in hand first.
struct PageDependenciesSection: View {
    let page: ExercisePage
    let playback: MediaInlinePlayback
    let actions: PageMediaActions

    var body: some View {
        VStack(alignment: .leading, spacing: SkillMetrics.s6) {
            SkillPrerequisitesSection(materialID: page.manifest.id)
            PageAttachmentsSection(
                page: page,
                role: .dependencies,
                marksCover: false,
                playback: playback,
                linkedPages: [],
                actions: actions
            )
        }
    }
}
