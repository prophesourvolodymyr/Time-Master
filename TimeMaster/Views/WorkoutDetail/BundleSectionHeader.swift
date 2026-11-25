import SwiftUI

struct BundleSectionHeader: View {
    let section: Section
    let isExpanded: Bool
    var rail = BuilderRail()
    var slice: BuilderSlice = .top
    var progress: Double?
    let onToggle: () -> Void
    let onAddSet: () -> Void
    let onEdit: () -> Void
    let onOpenPage: (UUID) -> Void
    @Environment(\.workoutHeroSources) private var heroSources

    private var tone: BuilderTone { section.isCombo ? .combo : .light }

    private var summary: String {
        let seconds = section.calculatedDuration
        let time = "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
        let sets = section.bundleSets.count
        if section.isCombo {
            return "Combo · \(sets) \(sets == 1 ? "round" : "rounds") · \(time)"
        }
        return "\(sets) sets · \(section.isTimerEnabled ? time : "~\(time)")"
    }

    private enum StripEntry: Identifiable {
        case exercise(SetSlot)
        case rest(ownerID: UUID, pageIDs: [UUID], seconds: Int)

        var id: String {
            switch self {
            case .exercise(let slot): "exercise-\(slot.id)"
            case .rest(let ownerID, _, _): "rest-\(ownerID)"
            }
        }
    }

    private var stripEntries: [StripEntry] {
        let sets = section.bundleSets
        var entries: [StripEntry] = []
        for (setIndex, set) in sets.enumerated() {
            if set.children.isEmpty {
                entries.append(.exercise(set))
            } else {
                for (childIndex, child) in set.children.enumerated() {
                    entries.append(contentsOf: child.leafExercises.map { StripEntry.exercise($0) })
                    if childIndex < set.children.count - 1, !child.restExercisePageIDs.isEmpty {
                        entries.append(.rest(ownerID: child.id, pageIDs: child.restExercisePageIDs, seconds: child.playbackRest))
                    }
                }
            }
            if setIndex < sets.count - 1, !set.restExercisePageIDs.isEmpty {
                entries.append(.rest(ownerID: set.id, pageIDs: set.restExercisePageIDs, seconds: set.playbackRest))
            }
        }
        return entries
    }

