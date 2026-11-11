import SwiftUI
import TimeMasterCore

/// One to-do: nesting, a check circle, its picture or icon (or the linked workout's or page's), its text edited in
/// place, a few lines of note, its picture strip and its link chips, and a menu.
struct TodoRowView: View {
    let item: TodoItem
    let depth: Int
    let hasChildren: Bool
    let isCollapsed: Bool
    let canIndent: Bool
    let canOutdent: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let isFocused: Bool
    let artwork: ChecklistArtwork
    /// What each link points at, by link id.
    let targets: [String: ChecklistLinkTarget]
    let pictureURLs: [URL]
    var linkMetadata: [LinkMetadata] = []
    var comments: [String: String] = [:]
    var isPreview = false
    let actions: TodoRowActions

    @State private var title: String
    @ScaledMetric(relativeTo: .body) private var thumbSide: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var stripSide: CGFloat = 40

    static let indentStep: CGFloat = 24

    init(
        item: TodoItem, depth: Int, hasChildren: Bool, isCollapsed: Bool, canIndent: Bool, canOutdent: Bool,
        canMoveUp: Bool, canMoveDown: Bool, isFocused: Bool, artwork: ChecklistArtwork, targets: [String: ChecklistLinkTarget],
        pictureURLs: [URL], linkMetadata: [LinkMetadata] = [], comments: [String: String] = [:], isPreview: Bool = false,
        actions: TodoRowActions
    ) {
        self.item = item
        self.depth = depth
        self.hasChildren = hasChildren
        self.isCollapsed = isCollapsed
        self.canIndent = canIndent
        self.canOutdent = canOutdent
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.isFocused = isFocused
        self.artwork = artwork
        self.targets = targets
        self.pictureURLs = pictureURLs
        self.linkMetadata = linkMetadata
        self.comments = comments
        self.isPreview = isPreview
        self.actions = actions
        _title = State(initialValue: item.title)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            disclosure
            checkbox
            visual
            VStack(alignment: .leading, spacing: 6) {
                titleView
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !pictureURLs.isEmpty {
                    ChecklistImageStrip(urls: pictureURLs, side: stripSide, onOpen: actions.openPicture)
                }
                if !item.links.isEmpty {
                    ChecklistFlowLayout(spacing: 6) {
                        ForEach(item.links) { link in
                            chip(link)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, item.links.isEmpty && pictureURLs.isEmpty ? 0 : 4)
            trailing
        }
        .padding(.leading, CGFloat(depth - 1) * Self.indentStep)
        .padding(.vertical, 3)
        .modifier(TodoSwipeModifier(canIndent: canIndent && !isPreview, canOutdent: canOutdent && !isPreview, onIndent: actions.indent, onOutdent: actions.outdent))
        .contentShape(Rectangle())
        .contextMenu { if !isPreview { menuItems } }
        .onChange(of: item.title) { newValue in
            if !isFocused { title = newValue }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ChecklistLook.spokenSummary(item))
        .accessibilityAction(named: "Make a sub-to-do") { if canIndent { actions.indent() } }
        .accessibilityAction(named: "Bring back a level") { if canOutdent { actions.outdent() } }
        .accessibilityAction(named: "Edit") { actions.edit() }
    }

    // MARK: Pieces

    @ViewBuilder
    private var disclosure: some View {
        if hasChildren {
            Button(action: actions.toggleCollapse) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 18, height: 34)
                    .contentShape(Rectangle())
            }
            .keyNavPlainButtonStyle()
            .accessibilityLabel(isCollapsed ? "Show sub-to-dos" : "Hide sub-to-dos")
        } else {
            Color.clear.frame(width: 18, height: 34)
        }
    }

