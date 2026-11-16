import SwiftUI
import TimeMasterCore

/// A page in a container's gallery: its cover (a clip's first frame or a photo; a container shows the covers inside
/// it, a note its first lines) filling a portrait card, its kind and its clips and stills on top, its title, type and
/// place at the bottom.
struct ContainerPageTile: View {
    static let cornerRadius: CGFloat = 20
    /// Width over height.
    static let aspect: CGFloat = 4 / 5

    let entry: ContainerBrowseEntry
    let stats: ContainerPageStats

    private var page: ExercisePage { entry.page }
    private var kind: ContainerPageKind { ContainerPageKind(page) }
    private var typeColor: Color? { page.effectiveWorkoutType.map { Color(hex: $0.colorHex) } }
    private var typeSymbol: String { page.effectiveWorkoutType?.iconName ?? kind.symbolName }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        Color.clear
            .aspectRatio(Self.aspect, contentMode: .fit)
            .overlay { cover }
            .overlay { shade }
            .overlay(alignment: .top) {
                HStack(alignment: .top, spacing: 6) {
                    kindChip
                    Spacer(minLength: 0)
                    mediaBadge
                        .fixedSize()
                }
                .padding(10)
            }
            .overlay(alignment: .bottomLeading) { caption.padding(12) }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(shape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(page.title)
            .accessibilityValue(accessibilityDetail)
    }

    // MARK: Cover

    @ViewBuilder
    private var cover: some View {
        switch kind {
        case .note:
            noteCover
        case .container:
            containerCover
        case .exercise, .skill, .tutorial:
            if let url = page.coverImageURL {
                GeometryReader { proxy in
                    AsyncCoverImage(
                        url: url,
                        fallbackIcon: typeSymbol,
                        fallbackColor: typeColor,
                        height: proxy.size.height,
                        contentMode: .fill,
                        overlayGradient: false
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }
                .id(url)
            } else {
                plainCover
            }
        }
    }

    @ViewBuilder
    private var containerCover: some View {
        if DatabaseGroupCover.descendantCoverURLs(in: page).isEmpty {
            ZStack {
                LinearGradient(
                    colors: [Theme.toolbarOrange.opacity(0.2), Theme.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "folder.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Theme.toolbarOrange.opacity(0.45))
            }
        } else {
            DatabaseGroupCover(page: page)
        }
    }

    private var noteCover: some View {
        let preview = NotePreview.text(from: page.manifest.markdownBody, maxLines: 6, maxLength: 220)
        return ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Theme.toolbarOrange.opacity(0.24), Theme.surface2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if preview.isEmpty {
                noteIcon(size: 44)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(preview)
                    .font(TimeMasterFont.body(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.textPrimary.opacity(0.78))
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 46)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func noteIcon(size: CGFloat) -> some View {
        if let name = page.manifest.iconName, !name.isEmpty {
            SkillIconView(iconName: name, iconType: page.manifest.iconType, size: size)
        } else {
            Image(systemName: "note.text")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange.opacity(0.8))
        }
    }

    private var plainCover: some View {
        let tint = typeColor ?? Theme.toolbarOrange
        return ZStack {
            LinearGradient(colors: [tint.opacity(0.28), Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: typeSymbol)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(tint.opacity(0.5))
        }
    }

    private var shade: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.42), location: 0),
                .init(color: .clear, location: 0.26),
                .init(color: .clear, location: 0.46),
                .init(color: .black.opacity(0.86), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    // MARK: Chips and caption

    private var kindChip: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 9, weight: .bold))
            Text(kind.title)
                .font(TimeMasterFont.black(10, relativeTo: .caption2))
        }
        .foregroundStyle(.white)
        .modifier(ContainerTileChipSurface())
    }

    @ViewBuilder
    private var mediaBadge: some View {
        if stats.clips > 0 || stats.stills > 0 {
            HStack(spacing: 7) {
                if stats.clips > 0 { mediaCount(stats.clips, symbol: "film.fill") }
                if stats.stills > 0 { mediaCount(stats.stills, symbol: "photo.fill") }
            }
            .font(TimeMasterFont.black(10, relativeTo: .caption2))
            .foregroundStyle(.white)
            .modifier(ContainerTileChipSurface())
        }
    }

    private func mediaCount(_ count: Int, symbol: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
            Text("\(count)")
                .monospacedDigit()
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(page.title)
                .font(TimeMasterFont.black(16, relativeTo: .headline))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
            if page.effectiveWorkoutType != nil || detail != nil {
                HStack(spacing: 6) {
                    if let type = page.effectiveWorkoutType {
                        Text(type.name)
                            .font(TimeMasterFont.black(10, relativeTo: .caption2))
                            .foregroundStyle(Color(hex: type.colorHex))
                            .modifier(ContainerTileChipSurface(stroke: Color(hex: type.colorHex).opacity(0.6)))
                    }
                    if let detail {
                        Text(detail)
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }
                }
            }
            if let path = entry.pathText {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 9, weight: .bold))
                    Text(path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(TimeMasterFont.caption())
                .foregroundStyle(.white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Size of a container, length of an exercise.
    private var detail: String? {
        switch kind {
        case .container:
            return stats.pages == 1 ? "1 page" : "\(stats.pages) pages"
        case .exercise:
            guard let duration = page.manifest.duration else { return nil }
            if let sets = page.manifest.sets, sets > 1 { return "\(sets) × \(duration)s" }
            return "\(duration)s"
        case .note, .skill, .tutorial:
            return nil
        }
    }

    private var accessibilityDetail: String {
        var parts = [kind.title]
        if let type = page.effectiveWorkoutType { parts.append(type.name) }
        if let detail { parts.append(detail) }
        if stats.clips > 0 { parts.append(stats.clips == 1 ? "1 clip" : "\(stats.clips) clips") }
        if stats.stills > 0 { parts.append(stats.stills == 1 ? "1 photo" : "\(stats.stills) photos") }
        if let path = entry.pathText { parts.append("in \(path)") }
        return parts.joined(separator: ", ")
    }
}

/// The dark capsule behind the chips laid over a cover.
private struct ContainerTileChipSurface: ViewModifier {
    var stroke: Color = Color.white.opacity(0.18)

    func body(content: Content) -> some View {
        content
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule(style: .continuous).fill(Color.black.opacity(0.5)))
            .overlay(Capsule(style: .continuous).strokeBorder(stroke, lineWidth: 1))
    }
}

/// A page as a row of a container's list: the Database row (cover, title, type and counts) with its place below the
/// container and why a search showed it. Opens the page on tap and carries the page menu and drops onto containers.
struct ContainerPageListRow: View {
    let page: ExercisePage
    var location: String? = nil
    var match: ContainerMatchReason? = nil
    let actions: ContainerPageActions

    var body: some View {
        NavigationLink(value: DatabasePageRoute(pageID: page.manifest.id)) {
            PageCardView(
                page: page,
                onAddToWorkout: { actions.addToWorkout(page) },
                onEdit: { actions.edit(page) },
                onAddChild: { actions.addInside(page) },
                onDuplicate: { actions.duplicate(page) },
                onMove: { actions.move(page) },
                onDelete: { actions.delete(page) },
                onMoveIntoContainer: { actions.moveInside($0, page) },
                location: location,
                match: match
            )
            .padding(12)
            .modifier(TimeMasterCardSurface(cornerRadius: 16, flat: true))
        }
        .buttonStyle(ContainerTileButtonStyle(cornerRadius: 16))
        .accessibilityHint("Opens this page")
    }
}
