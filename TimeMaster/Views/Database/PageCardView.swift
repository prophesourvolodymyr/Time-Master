import SwiftUI

struct PageCardView: View {
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    let page: ExercisePage
    var isGridMode: Bool = false
    var onAddToWorkout: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onAddChild: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onMove: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    /// Drags the page's id as plain text; false where the list around the card drags and drops cards itself
    /// (`PageCardDragDrop`).
    var isDraggable = true
    /// A tap on the cover opens the page and plays its first clip (`PageCoverOpening`); nil leaves the cover to the card.
    var onOpenCover: (() -> Void)? = nil
    /// Where the page sits below the list's container ("Footwork › Drills"); nil for a direct child.
    var location: String? = nil
    /// Why a search showed the page when its title did not match.
    var match: ContainerMatchReason? = nil
    @ScaledMetric(relativeTo: .body) private var listThumbnailSize: CGFloat = 56

    var body: some View {
        if isDraggable {
            card.onDrag { NSItemProvider(object: page.manifest.id as NSString) }
        } else {
            card
        }
    }

    @ViewBuilder
    private var card: some View {
        if isGridMode {
            gridCard
        } else {
            listRow
        }
    }

    /// The card's cover, opening the page when tapped where the screen hands over `onOpenCover`.
    @ViewBuilder
    private func coverTarget<Cover: View>(
        cornerRadius: CGFloat,
        glyphSize: CGFloat,
        @ViewBuilder cover: () -> Cover
    ) -> some View {
        if let onOpenCover {
            cover().modifier(PageCoverTap(page: page, cornerRadius: cornerRadius, glyphSize: glyphSize, onOpen: onOpenCover))
        } else {
            cover()
        }
    }

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverTarget(cornerRadius: 0, glyphSize: 34) {
                if page.isNote { noteHeroGrid } else { coverHeroGrid }
            }
            infoGrid
        }
        .modifier(TimeMasterCardSurface(flat: true))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contextMenu { contextMenuContent }
    }

    private var listRow: some View {
        HStack(alignment: .center, spacing: 12) {
            coverTarget(cornerRadius: 10, glyphSize: 22) { coverArea }
                .accessibilityHidden(onOpenCover == nil)
            infoArea
        }
        .frame(minHeight: listThumbnailSize)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .contextMenu { contextMenuContent }
    }

    private var contextMenuContent: some View {
        PageCardMenu(
            page: page,
            onAddToWorkout: onAddToWorkout,
            onEdit: onEdit,
            onAddChild: onAddChild,
            onDuplicate: onDuplicate,
            onMove: onMove,
            onDelete: onDelete
        )
    }

    private var coverHeroGrid: some View {
        ZStack(alignment: .bottomLeading) {
            if page.isContainer {
                DatabaseGroupCover(page: page)
            } else if let coverURL = page.coverImageURL {
                coverImageGrid(url: coverURL)
            } else if let type = page.effectiveWorkoutType {
                gradientCoverGrid(color: Color(hex: type.colorHex))
            } else {
                gradientCoverGrid(color: nil)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(spacing: 6) {
                if page.isContainer {
                    countPill
                }
                if let type = page.effectiveWorkoutType {
                    typeChip(name: type.name, colorHex: type.colorHex)
                }
            }
            .padding(10)
        }
        .frame(height: 120)
        .clipped()
    }

    /// How many pages a container holds: shown once, big enough to read over any cover.
    private var countPill: some View {
        let count = page.totalChildCount
        return HStack(spacing: 5) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 14, weight: .bold))
            Text("\(count)")
                .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .modifier(ContainerTileChipSurface())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count == 1 ? "1 page" : "\(count) pages")
    }

    private func typeChip(name: String, colorHex: String) -> some View {
        Text(name)
            .font(TimeMasterFont.black(13, relativeTo: .caption))
            .foregroundStyle(Color(hex: colorHex))
            .modifier(ContainerTileChipSurface(stroke: Color(hex: colorHex).opacity(0.6)))
    }

    private func noteGlyph(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.surface2)
            .overlay { noteIcon(size: size * 0.5) }
            .frame(width: size, height: size)
    }

    private var noteHeroGrid: some View {
        LinearGradient(
            colors: [Theme.toolbarOrange.opacity(0.18), Theme.toolbarOrange.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay { noteIcon(size: 44) }
        .frame(height: 120)
        .clipped()
    }

    @ViewBuilder
    private func noteIcon(size: CGFloat) -> some View {
        if let name = page.manifest.iconName, !name.isEmpty {
            SkillIconView(iconName: name, iconType: page.manifest.iconType, size: size)
        } else {
            Image(systemName: "note.text")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange)
        }
    }

    private func coverImageGrid(url: URL) -> some View {
        AsyncCoverImage(url: url, height: 120, contentMode: .fill, overlayGradient: false)
            .frame(height: 120)
    }

    private func gradientCoverGrid(color: Color?) -> some View {
        Group {
            if let color {
                LinearGradient(
                    colors: [color.opacity(0.2), color.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var infoGrid: some View {
        VStack(alignment: .leading, spacing: 3) {
            titleLabel(font: TimeMasterFont.rowTitle())
            if let location {
                ContainerPathLabel(path: location)
            }
            if page.isNote {
                let preview = NotePreview.text(from: page.manifest.markdownBody)
                if !preview.isEmpty {
                    Text(preview)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
            }

            if let details = gridDetails {
                Text(details)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var coverArea: some View {
        if page.isNote {
            noteGlyph(size: listThumbnailSize)
        } else if page.isContainer {
            DatabaseGroupCover(page: page)
                .frame(width: listThumbnailSize, height: listThumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if let coverURL = page.coverImageURL {
            AsyncCoverImage(url: coverURL, height: listThumbnailSize, overlayGradient: false)
                .frame(width: listThumbnailSize, height: listThumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            gradientFallback
        }
    }

    private var gradientFallback: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: listThumbnailSize, height: listThumbnailSize)
    }

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleLabel(font: TimeMasterFont.black(17))

            if !listMetadata.isEmpty {
                Text(listMetadata)
                    .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            if let location {
                ContainerPathLabel(path: location)
            }
            if let match {
                ContainerMatchLabel(reason: match)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func titleLabel(font: Font) -> some View {
        if page.isSkillLike {
            SkillEditableTitle(pageID: page.manifest.id, title: page.title, font: font, lineLimit: 2) {
                navigationState.path.append(DatabasePageRoute(pageID: page.manifest.id))
            }
        } else {
            Text(page.title)
                .font(font)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
        }
    }

    /// What the page holds, in words: a container's pages, an exercise's length, the attachments.
    private var contentParts: [String] {
        var parts: [String] = []
        if page.isContainer {
            let count = page.totalChildCount
            parts.append("\(count) \(count == 1 ? "page" : "pages")")
        }
        if page.hasWorkoutConfig, let duration = page.manifest.duration {
            parts.append("\(duration)s")
        }
        if page.hasMedia {
            let count = page.mediaURLs.count
            parts.append("\(count) \(count == 1 ? "attachment" : "attachments")")
        }
        return parts
    }

    private var listMetadata: String {
        if page.isNote { return NotePreview.text(from: page.manifest.markdownBody) }
        let kind = page.effectiveWorkoutType?.name ?? pageTypeLabel ?? "Container"
        return ([kind] + contentParts).joined(separator: " · ")
    }

    /// The line under a gallery card's title; its type is a chip on the cover and its size the pill beside it.
    private var gridDetails: String? {
        let parts = contentParts
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var pageTypeLabel: String? {
        switch page.pageType {
        case .exercise: "Exercise"
        case .skill: "Skill"
        case .tutorial: "Tutorial"
        case .note: "Note"
        case nil: nil
        }
    }


}