    private func comboTile(_ slot: SetSlot) -> some View {
        VStack(spacing: 5) {
            ComboCallChip(tokens: ComboCall.tokens(in: slot.displayName))
            Text(section.isTimerEnabled ? "\(slot.duration) s" : "until done")
                .font(TimeMasterFont.caption().monospacedDigit())
                .opacity(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ComboCall.spoken(slot.displayName)), \(slot.duration) seconds")
    }

    private func exerciseTile(_ slot: SetSlot) -> some View {
        let key = "bundle-strip-\(slot.id)"
        return Button {
            guard let id = slot.exercisePageID else { return }
            heroSources?.markTapped(key)
            onOpenPage(id)
        } label: {
            VStack(spacing: 5) {
                BundleExerciseThumbnail(slot: slot, size: 52)
                    .workoutHeroSource(key)
                Text(slot.displayName)
                    .font(TimeMasterFont.body(11, relativeTo: .caption2))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 60)
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 10))
        .disabled(slot.exercisePageID == nil)
        .accessibilityLabel(section.isTimerEnabled ? "\(slot.displayName), \(slot.duration) seconds" : "\(slot.displayName), until done")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 0) {
                BuilderHandle(tone: tone)
                Group {
                    if section.isCombo {
                        ComboIconGlyph(iconName: section.iconName, iconType: section.iconType, size: 21)
                    } else {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                    .accessibilityHidden(true)
                    .frame(width: BuilderMetrics.root, height: BuilderMetrics.root)
                    .background(
                        RoundedRectangle(cornerRadius: BuilderMetrics.thumbnailRadius(BuilderMetrics.root), style: .continuous)
                            .fill(section.isCombo ? Color.white.opacity(0.22) : Color.black.opacity(0.07))
                    )
                    .overlay {
                        if let progress {
                            BuilderProgressRing(
                                progress: progress,
                                cornerRadius: BuilderMetrics.thumbnailRadius(BuilderMetrics.root)
                            )
                        }
                    }
                    .padding(.leading, BuilderMetrics.handleGap)
                Button(action: onToggle) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.name)
                            .font(TimeMasterFont.black(17, relativeTo: .headline))
                            .lineLimit(1)
                        Text(summary)
                            .font(TimeMasterFont.caption().monospacedDigit())
                            .opacity(0.6)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: BuilderMetrics.root, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, BuilderMetrics.rootGap)
                .accessibilityLabel("\(section.name), \(summary)")
                .accessibilityHint(isExpanded ? "Collapses the bundle" : "Expands the bundle")
                BuilderCluster {
                    Button(action: onAddSet) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(BuilderChipButtonStyle(tone: tone))
                    .accessibilityLabel("Add set to \(section.name)")
                } middle: {
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(BuilderChipButtonStyle(tone: tone))
                    .accessibilityLabel("Edit bundle")
                } last: {
                    BuilderDisclosureChip(
                        isExpanded: isExpanded,
                        tone: tone,
                        expandLabel: "Expand bundle",
                        collapseLabel: "Collapse bundle",
                        action: onToggle
                    )
                }
                .frame(height: BuilderMetrics.root)
                .padding(.leading, 8)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(stripEntries) { entry in
                        switch entry {
                        case .exercise(let slot):
                            if section.isCombo { comboTile(slot) } else { exerciseTile(slot) }
                        case .rest(let ownerID, let pageIDs, let seconds):
                            BundleRestChip(ownerID: ownerID, pageIDs: pageIDs, seconds: seconds, onOpenPage: onOpenPage)
                        }
                    }
                }
            }
            .padding(.leading, BuilderMetrics.textX(1))
        }
        .foregroundStyle(section.isCombo ? Color.white : Color.black)
        .modifier(BuilderRowChrome(rail: rail, slice: slice, tone: tone, vertical: BuilderMetrics.headerVertical))
    }
}

private struct BundleRestChip: View {
    @EnvironmentObject private var databaseStore: DatabaseStore
    @Environment(\.workoutHeroSources) private var heroSources

    let ownerID: UUID
    let pageIDs: [UUID]
    let seconds: Int
    let onOpenPage: (UUID) -> Void

    private var title: String {
        pageIDs.first.flatMap { databaseStore.page(id: $0)?.title } ?? "Rest exercise"
    }

    private var accessibilityText: String {
        var text = "Rest, \(seconds) seconds: \(title)"
        let more = pageIDs.count - 1
        if more > 0 { text += ", \(more) more \(more == 1 ? "choice" : "choices")" }
        return text
    }

    var body: some View {
        let key = "bundle-strip-rest-\(ownerID)"
        Button {
            guard let id = pageIDs.first else { return }
            heroSources?.markTapped(key)
            onOpenPage(id)
        } label: {
            VStack(spacing: 4) {
                BundlePageThumbnail(pageID: pageIDs.first, size: 44, fallbackIcon: "figure.cooldown")
                    .workoutHeroSource(key)
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Theme.toolbarOrange))
                            .offset(x: -3, y: 3)
                    }
                    .overlay(alignment: .topTrailing) {
                        if pageIDs.count > 1 {
                            Text("+\(pageIDs.count - 1)")
                                .font(TimeMasterFont.black(9, relativeTo: .caption2))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .frame(minWidth: 16, minHeight: 14)
                                .background(Capsule().fill(Color.black.opacity(0.75)))
                                .offset(x: 4, y: -4)
                        }
                    }
                Text("\(seconds) s")
                    .font(TimeMasterFont.black(10, relativeTo: .caption2).monospacedDigit())
                    .lineLimit(1)
                Text(title)
                    .font(TimeMasterFont.body(10, relativeTo: .caption2))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .opacity(0.65)
            .frame(width: 52)
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 10))
        .disabled(pageIDs.isEmpty)
        .accessibilityLabel(accessibilityText)
    }
}