    private var checkbox: some View {
        Button(action: actions.toggle) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(item.isDone ? Theme.toolbarOrange : Theme.textSecondary)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle(shape: .circle)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isDone ? "Done" : "Not done")
        .accessibilityHint(item.isDone ? "Opens it again" : "Checks it off")
        .accessibilityAddTraits(item.isDone ? .isSelected : [])
    }

    @ViewBuilder
    private var visual: some View {
        if artwork.hasCover || artwork.hasIcon {
            Button(action: actions.chooseIcon) {
                if artwork.hasCover {
                    ChecklistThumbnail(cover: artwork.cover, tintHex: ChecklistLook.tintHex(item), side: thumbSide, marksWorkout: artwork.workout != nil)
                        .overlay(alignment: .topLeading) {
                            if item.iconName != nil || item.iconImage != nil {
                                ChecklistIconTile(icon: artwork.icon, tintHex: ChecklistLook.tintHex(item), side: thumbSide * 0.46, onCard: true)
                                    .offset(x: -5, y: -5)
                            }
                        }
                } else {
                    ChecklistIconTile(icon: artwork.icon, tintHex: ChecklistLook.tintHex(item), side: iconSide)
                        .frame(height: 34)
                }
            }
            .keyNavPlainButtonStyle()
            .disabled(isPreview)
            .help("Change the icon")
            .accessibilityLabel("Change the icon of \(item.title)")
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if isPreview {
            Text(item.title)
                .font(TimeMasterFont.body(16))
                .foregroundStyle(item.isDone ? Theme.textSecondary : Theme.textPrimary)
                .strikethrough(item.isDone, color: Theme.textSecondary)
                .padding(.top, 7)
        } else {
            TodoTextField(
                text: $title,
                placeholder: "To-do",
                isDone: item.isDone,
                isFocused: isFocused,
                onFocusChange: { focused in
                    actions.focusChanged(focused)
                    if !focused { actions.commitTitle(title) }
                },
                onSubmit: { actions.submit(title) },
                onIndent: { actions.commitTitle(title); actions.indent() },
                onOutdent: { actions.commitTitle(title); actions.outdent() }
            )
            .padding(.top, 7)
            .accessibilityLabel("To-do text")
        }
    }

    private func chip(_ link: TodoLink) -> some View {
        let target = targets[link.id] ?? .unreadable(link.url)
        var onPlay: (() -> Void)?
        if case .workout(let workout) = target, !isPreview { onPlay = { actions.playWorkout(workout) } }
        return ChecklistLinkChip(
            link: link,
            target: target,
            linkMetadata: linkMetadata,
            comments: comments,
            onOpen: { actions.openLink(link, target) },
            onPlay: onPlay,
            onRemove: isPreview ? nil : { actions.removeLink(link) }
        )
        .allowsHitTesting(!isPreview)
    }

    private var trailing: some View {
        HStack(spacing: 4) {
            if hasChildren {
                let total = item.children.progressTotal
                Text("\(item.children.progressDone)/\(total)")
                    .font(TimeMasterFont.technical())
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel("\(item.children.progressDone) of \(total) sub-to-dos done")
            }
            if !isPreview {
                Menu {
                    menuItems
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 34)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .keyNavPlainButtonStyle()
                .fixedSize()
                .accessibilityLabel("More for \(item.title)")
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var menuItems: some View {
        Button(action: actions.edit) { Label("Edit…", systemImage: "slider.horizontal.3") }
        Button(action: actions.chooseIcon) { Label("Icon…", systemImage: "face.smiling") }
        Button(action: actions.addSubTodo) { Label("Add a sub-to-do", systemImage: "arrow.turn.down.right") }
        Divider()
        if canIndent {
            Button(action: actions.indent) { Label("Make a sub-to-do", systemImage: "increase.indent") }
        }
        if canOutdent {
            Button(action: actions.outdent) { Label("Bring back a level", systemImage: "decrease.indent") }
        }
        if canMoveUp {
            Button(action: actions.moveUp) { Label("Move up", systemImage: "arrow.up") }
        }
        if canMoveDown {
            Button(action: actions.moveDown) { Label("Move down", systemImage: "arrow.down") }
        }
        Divider()
        Button(role: .destructive, action: actions.remove) { Label("Delete", systemImage: "trash") }
    }
}
