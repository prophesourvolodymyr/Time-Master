import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

/// The top of a library page in its full view (Tmax's cover hero): the page's cover across the width (its chosen
/// picture, else its first photo or the first frame of its first video, or a warm wash when it has none) fading into the
/// page, the path to the page, and the page's head over it. A glass chip in the corner picks another cover among the
/// page's photos and videos, adds a new picture, or goes back to the first file.
struct PageCoverHero<Header: View>: View {
    let page: ExercisePage
    let breadcrumbs: [ExercisePage]
    let isImportingCover: Bool
    /// One of the page's media file names, or nil for its first file.
    let onChooseCover: (String?) -> Void
    let onImportCover: () -> Void
    let header: Header

    @ScaledMetric(relativeTo: .largeTitle) private var minimumHeight: CGFloat = 220
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject private var revisions = MediaRevisions.shared

    init(
        page: ExercisePage,
        breadcrumbs: [ExercisePage],
        isImportingCover: Bool,
        onChooseCover: @escaping (String?) -> Void,
        onImportCover: @escaping () -> Void,
        @ViewBuilder header: () -> Header
    ) {
        self.page = page
        self.breadcrumbs = breadcrumbs
        self.isImportingCover = isImportingCover
        self.onChooseCover = onChooseCover
        self.onImportCover = onImportCover
        self.header = header()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            Spacer(minLength: minimumHeight * 0.35)
            if breadcrumbs.count > 1 {
                breadcrumbRow
            }
            header
        }
        .skillsContained()
        .padding(.bottom, SkillMetrics.s5)
        .frame(minHeight: minimumHeight, alignment: .bottomLeading)
        .background { backdrop }
        .overlay(alignment: .top) {
            HStack {
                Spacer(minLength: 0)
                coverControl
            }
            .skillsContained()
            .padding(.top, SkillMetrics.s1)
        }
        .clipped()
    }

    // MARK: Backdrop

    private var backdrop: some View {
        GeometryReader { proxy in
            ZStack {
                if let url = page.coverImageURL {
                    AsyncCoverImage(url: url, height: proxy.size.height, overlayGradient: false)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .id("\(url.absoluteString)#\(revisions.revision(of: url))")
                } else {
                    wash
                }
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.35), location: 0),
                        .init(color: .clear, location: 0.3),
                        .init(color: .clear, location: 0.42),
                        .init(color: .black.opacity(0.62), location: 0.8),
                        .init(color: Theme.background, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .accessibilityHidden(true)
    }

    /// A page without a picture: Tmax orange warming the corner, the page's kind as a large faint glyph.
    private var wash: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Theme.toolbarOrange.opacity(0.22), Theme.surface2, Theme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: PageKindStyle.symbol(page))
                .font(.system(size: minimumHeight * 0.55, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.05))
                .padding(.top, SkillMetrics.s4)
                .padding(.trailing, SkillMetrics.s6)
        }
    }

    // MARK: Path

    private var breadcrumbRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    if crumb.id != page.id {
                        NavigationLink(value: DatabasePageRoute(pageID: crumb.manifest.id)) {
                            Text(crumb.title)
                                .font(TimeMasterFont.black(11, relativeTo: .caption2))
                                .foregroundStyle(Color.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        .keyNavPlainButtonStyle()
                    } else {
                        Text(crumb.title)
                            .font(TimeMasterFont.black(11, relativeTo: .caption2))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.bottom, 2)
        }
    }

    // MARK: Cover control

    private struct CoverChoice: Identifiable {
        let filename: String
        let title: String
        let symbol: String
        let isCurrent: Bool

        var id: String { filename }
    }

    /// The page's photos and videos, named by their note's first line or as "Video 2", "Photo 1".
    private var coverChoices: [CoverChoice] {
        var photos = 0
        var videos = 0
        return page.mediaURLs.compactMap { url -> CoverChoice? in
            let isVideo = PageMediaKind.isVideo(url)
            guard isVideo || UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true else { return nil }
            if isVideo { videos += 1 } else { photos += 1 }
            let note = page.manifest.mediaComments[url.lastPathComponent].flatMap { Self.firstLine(of: $0) }
            return CoverChoice(
                filename: url.lastPathComponent,
                title: note ?? (isVideo ? "Video \(videos)" : "Photo \(photos)"),
                symbol: isVideo ? "video" : "photo",
                isCurrent: page.coverImageURL == url
            )
        }
    }

    private static func firstLine(of note: String) -> String? {
        let line = note
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "#>*- ").union(.whitespaces)) }
            .first { !$0.isEmpty }
        return line.map { $0.count > 40 ? String($0.prefix(40)) + "…" : $0 }
    }

    @ViewBuilder
    private var coverControl: some View {
        let choices = coverChoices
        if choices.isEmpty {
            Button(action: onImportCover) {
                chip(title: "Add cover")
            }
            .keyNavPlainButtonStyle(shape: .capsule)
            .disabled(isImportingCover)
            .help("Add a cover picture")
            .accessibilityLabel("Add a cover picture")
        } else {
            Menu {
                SwiftUI.Section("From this page") {
                    ForEach(choices) { choice in
                        Button {
                            onChooseCover(choice.filename)
                        } label: {
                            Label(choice.title, systemImage: choice.isCurrent ? "checkmark" : choice.symbol)
                        }
                    }
                }
                Button(action: onImportCover) {
                    Label("Add a picture…", systemImage: "photo.badge.plus")
                }
                if page.manifest.coverMediaFilename != nil {
                    Button {
                        onChooseCover(nil)
                    } label: {
                        Label("Use the first file", systemImage: "arrow.uturn.backward")
                    }
                }
            } label: {
                chip(title: "Cover")
            }
            .menuStyle(.button)
            .keyNavPlainButtonStyle(shape: .capsule)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(isImportingCover)
            .help("Change the cover")
            .accessibilityLabel("Cover")
            .accessibilityHint("Pick another cover or add a picture")
        }
    }

    private func chip(title: String) -> some View {
        HStack(spacing: 6) {
            if isImportingCover {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(title)
                .font(TimeMasterFont.black(13, relativeTo: .caption))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, SkillMetrics.s3)
        .frame(minHeight: 32)
        .background(Capsule().fill(glass))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .frame(minWidth: SkillMetrics.touch, minHeight: SkillMetrics.touch)
        .contentShape(Rectangle())
    }

    private var glass: AnyShapeStyle {
        reduceTransparency ? AnyShapeStyle(Theme.surface2) : AnyShapeStyle(.ultraThinMaterial)
    }
}
