import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers

/// One sub-skill of the sections list: the done check, its icon (opens the icon picker), its title and a chevron on
/// the first line; the status chip (a tap moves it on), its type and what it holds on the second; a progress bar when
/// it has sub-skills of its own. Tapping anywhere else opens it. Draggable: dropped on another row it lands before or
/// after it, or inside it from the middle.
struct SkillBoardRow: View {
    let item: SkillBoardItem
    let tintHex: String
    let hoverZone: SkillDropZone?
    let state: SkillBoardDragState
    let actions: SkillBoardActions
    let moveTargets: [SkillBoardLane]
    let onDrop: (SkillBoardDrag, SkillBoardDropPlacement) -> Void

    @State private var height = SkillRowHeight()
    @State private var typeEditor: SkillTypeEditorRoute?
    @State private var showingTypeManager = false
    @AppStorage(SkillSettings.showsCardCoversKey) private var showsCovers = true

    private var page: ExercisePage { item.page }

    var body: some View {
        let tint = Color(hex: tintHex)
        let progress = item.progress
        VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            if showsCovers, let cover = page.cardCoverURL {
                SkillLocalImage(url: cover, maxPixel: 720)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius - 4, style: .continuous))
                    .accessibilityHidden(true)
            }
            HStack(spacing: SkillMetrics.s2) {
                SkillDoneButton(title: item.title, status: item.status, pageID: item.id) { actions.setStatus(page, $0) }
                HStack(spacing: SkillMetrics.s3) {
                    SkillIconChangeButton(page: page, side: 40) { actions.changeIcon(page) }
                    Button(action: open) {
                        HStack(spacing: 0) {
                            SkillEditableTitle(
                                pageID: item.id,
                                title: item.title,
                                font: TimeMasterFont.rowTitle(),
                                color: Theme.textPrimary.opacity(item.status.titleOpacity),
                                onOpen: open
                            )
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: SkillMetrics.touch)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SkillPressButtonStyle())
                    .accessibilityLabel(item.title)
                    .accessibilityHint("Opens this sub-skill")
                    .keyNavRole(.excluded)
                }
                Button(action: open) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: SkillMetrics.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SkillPressButtonStyle())
                .accessibilityLabel("Open \(item.title)")
                .keyNavRole(.excluded)
            }

            HStack(spacing: SkillMetrics.s2) {
                Button {
                    actions.setStatus(page, item.status.next)
                } label: {
                    SkillStatusChip(item.status)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SkillPressButtonStyle())
                .accessibilityLabel("Status: \(item.status.title)")
                .accessibilityHint("Changes the status")
                .help("Click to change the status")
                .fixedSize()
                SkillTypePicker(pageID: item.id) {
                    if let type = item.type {
                        SkillTypeChip(type: type)
                    } else {
                        SkillAddTypeChip()
                    }
                }
                Button(action: open) {
                    HStack(spacing: 0) {
                        metaLine(progress: progress)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SkillPressButtonStyle())
                .layoutPriority(-1)
                .accessibilityHidden(true)
                .keyNavRole(.excluded)
            }
            .padding(.leading, 52)

            if progress.total > 0 {
                ProgressView(value: min(1, max(0, progress.fraction)))
                    .progressViewStyle(.linear)
                    .tint(tint)
                    .padding(.leading, 52)
                    .padding(.trailing, SkillMetrics.s1)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, SkillMetrics.s3)
        .padding(.vertical, SkillMetrics.s2)
        .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, accent: tint, flat: true))
        .skillTypeBase(item.type, cornerRadius: SkillMetrics.fieldRadius)
        .overlay { dropIndicator }
        .background(heightReader)
        .contentShape(RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous))
        .onTapGesture(perform: open)
        .keyNavTarget(id: item.id, role: .primary, shape: .roundedRectangle(cornerRadius: SkillMetrics.fieldRadius), action: open)
        .skillTypeSheets(for: item.id, editor: $typeEditor, showingManager: $showingTypeManager)
        .contextMenu {
            SkillPageMenuItems(
                item: item,
                actions: actions,
                moveTargets: moveTargets,
                typeEditor: $typeEditor,
                showingTypeManager: $showingTypeManager
            )
        }
        .onDrag { state.provider(for: .page(item.id)) }
        .onDrop(
            of: [UTType.plainText],
            delegate: SkillRowDropDelegate(rowID: item.id, height: height, state: state, onDrop: onDrop)
        )
        .accessibilityAction(named: "Change status") { actions.setStatus(page, item.status.next) }
        .accessibilityAction(named: "Change icon") { actions.changeIcon(page) }
    }

    private func open() {
        actions.open(page)
    }

    // MARK: Meta

    private func metaLine(progress: SkillBoardTally) -> some View {
        HStack(spacing: SkillMetrics.s3) {
            if progress.total > 0 {
                badge("checklist", "\(progress.completed) of \(progress.total) done")
            }
            if item.mediaCount > 0 {
                badge("paperclip", "\(item.mediaCount)")
            }
            if item.linkCount > 0 {
                badge("link", "\(item.linkCount)")
            }
            if item.noteCount > 0 {
                badge("note.text", "\(item.noteCount)")
            }
            if item.dependencyCount > 0 {
                badge("arrow.triangle.branch", "\(item.dependencyCount)")
            }
            if progress.total == 0 && item.mediaCount == 0 && item.linkCount == 0 && item.noteCount == 0 {
                Text("Nothing attached yet")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
            }
        }
    }

    private func badge(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(TimeMasterFont.caption())
        }
        .foregroundStyle(Theme.textSecondary)
        .lineLimit(1)
    }

    // MARK: Drop feedback

    @ViewBuilder
    private var dropIndicator: some View {
        if let zone = hoverZone {
            switch zone {
            case .into:
                RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
                    .strokeBorder(Theme.toolbarOrange, lineWidth: 2)
                    .overlay(alignment: .topTrailing) {
                        Text("Move inside")
                            .font(TimeMasterFont.black(11, relativeTo: .caption2))
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.toolbarOrange))
                            .padding(6)
                    }
                    .allowsHitTesting(false)
            case .before:
                VStack(spacing: 0) {
                    Capsule().fill(Theme.toolbarOrange).frame(height: 3)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .offset(y: -5)
                .allowsHitTesting(false)
            case .after:
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Capsule().fill(Theme.toolbarOrange).frame(height: 3)
                }
                .padding(.horizontal, 4)
                .offset(y: 5)
                .allowsHitTesting(false)
            }
        }
    }

    private var heightReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { height.value = proxy.size.height }
                .onChange(of: proxy.size.height) { newValue in height.value = newValue }
        }
    }
}
