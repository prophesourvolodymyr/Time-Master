import SwiftUI
import TimeMasterCore

/// The head of a library page, the same for every kind: the icon tile (on every page it opens the icon chooser; a
/// skill's or a tutorial's without an icon of its own shows its category as its Skills card does, any other page shows
/// its own icon or what it is), the title (double-click or double-tap renames it), then one row of pills that wraps
/// below the title: the status chips (a skill's done check and status, how many sub-skills are done, the skill type,
/// the workout type; a page that needs no skills keeps only a type it already wears and the workout type) and a pill
/// for each fact (what the page is, the workouts that train it and when, its pages, its clips). `onCover` draws it in
/// white over a cover picture; `compact` is the smaller head of a page shown without its cover.
struct PageHeroHeader: View {
    let page: ExercisePage
    let progress: SkillProgress
    let usage: PageWorkoutUsage
    var onCover = false
    var compact = false
    let onChangeIcon: () -> Void
    let onSetStatus: (SkillStatus) -> Void

    @EnvironmentObject private var store: DatabaseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHoveringIcon = false

    var body: some View {
        VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            titleRow
            pills
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Title

    private var iconSide: CGFloat {
        if compact { return 44 }
        #if os(macOS)
        return 64
        #else
        return 56
        #endif
    }

    private var titleRow: some View {
        HStack(alignment: .center, spacing: compact ? SkillMetrics.s3 : SkillMetrics.s4) {
            iconTile
            PageTitleField(
                pageID: page.manifest.id,
                title: page.title,
                size: compact ? 30 : 40,
                relativeTo: compact ? .title : .largeTitle,
                color: onCover ? .white : Theme.textPrimary
            )
        }
        .shadow(color: .black.opacity(onCover ? 0.4 : 0), radius: 3)
    }

    /// Opens the icon chooser on every kind of page; the pencil on its corner says so, and on the Mac the pointer turns
    /// into a hand over it.
    private var iconTile: some View {
        Button(action: onChangeIcon) {
            icon
                .overlay(alignment: .bottomTrailing) { pencilBadge }
        }
        .buttonStyle(SkillPressButtonStyle())
        #if os(macOS)
        .pageCoverPointer($isHoveringIcon)
        #else
        .onHover { isHoveringIcon = $0 }
        #endif
        .help("Edit the icon")
        .accessibilityLabel("Edit icon")
        .accessibilityHint("Opens the icon chooser")
    }

    /// The page's own picture, symbol or emoji; without one, a skill's or a tutorial's category symbol on a tile, as its
    /// card on the Skills page shows it, and for any other page the symbol of what it is.
    @ViewBuilder
    private var icon: some View {
        if page.iconImageURL != nil || !(page.manifest.iconName ?? "").isEmpty {
            SkillPageIconTile(page: page, size: iconSide, tilesSymbols: true)
        } else if page.isSkillLike {
            SkillCardIcon(page: page, category: SkillCategory.of(page, in: store.index), size: iconSide)
        } else {
            Image(systemName: PageKindStyle.symbol(page))
                .font(.system(size: iconSide * 0.42, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange)
                .frame(width: iconSide, height: iconSide)
                .skillTile(cornerRadius: iconSide * 0.32)
        }
    }

    /// The pencil on the tile's corner says the icon can change; it grows a little under the pointer.
    private var pencilBadge: some View {
        let side: CGFloat = compact ? 20 : 24
        return Image(systemName: "pencil")
            .font(.system(size: compact ? 9 : 11, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: side, height: side)
            .background(Circle().fill(Theme.toolbarOrange))
            .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
            .scaleEffect(isHoveringIcon && !reduceMotion ? 1.12 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHoveringIcon)
            .offset(x: 4, y: 4)
            .accessibilityHidden(true)
    }

    // MARK: Pills

    private var status: SkillStatus { page.manifest.skillStatus ?? .notStarted }

    /// A skill or a tutorial that keeps its sub-skills: its done check, its status and its type picker.
    private var showsSkillChips: Bool { page.isSkillLike && !page.manifest.hidesSkills }

    private var showsProgress: Bool { !page.isExercise && !page.manifest.hidesSkills && progress.total > 0 }

    /// A page that needs no skills shows the type it wears without inviting one.
    private var showsTypeChip: Bool { showsSkillChips || (page.isSkillLike && store.skillType(of: page) != nil) }

    /// The status chips first, then the fact pills; together they wrap below the title.
    private var pills: some View {
        PageChipFlowLayout {
            if showsSkillChips {
                SkillDoneButton(title: page.title, status: status, pageID: page.manifest.id, onSet: onSetStatus)
                SkillStatusMenu(status: status, onChange: onSetStatus) {
                    SkillStatusChip(status)
                        .frame(minHeight: SkillMetrics.touch)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(SkillPressButtonStyle())
                .fixedSize()
            }
            if showsProgress {
                progressChip
            }
            if showsTypeChip {
                SkillTypePicker(pageID: page.manifest.id) {
                    if let type = store.skillType(of: page) {
                        SkillTypeChip(type: type, showsChevron: true)
                    } else {
                        SkillAddTypeChip()
                    }
                }
            }
            if let type = page.effectiveWorkoutType {
                pill(symbol: type.iconName, Text(type.name).font(labelFont).fontWeight(.semibold).foregroundColor(valueColor))
                    .accessibilityLabel("Workout type: \(type.name)")
            }
            ForEach(facts) { fact in
                pill(symbol: fact.symbol, text(of: fact))
                    .accessibilityLabel(fact.spoken)
            }
        }
    }

    private var progressChip: some View {
        HStack(spacing: 6) {
            SkillProgressRing(fraction: progress.fraction, lineWidth: 3)
                .frame(width: 16, height: 16)
            Text(progress.summary)
                .font(TimeMasterFont.caption())
                .foregroundStyle(onCover ? Color.white.opacity(0.85) : Theme.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(progress.completed) of \(progress.total) sub-skills done")
    }

    /// A fact or the workout type in its own quiet capsule.
    private func pill(symbol: String, _ text: Text) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(valueColor)
            text
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(onCover ? 0.16 : 0.07)))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .ignore)
    }

    // MARK: Facts

    private struct Fact: Identifiable {
        let id: String
        let symbol: String
        var value: String?
        var label = ""

        var spoken: String { [value ?? "", label].filter { !$0.isEmpty }.joined(separator: " ") }
    }

    /// What the page is, the workouts that train it and when, the pages in a container, the clips.
    private var facts: [Fact] {
        var facts = [Fact(id: "kind", symbol: PageKindStyle.symbol(page), value: PageKindStyle.title(page))]
        let workouts = usage.entries.count
        if workouts > 0 {
            facts.append(Fact(id: "workouts", symbol: "figure.strengthtraining.traditional", value: "\(workouts)", label: workouts == 1 ? "workout" : "workouts"))
            if let last = usage.lastTrained {
                facts.append(Fact(id: "trained", symbol: "clock.arrow.circlepath", label: PageWidgetFormat.trained(last)))
            }
        } else if page.isExercise {
            facts.append(Fact(id: "workouts", symbol: "figure.strengthtraining.traditional", label: "Not in a workout yet"))
        }
        let pages = page.manifest.childIDs.count
        if page.pageType == nil, pages > 0 {
            facts.append(Fact(id: "pages", symbol: "doc.on.doc", value: "\(pages)", label: pages == 1 ? "page" : "pages"))
        }
        let clips = page.mediaURLs.count
        if clips > 0 {
            facts.append(Fact(id: "clips", symbol: "play.rectangle", value: "\(clips)", label: clips == 1 ? "clip" : "clips"))
        }
        return facts
    }

    /// The number in black, the words in the caption face.
    private func text(of fact: Fact) -> Text {
        let words = Text(fact.label).font(labelFont).foregroundColor(labelColor)
        guard let value = fact.value else { return words }
        let number = Text(value).font(valueFont).foregroundColor(valueColor)
        return fact.label.isEmpty ? number : number + Text(" ").font(labelFont) + words
    }

    private var valueFont: Font { TimeMasterFont.black(12, relativeTo: .caption) }
    private var labelFont: Font { TimeMasterFont.caption() }
    private var valueColor: Color { onCover ? .white : Theme.textPrimary }
    private var labelColor: Color { onCover ? Color.white.opacity(0.78) : Theme.textSecondary }
}

/// A page title in Tmax's title face that renames where it stands: double-click it (Mac) or double-tap it (iPhone)
/// and type; Return or clicking away saves, Escape keeps the old name.
struct PageTitleField: View {
    @EnvironmentObject private var store: DatabaseStore

    let pageID: String
    let title: String
    let size: CGFloat
    var relativeTo: Font.TextStyle = .largeTitle
    var color: Color = Theme.textPrimary

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        if isEditing {
            field
        } else {
            label
        }
    }

    private var label: some View {
        TimeMasterPageTitle(title, size: size, relativeTo: relativeTo)
            .foregroundStyle(color)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: beginEditing)
            .help("Double-click to rename")
            .accessibilityAction(named: "Rename", beginEditing)
    }

    private var field: some View {
        TextField("Title", text: $draft)
            .textFieldStyle(.plain)
            .font(TimeMasterFont.pageTitle(size, relativeTo: relativeTo))
            .foregroundStyle(Theme.textPrimary)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit(commit)
            #if os(macOS)
            .onExitCommand { isEditing = false }
            #endif
            .padding(.horizontal, SkillMetrics.s2)
            .padding(.vertical, SkillMetrics.s1)
            .background(RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous).fill(Theme.surface2))
            .overlay(
                RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
                    .strokeBorder(Theme.toolbarOrange.opacity(0.9), lineWidth: 2)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: focused) { isFocused in
                if !isFocused, isEditing { commit() }
            }
            .task { focused = true }
            .accessibilityLabel("Title")
    }

    private func beginEditing() {
        draft = title
        isEditing = true
    }

    private func commit() {
        guard isEditing else { return }
        isEditing = false
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != title else { return }
        if SkillErrorCenter.shared.attempt("Rename", { try store.renameSkillPage(pageID, to: name) }) {
            EverHaptic.selection()
        }
    }
}
