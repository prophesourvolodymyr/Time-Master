import SwiftUI
import TimeMasterCore

/// The head of a library page, the same for every kind: the icon tile (a skill's or a tutorial's opens the icon
/// chooser and, without an icon of its own, shows its category as its Skills card does; other pages show what they
/// are), the title (double-click or double-tap renames it), the status row (a skill's done check and status, how many
/// sub-skills are done, the skill type, the workout type; a page that needs no skills keeps only a type it already
/// wears and the workout type) and a quiet line of numbers (what the page is, the workouts that train it and when, its
/// clips). `onCover` draws it in white over a cover picture; `compact` is the smaller head of a page shown without its
/// cover.
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
            if hasChips {
                chips
            }
            statsLine
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

    @ViewBuilder
    private var iconTile: some View {
        if page.isSkillLike {
            Button(action: onChangeIcon) {
                skillIcon
                    .overlay(alignment: .bottomTrailing) { pencilBadge }
            }
            .buttonStyle(SkillPressButtonStyle())
            .onHover { isHoveringIcon = $0 }
            .help("Change the icon")
            .accessibilityLabel("Change the icon")
            .accessibilityHint("Opens the icon chooser")
        } else {
            Image(systemName: PageKindStyle.symbol(page))
                .font(.system(size: iconSide * 0.42, weight: .semibold))
                .foregroundStyle(Theme.toolbarOrange)
                .frame(width: iconSide, height: iconSide)
                .skillTile(cornerRadius: iconSide * 0.32)
                .accessibilityHidden(true)
        }
    }

    /// A skill's own picture, symbol or emoji; without one, the symbol of its category on a tile, as its card on the
    /// Skills page shows it.
    @ViewBuilder
    private var skillIcon: some View {
        if page.iconImageURL == nil, (page.manifest.iconName ?? "").isEmpty {
            SkillCardIcon(page: page, category: SkillCategory.of(page, in: store.index), size: iconSide)
        } else {
            SkillPageIconTile(page: page, size: iconSide, tilesSymbols: true)
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

    // MARK: Status row

    private var status: SkillStatus { page.manifest.skillStatus ?? .notStarted }

    /// A skill or a tutorial that keeps its sub-skills: its done check, its status and its type picker.
    private var showsSkillChips: Bool { page.isSkillLike && !page.manifest.hidesSkills }

    private var showsProgress: Bool { !page.isExercise && !page.manifest.hidesSkills && progress.total > 0 }

    /// A page that needs no skills shows the type it wears without inviting one.
    private var showsTypeChip: Bool { showsSkillChips || (page.isSkillLike && store.skillType(of: page) != nil) }

    private var hasChips: Bool { showsSkillChips || showsProgress || showsTypeChip || page.effectiveWorkoutType != nil }

    private var chips: some View {
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
                workoutTypeChip(type)
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

    private func workoutTypeChip(_ type: TimeMasterCore.WorkoutType) -> some View {
        HStack(spacing: 5) {
            Image(systemName: type.iconName)
                .font(.system(size: 11, weight: .semibold))
            Text(type.name)
                .font(TimeMasterFont.caption())
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .foregroundStyle(onCover ? Color.white : Theme.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(onCover ? 0.16 : 0.07)))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Workout type: \(type.name)")
    }

    // MARK: Numbers

    private struct Stat {
        var value: String?
        var label: String
    }

    /// "Exercise · 3 workouts · Trained yesterday · 5 clips": plain text with no hit area, so it takes no taps.
    private var statsLine: some View {
        let stats = self.stats
        let line = stats.indices.reduce(Text("")) { partial, index in
            var next = index > 0 ? partial + Text("  ·  ").font(labelFont).foregroundColor(labelColor) : partial
            if let value = stats[index].value {
                next = next + Text(value).font(valueFont).foregroundColor(valueColor)
            }
            if !stats[index].label.isEmpty {
                next = next + Text(stats[index].label).font(labelFont).foregroundColor(labelColor)
            }
            return next
        }
        return line
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .allowsHitTesting(false)
            .accessibilityLabel(stats.map { ($0.value ?? "") + $0.label }.joined(separator: ", "))
    }

    private var stats: [Stat] {
        var stats = [Stat(value: PageKindStyle.title(page), label: "")]
        let workouts = usage.entries.count
        if workouts > 0 {
            stats.append(Stat(value: "\(workouts)", label: workouts == 1 ? " workout" : " workouts"))
            if let last = usage.lastTrained {
                stats.append(Stat(value: nil, label: PageWidgetFormat.trained(last)))
            }
        } else if page.isExercise {
            stats.append(Stat(value: nil, label: "Not in a workout yet"))
        }
        let pages = page.manifest.childIDs.count
        if page.pageType == nil, pages > 0 {
            stats.append(Stat(value: "\(pages)", label: pages == 1 ? " page" : " pages"))
        }
        let clips = page.mediaURLs.count
        if clips > 0 {
            stats.append(Stat(value: "\(clips)", label: clips == 1 ? " clip" : " clips"))
        }
        return stats
    }

    private var valueFont: Font { TimeMasterFont.black(13, relativeTo: .footnote) }
    private var labelFont: Font { TimeMasterFont.body(13, relativeTo: .footnote) }
    private var valueColor: Color { onCover ? .white : Theme.textPrimary }
    private var labelColor: Color { onCover ? Color.white.opacity(0.72) : Theme.textSecondary }
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
