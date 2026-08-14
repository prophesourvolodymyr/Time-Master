import SwiftUI
import UniformTypeIdentifiers

struct WorkoutDetailView: View {
    @EnvironmentObject var store: WorkoutStore
    @EnvironmentObject var databaseStore: DatabaseStore
    @State private var showingDeleteAlert = false
    @State private var sectionToDelete: Section?
    @State private var showPlayer = false
    @State private var showingWorkoutSettings = false
    @State private var mediaPreviewSection: Section? = nil
    @State private var inspectedPageID: UUID?
    @State private var durationEdit: DurationEditTarget?
    @State private var expandedRestRowIDs: Set<UUID> = []
    @State private var noteEditTarget: RestNoteTarget?
    @State private var showBrowserSheet = false

    let workoutID: UUID
    @State private var sectionIDs: [UUID] = []

    @State private var pendingSection: PendingSectionConfig?
    @State private var expandedSectionIDs: Set<UUID> = []
    @State private var draggedSlotID: UUID?
    @State private var browserTarget: BuilderBrowserTarget = .newSection

    private var workout: Workout {
        store.workouts.first(where: { $0.id == workoutID }) ?? Workout(name: "")
    }

    init(workout: Workout) {
        workoutID = workout.id
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if workout.sections.isEmpty && pendingSection == nil {
                emptySectionsView
            } else {
                VStack(spacing: 0) {
                    sectionList
                    startButton
                }
            }
        }
        .navigationTitle(workout.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .onAppear { sectionIDs = workout.sections.map(\.id) }
        .onChange(of: workout.sections.count) { _ in sectionIDs = workout.sections.map(\.id) }
        .sheet(isPresented: $showPlayer) {
            WorkoutPlayerView(workout: workout)
                .environmentObject(store)
                .environmentObject(DatabaseStore.shared)
        }
        .toolbar { toolbarItems }
        .alert("Delete Section", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { sectionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let section = sectionToDelete {
                    store.deleteSection(in: workout, section: section)
                    sectionIDs = workout.sections.map(\.id)
                }
                sectionToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this section?")
        }
        .sheet(item: $mediaPreviewSection) { section in
            MediaPreviewSheet(items: section.mediaItems)
        }
        .sheet(
            isPresented: Binding(
                get: { inspectedPageID != nil },
                set: { if !$0 { inspectedPageID = nil } }
            )
        ) {
            if let pageID = inspectedPageID {
                WorkoutPageInspector(pageID: pageID)
                    .environmentObject(databaseStore)
                    .environmentObject(store)
            }
        }
        .sheet(item: $durationEdit) { target in
            DurationEditorSheet(
                title: target.title,
                seconds: target.seconds,
                onSave: { seconds in
                    updateDuration(target, seconds: seconds)
                }
            )
        }
        .sheet(item: $noteEditTarget) { target in
            RestNoteEditorSheet(
                initialText: target.text,
                onSave: { text in
                    updateRestContent(target, content: RestContent(
                        id: target.contentID ?? UUID(),
                        kind: .note,
                        text: text
                    ))
                }
            )
        }
        .sheet(isPresented: $showingWorkoutSettings) {
            WorkoutSettingsView(workoutID: workoutID, store: store)
        }
        .sheet(isPresented: $showBrowserSheet) {
            DatabasePageBrowserSheet(
                workout: workout,
                onAdd: { page, dur, sets, reps, restAfter, restBetween in
                    handlePageSelection(
                        page,
                        duration: dur,
                        sets: sets,
                        reps: reps,
                        restAfter: restAfter,
                        restBetween: restBetween
                    )
                },
                onAddBundle: { pages, dur, sets, reps, restAfter, restBetween in
                    guard case .newSection = browserTarget else { return }
                    let bundleName = pages.first?.title ?? "Bundle"
                    let subNames = pages.map { $0.title }
                    let totalSets = pages.reduce(sets) { acc, page in
                        acc + (page.manifest.sets ?? 1)
                    }
                    pendingSection = PendingSectionConfig(
                        name: "Bundle: \(bundleName) (\(subNames.joined(separator: ", ")))",
                        pageID: pages.first?.id,
                        duration: dur,
                        sets: totalSets,
                        repCount: reps > 0 ? reps : nil,
                        restAfter: restAfter,
                        restBetweenSets: restBetween,
                        mode: .bundle,
                        slots: pages.map {
                            SetSlot(
                                exercisePageID: $0.id,
                                name: $0.title,
                                duration: $0.manifest.duration ?? dur,
                                repCount: $0.manifest.sets != nil ? max(1, reps) : nil,
                                restAfter: restAfter
                            )
                        }
                    )
                }
            )
            .environmentObject(databaseStore)
            .environmentObject(store)
        }
    }

    // MARK: - Sub-views

    private var emptySectionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(Theme.textSecondary)
            Text("No Sections Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
            Text("Exercises define the structure of your workout.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                browserTarget = .newSection
                databaseStore.reloadImmediately()
                showBrowserSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add First Exercise")
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
            }
            .padding(.top, 8)
            Button {
                browserTarget = .newSection
                databaseStore.reloadImmediately()
                showBrowserSheet = true
            } label: {
                HStack {
                    Image(systemName: "folder.fill.badge.plus")
                    Text("Browse Exercises")
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
        }
    }

    private var sectionList: some View {
        List {
            if let pending = pendingSection {
                pendingConfigCard(pending)
                    .listRowBackground(Theme.surface)
                    .listRowSeparatorTint(Theme.separator)
            }

            ForEach(sectionIDs, id: \.self) { id in
                if let section = workout.sections.first(where: { $0.id == id }) {
                    sectionCell(section, id: id)
                        .listRowBackground(Theme.surface)
                        .listRowSeparatorTint(Theme.separator)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                sectionToDelete = section
                                showingDeleteAlert = true
                            } label: { Label("Delete", systemImage: "trash") }
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                if expandedSectionIDs.contains(section.id) {
                                    expandedSectionIDs.remove(section.id)
                                } else {
                                    expandedSectionIDs.insert(section.id)
                                }
                            } label: {
                                Label(
                                    expandedSectionIDs.contains(section.id) ? "Collapse" : "Edit",
                                    systemImage: expandedSectionIDs.contains(section.id) ? "chevron.up" : "pencil"
                                )
                            }
                            .tint(Color.white.opacity(0.3))
                        }
                }
            }
            .onMove(perform: moveSections)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func pendingConfigCard(_ pending: PendingSectionConfig) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(Theme.textSecondary)
                Text("Configure New Section")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            Text(pending.name)
                .font(.callout.weight(.medium))
                .foregroundColor(.white)
                .lineLimit(2)

            HStack(spacing: 6) {
                inlineStepper(label: "Dur", value: Binding(
                    get: { pending.duration },
                    set: { pendingSection?.duration = $0 }
                ), range: 5...600, step: 5, unit: "s")
                inlineStepper(label: "Sets", value: Binding(
                    get: { pending.sets },
                    set: { pendingSection?.sets = $0 }
                ), range: 1...50, step: 1, unit: "")
                inlineStepper(label: "Reps", value: Binding(
                    get: { pending.repCount ?? 0 },
                    set: { pendingSection?.repCount = ($0 > 0 ? $0 : nil) }
                ), range: 0...100, step: 1, unit: "")
                inlineStepper(label: "Rest", value: Binding(
                    get: { pending.restAfter },
                    set: { pendingSection?.restAfter = $0 }
                ), range: 0...120, step: 5, unit: "s")
                inlineStepper(label: "Btwn", value: Binding(
                    get: { pending.restBetweenSets },
                    set: { pendingSection?.restBetweenSets = $0 }
                ), range: 0...120, step: 5, unit: "s")
            }

            HStack(spacing: 10) {
                Button {
                    pendingSection = nil
                } label: {
                    Text("Cancel")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }

                Button {
                    confirmPendingSection(pending)
                } label: {
                    Text("Confirm")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(Theme.surface2.opacity(0.6))
        .cornerRadius(12)
        .padding(.vertical, 6)
    }

    private func inlineStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(Theme.textSecondary)
            if unit == "s" {
                DurationPickerView(
                    seconds: value,
                    range: range,
                    step: step,
                    compact: true
                )
                .frame(maxWidth: .infinity)
            } else {
                Text("\(value.wrappedValue)\(unit)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 3) {
                    Button {
                        let new = value.wrappedValue - step
                        if new >= range.lowerBound { value.wrappedValue = new }
                    } label: {
                        Image(systemName: "minus").font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white).frame(width: 16, height: 16)
                            .background(Theme.surface).cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Decrease \(label)")
                    Button {
                        let new = value.wrappedValue + step
                        if new <= range.upperBound { value.wrappedValue = new }
                    } label: {
                        Image(systemName: "plus").font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white).frame(width: 16, height: 16)
                            .background(Theme.surface).cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Increase \(label)")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Theme.surface)
        .cornerRadius(6)
    }

    private func confirmPendingSection(_ pending: PendingSectionConfig) {
        let section = Section(
            name: pending.name,
            duration: pending.duration,
            sets: pending.sets,
            repCount: pending.repCount,
            restBetweenSets: pending.restBetweenSets,
            customRestAfter: pending.restAfter,
            prepareTime: 4,
            pageID: pending.pageID,
            mode: pending.mode,
            slots: pending.slots.isEmpty ? [
                SetSlot(
                    exercisePageID: pending.pageID,
                    name: pending.name,
                    duration: pending.duration,
                    repCount: pending.repCount,
                    restAfter: pending.restBetweenSets
                )
            ] : pending.slots
        )
        store.addSection(to: workout, section: section)
        sectionIDs = workout.sections.map(\.id)
        pendingSection = nil
    }

    private func sectionCell(_ section: Section, id: UUID) -> some View {
        let isExpanded = expandedSectionIDs.contains(section.id)
        let bigRest = section.bigRestRow ?? RestRow(
            id: section.id,
            kind: .big,
            duration: section.customRestAfter ?? workout.restBetweenSections
        )

        return VStack(spacing: 6) {
            sectionHeader(section, isExpanded: isExpanded)

            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(Array(section.effectiveSlots.enumerated()), id: \.element.id) { slotIndex, slot in
                        slotRows(section: section, slot: slot, index: slotIndex)
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            restRowView(
                bigRest,
                target: RestTarget(sectionID: section.id, slotID: nil, isBig: true)
            )
        }
        .padding(.vertical, 4)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isExpanded)
    }

    private func sectionHeader(_ section: Section, isExpanded: Bool) -> some View {
        HStack(spacing: 10) {
            pageThumbnailButton(
                pageID: section.pageID,
                size: 42,
                fallbackIcon: section.mode == .bundle ? "rectangle.stack.fill" : "figure.run"
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(section.slotCount)×")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundColor(Theme.textPrimary)
                    Text(formatCompactDuration(section.effectiveSlots.first?.duration ?? section.duration))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundColor(Theme.textPrimary)
                    Text(section.name)
                        .font(.headline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let reps = section.repCount {
                        Text("\(reps) reps")
                    }
                    Text(section.mode == .bundle ? "Bundle" : "Timed")
                    Text(formatCompactDuration(section.calculatedDuration))
                }
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { toggleSection(section.id) }

            Spacer(minLength: 4)

            Button {
                toggleSection(section.id)
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse \(section.name)" : "Expand \(section.name)")
        }
        .padding(10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toggleSection(_ id: UUID) {
        if expandedSectionIDs.contains(id) {
            expandedSectionIDs.remove(id)
        } else {
            expandedSectionIDs.insert(id)
        }
    }

    private func slotRows(section: Section, slot: SetSlot, index: Int) -> some View {
        VStack(spacing: 4) {
            setRow(section: section, slot: slot, index: index)
                .onDrag {
                    draggedSlotID = slot.id
                    return NSItemProvider(object: slot.id.uuidString as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: SlotDropDelegate(
                        sourceID: draggedSlotID,
                        targetID: slot.id,
                        move: { source, target in
                            moveSlot(in: section.id, sourceID: source, before: target)
                        }
                    )
                )

            ForEach(slot.drops) { drop in
                dropRow(section: section, slot: slot, drop: drop)
                restRowView(
                    RestRow(id: drop.id, kind: .normal, duration: drop.restAfter),
                    target: RestTarget(
                        sectionID: section.id,
                        slotID: slot.id,
                        dropID: drop.id,
                        isBig: false
                    )
                )
            }

            let rest = slot.restRow ?? RestRow(
                id: slot.id,
                kind: .normal,
                duration: slot.restAfter
            )
            restRowView(
                rest,
                target: RestTarget(sectionID: section.id, slotID: slot.id, isBig: false)
            )
        }
    }

    private func setRow(section: Section, slot: SetSlot, index: Int) -> some View {
        HStack(spacing: 8) {
            pageThumbnailButton(
                pageID: slot.exercisePageID,
                size: 34,
                fallbackIcon: "figure.run"
            )

            VStack(alignment: .leading, spacing: 1) {
                Button {
                    inspectedPageID = slot.exercisePageID
                } label: {
                    Text(slot.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Text("Set \(index + 1)")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer(minLength: 4)

            durationButton(
                text: formatCompactDuration(slot.duration),
                title: "Set \(index + 1) duration",
                seconds: slot.duration
            ) {
                durationEdit = DurationEditTarget(
                    title: "Set \(index + 1) duration",
                    seconds: slot.duration,
                    kind: .slot(section.id, slot.id)
                )
            }

            Button {
                openBrowser(.addDrop(section.id, slot.id))
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(Theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add drop set to \(slot.displayName)")
        }
        .padding(8)
        .background(Theme.surface2.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func dropRow(section: Section, slot: SetSlot, drop: DropSet) -> some View {
        HStack(spacing: 8) {
            pageThumbnailButton(
                pageID: drop.exercisePageID,
                size: 28,
                fallbackIcon: "arrow.down.right"
            )

            Text(drop.displayName)
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

            durationButton(
                text: formatCompactDuration(drop.duration),
                title: "\(drop.displayName) duration",
                seconds: drop.duration
            ) {
                durationEdit = DurationEditTarget(
                    title: "\(drop.displayName) duration",
                    seconds: drop.duration,
                    kind: .drop(section.id, slot.id, drop.id)
                )
            }

            Button(role: .destructive) {
                mutateSection(id: section.id) { updated in
                    var slots = updated.effectiveSlots
                    guard let slotIndex = slots.firstIndex(where: { $0.id == slot.id }) else { return }
                    slots[slotIndex].drops.removeAll { $0.id == drop.id }
                    updated.slots = slots
                }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(drop.displayName)")
        }
        .padding(.leading, 18)
        .padding(.vertical, 5)
        .padding(.trailing, 8)
        .background(Theme.surface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func durationButton(
        text: String,
        title: String,
        seconds: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Theme.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(formatCompactDuration(seconds))
    }

    private func pageThumbnailButton(pageID: UUID?, size: CGFloat, fallbackIcon: String) -> some View {
        Button {
            inspectedPageID = pageID
        } label: {
            pageThumbnail(pageID: pageID, size: size, fallbackIcon: fallbackIcon)
        }
        .buttonStyle(.plain)
        .disabled(pageID == nil)
        .accessibilityLabel(pageID == nil ? "No page preview" : "Open page preview")
    }

    private func pageThumbnail(pageID: UUID?, size: CGFloat, fallbackIcon: String) -> some View {
        let page = pageID.flatMap { databaseStore.page(id: $0) }
        return AsyncCoverImage(
            url: page?.coverImageURL,
            fallbackIcon: page?.manifest.iconName ?? fallbackIcon,
            fallbackColor: page?.effectiveWorkoutType.map { Color(hex: $0.colorHex) },
            height: size,
            contentMode: .fill,
            overlayGradient: false
        )
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: min(9, size / 4)))
    }

    private func restRowView(_ row: RestRow, target: RestTarget) -> some View {
        let isExpanded = expandedRestRowIDs.contains(row.id)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: row.kind == .big ? "square.stack.3d.up.fill" : "pause.fill")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Text(row.kind == .big ? "BIG REST" : "REST")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)

                durationButton(
                    text: formatCompactDuration(row.duration),
                    title: row.kind == .big ? "Big rest duration" : "Rest duration",
                    seconds: row.duration
                ) {
                    durationEdit = DurationEditTarget(
                        title: row.kind == .big ? "Big rest duration" : "Rest duration",
                        seconds: row.duration,
                        kind: .rest(target)
                    )
                }

                Spacer(minLength: 4)

                restActionMenu(target: target)

                Button {
                    if expandedRestRowIDs.contains(row.id) {
                        expandedRestRowIDs.remove(row.id)
                    } else {
                        expandedRestRowIDs.insert(row.id)
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse rest contents" : "Expand rest contents")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if isExpanded {
                VStack(spacing: 3) {
                    if row.contents.isEmpty {
                        Text("Add a note or stretch")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 34)
                            .padding(.bottom, 5)
                    } else {
                        ForEach(row.contents) { content in
                            restContentRow(content, target: target)
                        }
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .background(row.kind == .big ? Theme.surface2.opacity(0.9) : Theme.surface2.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: row.kind == .big ? 11 : 8))
    }

    private func restActionMenu(target: RestTarget) -> some View {
        Menu {
            Button("Add Note", systemImage: "note.text") {
                noteEditTarget = RestNoteTarget(target: target, contentID: nil, text: "")
            }
            Button("Add Stretch", systemImage: "figure.cooldown") {
                openBrowser(.restStretch(target))
            }
        } label: {
            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 26, height: 26)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Add rest content")
    }

    private func restContentRow(_ content: RestContent, target: RestTarget) -> some View {
        HStack(spacing: 7) {
            pageThumbnailButton(
                pageID: content.pageID,
                size: 24,
                fallbackIcon: content.kind == .stretch ? "figure.cooldown" : "note.text"
            )

            Text(content.text.isEmpty ? (content.kind == .stretch ? "Stretch" : "Note") : content.text)
                .font(.caption)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            Spacer()

            if content.kind == .note {
                Button {
                    noteEditTarget = RestNoteTarget(target: target, contentID: content.id, text: content.text)
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                removeRestContent(target, contentID: content.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 30)
        .padding(.trailing, 10)
        .padding(.vertical, 3)
    }


    @ViewBuilder
    private var startButton: some View {
        if !workout.sections.isEmpty {
            Button { showPlayer = true } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(16)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showingWorkoutSettings = true } label: {
                    Label("Workout Settings", systemImage: "slider.horizontal.3")
                }
                Button { store.cloneWorkout(workout) } label: {
                    Label("Clone Workout", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) { store.deleteWorkout(workout) } label: {
                    Label("Delete Workout", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.white)
            }
            .accessibilityLabel("Workout actions")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                browserTarget = .newSection
                databaseStore.reloadImmediately()
                showBrowserSheet = true
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(.white)
            }
            .accessibilityLabel("Add exercise")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                browserTarget = .newSection
                databaseStore.reloadImmediately()
                showBrowserSheet = true
            } label: {
                Image(systemName: "folder.fill.badge.plus")
                    .foregroundColor(.white)
            }
            .accessibilityLabel("Browse exercises")
        }
    }

    // MARK: - Helpers

    private func moveSections(from source: IndexSet, to destination: Int) {
        sectionIDs.move(fromOffsets: source, toOffset: destination)
        var w = workout
        w.sections = sectionIDs.compactMap { id in w.sections.first(where: { $0.id == id }) }
        store.updateWorkout(w)
    }

    private func handlePageSelection(
        _ page: ExercisePage,
        duration: Int,
        sets: Int,
        reps: Int,
        restAfter: Int,
        restBetween: Int
    ) {
        switch browserTarget {
        case .newSection:
            pendingSection = PendingSectionConfig(
                name: page.title,
                pageID: page.id,
                duration: duration,
                sets: sets,
                repCount: reps > 0 ? reps : nil,
                restAfter: restAfter,
                restBetweenSets: restBetween
            )
        case .addDrop(let sectionID, let slotID):
            mutateSection(id: sectionID) { section in
                var slots = section.effectiveSlots
                guard let slotIndex = slots.firstIndex(where: { $0.id == slotID }),
                      page.id != section.pageID,
                      !slots[slotIndex].drops.contains(where: { $0.exercisePageID == page.id }) else { return }
                slots[slotIndex].drops.append(
                    DropSet(
                        exercisePageID: page.id,
                        name: page.title,
                        duration: duration,
                        restAfter: restAfter
                    )
                )
                section.slots = slots
            }
        case .setRestExercise(let sectionID, let slotID):
            mutateSection(id: sectionID) { section in
                var slots = section.effectiveSlots
                if let index = slots.firstIndex(where: { $0.id == slotID }) {
                    slots[index].restExercisePageID = page.id
                    section.slots = slots
                }
            }
        case .restStretch(let target):
            mutateRestRow(target) { row in
                row.contents.append(
                    RestContent(
                        kind: .stretch,
                        pageID: page.id,
                        text: page.title
                    )
                )
            }
        }
        showBrowserSheet = false
    }

    private func mutateSection(id: UUID, _ mutate: (inout Section) -> Void) {
        var updatedWorkout = workout
        guard let index = updatedWorkout.sections.firstIndex(where: { $0.id == id }) else { return }
        mutate(&updatedWorkout.sections[index])
        store.updateWorkout(updatedWorkout)
        sectionIDs = updatedWorkout.sections.map(\.id)
    }

    private func moveSlot(in sectionID: UUID, from source: Int, to destination: Int) {
        mutateSection(id: sectionID) { section in
            guard source != destination else { return }
            var slots = section.effectiveSlots
            guard slots.indices.contains(source), slots.indices.contains(destination) else { return }
            let slot = slots.remove(at: source)
            slots.insert(slot, at: destination)
            section.slots = slots
            section.sets = slots.count
        }
    }

    private func removeSlot(in sectionID: UUID, at index: Int) {
        mutateSection(id: sectionID) { section in
            var slots = section.effectiveSlots
            guard slots.count > 1, slots.indices.contains(index) else { return }
            slots.remove(at: index)
            section.slots = slots
            section.sets = slots.count
        }
    }

    private func moveSlot(in sectionID: UUID, sourceID: UUID?, before targetID: UUID) {
        guard let sourceID, sourceID != targetID else { return }
        mutateSection(id: sectionID) { section in
            var slots = section.effectiveSlots
            guard let sourceIndex = slots.firstIndex(where: { $0.id == sourceID }) else { return }
            let movedSlot = slots.remove(at: sourceIndex)
            let targetIndex = slots.firstIndex(where: { $0.id == targetID }) ?? slots.endIndex
            slots.insert(movedSlot, at: targetIndex)
            section.slots = slots
            section.sets = slots.count
        }
        draggedSlotID = nil
    }


    private func openBrowser(_ target: BuilderBrowserTarget) {
        browserTarget = target
        databaseStore.reloadImmediately()
        showBrowserSheet = true
    }

    private func formatCompactDuration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainder = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    private func updateDuration(_ target: DurationEditTarget, seconds: Int) {
        switch target.kind {
        case .slot(let sectionID, let slotID):
            mutateSection(id: sectionID) { section in
                var slots = section.effectiveSlots
                guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
                slots[index].duration = max(5, seconds)
                section.slots = slots
            }
        case .drop(let sectionID, let slotID, let dropID):
            mutateSection(id: sectionID) { section in
                var slots = section.effectiveSlots
                guard let slotIndex = slots.firstIndex(where: { $0.id == slotID }),
                      let dropIndex = slots[slotIndex].drops.firstIndex(where: { $0.id == dropID }) else { return }
                slots[slotIndex].drops[dropIndex].duration = max(5, seconds)
                section.slots = slots
            }
        case .rest(let restTarget):
            mutateRestRow(restTarget) { row in
                row.duration = max(0, seconds)
            }
        }
    }

    private func mutateRestRow(_ target: RestTarget, _ mutate: (inout RestRow) -> Void) {
        mutateSection(id: target.sectionID) { section in
            if target.isBig {
                var row = section.bigRestRow ?? RestRow(
                    id: section.id,
                    kind: .big,
                    duration: section.customRestAfter ?? workout.restBetweenSections
                )
                mutate(&row)
                section.bigRestRow = row
                section.customRestAfter = row.duration
                return
            }

            var slots = section.effectiveSlots
            guard let slotID = target.slotID,
                  let slotIndex = slots.firstIndex(where: { $0.id == slotID }) else { return }

            if let dropID = target.dropID,
               let dropIndex = slots[slotIndex].drops.firstIndex(where: { $0.id == dropID }) {
                let drop = slots[slotIndex].drops[dropIndex]
                var row = RestRow(id: drop.id, kind: .normal, duration: drop.restAfter)
                mutate(&row)
                slots[slotIndex].drops[dropIndex].restAfter = row.duration
            } else {
                var row = slots[slotIndex].restRow ?? RestRow(
                    id: slots[slotIndex].id,
                    kind: .normal,
                    duration: slots[slotIndex].restAfter
                )
                mutate(&row)
                slots[slotIndex].restRow = row
                slots[slotIndex].restAfter = row.duration
            }
            section.slots = slots
        }
    }

    private func updateRestContent(_ target: RestNoteTarget, content: RestContent) {
        mutateRestRow(target.target) { row in
            if let index = row.contents.firstIndex(where: { $0.id == content.id }) {
                row.contents[index] = content
            } else {
                row.contents.append(content)
            }
        }
    }

    private func removeRestContent(_ target: RestTarget, contentID: UUID) {
        mutateRestRow(target) { row in
            row.contents.removeAll { $0.id == contentID }
        }
    }

}

struct PendingSectionConfig {
    var name: String
    var pageID: UUID?
    var duration: Int
    var sets: Int
    var repCount: Int?
    var restAfter: Int
    var restBetweenSets: Int
    var mode: SectionMode = .timed
    var slots: [SetSlot] = []
}

private enum BuilderBrowserTarget {
    case newSection
    case addDrop(UUID, UUID)
    case setRestExercise(UUID, UUID)
    case restStretch(RestTarget)
}

private struct RestTarget {
    let sectionID: UUID
    let slotID: UUID?
    let dropID: UUID?
    let isBig: Bool

    init(sectionID: UUID, slotID: UUID?, dropID: UUID? = nil, isBig: Bool) {
        self.sectionID = sectionID
        self.slotID = slotID
        self.dropID = dropID
        self.isBig = isBig
    }
}

private enum DurationEditKind {
    case slot(UUID, UUID)
    case drop(UUID, UUID, UUID)
    case rest(RestTarget)
}

private struct DurationEditTarget: Identifiable {
    let id = UUID()
    let title: String
    let seconds: Int
    let kind: DurationEditKind
}

private struct RestNoteTarget: Identifiable {
    let id = UUID()
    let target: RestTarget
    let contentID: UUID?
    let text: String
}

private struct WorkoutPageInspector: View {
    let pageID: UUID

    var body: some View {
        NavigationStack {
            ExercisePageDetailView(pageID: pageID)
        }
    }
}

private struct DurationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let initialSeconds: Int
    let onSave: (Int) -> Void
    @State private var seconds: Int

    init(title: String, seconds: Int, onSave: @escaping (Int) -> Void) {
        self.title = title
        self.initialSeconds = seconds
        self.onSave = onSave
        _seconds = State(initialValue: seconds)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DurationPickerView(seconds: $seconds, range: 5...3600, step: 5)
                Text("Changes apply to this row only.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(seconds)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RestNoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let initialText: String
    let onSave: (String) -> Void
    @State private var text: String

    init(initialText: String, onSave: @escaping (String) -> Void) {
        self.initialText = initialText
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Write a short cue for this rest interval.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Rest Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RestSeparatorRow: View {
    @Binding var rest: Int
    let defaultRest: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pause.circle")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
            Text("Rest")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Button {
                if rest >= 5 { rest -= 5 }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(rest > 0 ? .white : Color.white.opacity(0.2))
            }
            .disabled(rest <= 0)
            .buttonStyle(.plain)
            Text("\(rest)s")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundColor(rest == defaultRest ? Theme.textSecondary : .white)
                .frame(minWidth: 32)
            Button {
                if rest < 300 { rest += 5 }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(rest < 300 ? .white : Color.white.opacity(0.2))
            }
            .disabled(rest >= 300)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.surface2.opacity(0.6))
    }
}

private struct SlotDropDelegate: DropDelegate {
    let sourceID: UUID?
    let targetID: UUID
    let move: (UUID?, UUID) -> Void

    func dropEntered(info: DropInfo) {
        move(sourceID, targetID)
    }

    func performDrop(info: DropInfo) -> Bool { true }
}

// MARK: - WorkoutSettingsView

private struct WorkoutSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: WorkoutStore
    @ObservedObject var musicManager = MusicManager.shared

    let workoutID: UUID

    @State private var restBetweenSections: Int
    @State private var colorHex: String
    @State private var selectedTrackIndices: Set<Int>
    @State private var useGlobalLibrary: Bool

    init(workoutID: UUID, store: WorkoutStore) {
        self.workoutID = workoutID
        let w = store.workouts.first(where: { $0.id == workoutID }) ?? Workout(name: "")
        _restBetweenSections = State(initialValue: w.restBetweenSections)
        _colorHex = State(initialValue: w.colorHex)
        _selectedTrackIndices = State(initialValue: {
            var set = Set<Int>()
            for filename in w.musicTrackFilenames {
                if let idx = MusicManager.shared.trackFilenames.firstIndex(of: filename) {
                    set.insert(idx)
                }
            }
            return set
        }())
        _useGlobalLibrary = State(initialValue: w.musicTrackFilenames.isEmpty)
    }

    private var workout: Workout {
        store.workouts.first(where: { $0.id == workoutID }) ?? Workout(name: "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        restSection
                        colorSection
                        musicSection
                        infoSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Workout Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSettings() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var restSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rest Between Sections")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            HStack {
                Text("\(restBetweenSections)s")
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Stepper("", value: $restBetweenSections, in: 0...300, step: 5).labelsHidden()
            }
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(12)
            Text("Default rest applied between sections unless overridden per-section.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icon Color")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            IconColorPicker(selectedHex: $colorHex)
        }
    }

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Music")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            if musicManager.trackFilenames.isEmpty {
                Text("No music tracks added. Add tracks in Settings → Background Music.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else {
                Toggle("Use entire music library", isOn: Binding(
                    get: { useGlobalLibrary },
                    set: { newValue in
                        useGlobalLibrary = newValue
                        if newValue { selectedTrackIndices.removeAll() }
                    }
                ))
                .tint(.white)

                VStack(spacing: 6) {
                    ForEach(Array(musicManager.trackFilenames.enumerated()), id: \.offset) { index, filename in
                        HStack(spacing: 12) {
                            Image(systemName: selectedTrackIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(selectedTrackIndices.contains(index) ? .white : Color.white.opacity(0.28))
                             Text(musicManager.displayName(for: filename))
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            useGlobalLibrary = false
                            if selectedTrackIndices.contains(index) {
                                selectedTrackIndices.remove(index)
                            } else {
                                selectedTrackIndices.insert(index)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(12)
                Text("Turn this off to choose a specific playlist for this workout.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow(label: "Type", value: workout.type.name)
            infoRow(label: "Sections", value: "\(workout.sections.count)")
            infoRow(label: "Total Duration", value: formatDuration(workout.totalDuration))
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(12)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(Theme.textPrimary)
        }
        .font(.subheadline)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private func saveSettings() {
        var w = workout
        w.restBetweenSections = restBetweenSections
        w.colorHex = colorHex
        w.musicTrackFilenames = useGlobalLibrary ? [] : selectedTrackIndices.sorted().map {
            musicManager.trackFilenames[$0]
        }
        store.updateWorkout(w)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: Workout(name: "Morning HIIT", sections: [
            Section(name: "Burpees",  duration: 45),
            Section(name: "Push-ups", duration: 30)
        ]))
    }
    .environmentObject(WorkoutStore())
    .preferredColorScheme(.dark)
}
