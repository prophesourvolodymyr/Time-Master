import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
    @State private var showingAddOptions = false
    @State private var showingSavedWorkoutPicker = false
    @State private var browserStartsInBundleMode = false
    @State private var workoutSummaryFrame = CGRect.zero

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
                    ZStack(alignment: .top) {
                        sectionList

                        if !workout.sections.isEmpty {
                            compactWorkoutSummary
                                .opacity(Double(workoutSummaryCollapseProgress))
                                .allowsHitTesting(workoutSummaryCollapseProgress > 0.85)
                                .accessibilityHidden(workoutSummaryCollapseProgress < 0.85)
                                .zIndex(1)
                        }
                    }
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

                onAdd: { page, dur, sets, reps, restAfter, restBetween, prepareTime in
                    handlePageSelection(
                        page,
                        duration: dur,
                        sets: sets,
                        reps: reps,
                        restAfter: restAfter,
                        restBetween: restBetween,
                        prepareTime: prepareTime
                    )
                },
                onAddBundle: { sources, dur, sets, reps, restAfter, restBetween, prepareTime in
                    guard case .newSection = browserTarget, !sources.isEmpty else { return }
                    showBrowserSheet = false
                    pendingSection = PendingSectionConfig(
                        name: "Bundle: \(sources.map(\.title).joined(separator: ", "))",
                        pageID: sources.first?.pageID,
                        sourcePages: sources.compactMap { source in
                            if case .page(let page) = source { return page }
                            return nil
                        },
                        bundleSources: sources,
                        duration: dur,
                        sets: sources.count,
                        repCount: reps > 0 ? reps : nil,
                        restAfter: restAfter,
                        restBetweenSets: restBetween,
                        prepareTime: prepareTime,
                        mode: .bundle
                    )
                },
                onNewExercise: nil,
                initialBundleMode: browserStartsInBundleMode
            )
            .environmentObject(databaseStore)
            .environmentObject(store)
            .onDisappear {
                browserStartsInBundleMode = false
            }
        }
        .sheet(isPresented: $showingAddOptions) {
            WorkoutAddContentSheet { type in
                handleAddContentType(type)
            }
        }
        .sheet(isPresented: $showingSavedWorkoutPicker) {
            SavedWorkoutPickerSheet(excludingWorkoutID: workoutID) { savedWorkout in
                addSavedWorkoutSection(savedWorkout)
            }
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
                showingAddOptions = true
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
                openBrowser(.newSection)
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

    private var workoutSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                WorkoutCoverMosaic(
                    workout: workout,
                    size: 64,
                    styleOverride: .exerciseThumbnails
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.type.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(workout.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                detailMetric(value: "\(workout.sectionCount)", label: "sections")
                detailMetric(value: "\(workoutSetCount)", label: "sets")
                detailMetric(value: formatCompactDuration(workout.totalDuration), label: "duration")
                detailMetric(value: "\(completedSessionCount)", label: "completed")
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func detailMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var compactWorkoutSummary: some View {
        HStack(spacing: 8) {
            WorkoutCoverMosaic(
                workout: workout,
                size: 42,
                styleOverride: .exerciseThumbnails
            )

            Text(workout.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            HStack(spacing: 8) {
                compactDetailMetric(
                    value: "\(workout.sectionCount)",
                    icon: "square.stack.3d.up",
                    label: "Sections"
                )
                compactDetailMetric(
                    value: "\(workoutSetCount)",
                    icon: "square.grid.2x2",
                    label: "Sets"
                )
                compactDetailMetric(
                    value: formatCompactDuration(workout.totalDuration),
                    icon: "clock",
                    label: "Duration"
                )
                compactDetailMetric(
                    value: "\(completedSessionCount)",
                    icon: "checkmark.circle",
                    label: "Completed"
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func compactDetailMetric(value: String, icon: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(value)
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(Theme.textSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private var workoutSummaryCollapseProgress: CGFloat {
        guard workoutSummaryFrame.height > 0 else { return 0 }
        let collapseDistance = max(workoutSummaryFrame.height * 0.65, 1)
        return min(1, max(0, -workoutSummaryFrame.minY / collapseDistance))
    }

    private var workoutSetCount: Int {
        workout.sections.reduce(0) { $0 + $1.slotCount }
    }

    private var completedSessionCount: Int {
        store.historyEntries.filter { $0.workoutId == workout.id }.count
    }


    private var sectionList: some View {
        List {
            if !workout.sections.isEmpty {
                workoutSummary
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: WorkoutSummaryFramePreferenceKey.self,
                                value: proxy.frame(in: .named("workout-detail-scroll"))
                            )
                        }
                    }
            }

            if let pending = pendingSection {
                builderListRow(
                    pendingConfigCard(pending),
                    insets: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
                )
            }

            ForEach(sectionIDs, id: \.self) { id in
                if let section = workout.sections.first(where: { $0.id == id }) {
                    let bigRest = section.bigRestRow ?? RestRow(
                        id: section.id,
                        kind: .big,
                        duration: section.customRestAfter ?? workout.restBetweenSections
                    )

                    builderListRow(
                        sectionHeader(section, isExpanded: expandedSectionIDs.contains(section.id)),
                        insets: EdgeInsets(top: 6, leading: 12, bottom: 2, trailing: 12)
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            sectionToDelete = section
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }

                    if expandedSectionIDs.contains(section.id) {
                        expandedSectionRows(section)
                    }

                    builderListRow(
                        restRowView(
                            bigRest,
                            target: RestTarget(sectionID: section.id, slotID: nil, isBig: true)
                        ),
                        insets: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12),
                        depth: 1
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            removeRestRow(RestTarget(sectionID: section.id, slotID: nil, isBig: true))
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                        .tint(.red)
                    }

                    restDetailRows(
                        row: bigRest,
                        target: RestTarget(sectionID: section.id, slotID: nil, isBig: true),
                        depth: 2
                    )
                }
            }
            .onMove(perform: moveSections)
        }
        .coordinateSpace(name: "workout-detail-scroll")
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.smooth(duration: 0.28), value: workout.sections.map(\.id))
        .onPreferenceChange(WorkoutSummaryFramePreferenceKey.self) { frame in
            workoutSummaryFrame = frame
        }
    }

    private func builderListRow<Content: View>(
        _ content: Content,
        insets: EdgeInsets,
        depth: Int = 0
    ) -> some View {
        BuilderThreadedRow(depth: depth) {
            content
        }
        .listRowInsets(insets)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func expandedSectionRows(_ section: Section) -> some View {
        ForEach(Array(section.effectiveSlots.enumerated()), id: \.element.id) { slotIndex, slot in
            if section.preparationTime(for: slot) > 0 {
                builderListRow(
                    preparationRow(section: section, slot: slot),
                    insets: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12),
                    depth: 1
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        disablePreparation(in: section.id, slotID: slot.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }

            builderListRow(
                setRow(section: section, slot: slot, index: slotIndex),
                insets: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12),
                depth: 1
            )
            .onDrag {
                draggedSlotID = slot.id
                return NSItemProvider(object: slot.id.uuidString as NSString)
            }
            .onDrop(
                of: [.text],
                delegate: SlotDropDelegate(
                    sourceID: draggedSlotID,
                    targetID: slot.id,
                    move: { sourceID, targetID in
                        moveSlot(in: section.id, sourceID: sourceID, before: targetID)
                    }
                )
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    requestSlotRemoval(slot, from: section)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }

            ForEach(slot.drops) { drop in
                builderListRow(
                    dropRow(section: section, slot: slot, drop: drop),
                    insets: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12),
                    depth: 2
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        removeDrop(sectionID: section.id, slotID: slot.id, dropID: drop.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }

                if drop.restAfter > 0 {
                    let target = RestTarget(
                        sectionID: section.id,
                        slotID: slot.id,
                        dropID: drop.id,
                        isBig: false
                    )
                    let rest = RestRow(id: drop.id, kind: .normal, duration: drop.restAfter)

                    builderListRow(
                        restRowView(rest, target: target),
                        insets: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12),
                        depth: 3
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            removeRestRow(target)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }

                    restDetailRows(row: rest, target: target, depth: 4)
                }
            }

            if (slot.restRow?.duration ?? slot.restAfter) > 0 {
                let rest = slot.restRow ?? RestRow(
                    id: slot.id,
                    kind: .normal,
                    duration: slot.restAfter
                )
                let target = RestTarget(sectionID: section.id, slotID: slot.id, isBig: false)

                builderListRow(
                    restRowView(rest, target: target),
                    insets: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12),
                    depth: 2
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        removeRestRow(target)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }

                restDetailRows(row: rest, target: target, depth: 3)
            }
        }
    }

    private func sectionHeader(_ section: Section, isExpanded: Bool) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
                    .frame(width: 12)

                Text(formatCompactDuration(section.calculatedDuration))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(Theme.textSecondary)

                pageThumbnailButton(
                    pageID: section.pageID,
                    size: 42,
                    fallbackIcon: section.mode == .bundle ? "rectangle.stack.fill" : "figure.run"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                toggleSection(section.id)
            } label: {
                VStack(spacing: 3) {
                    Text(section.name)
                        .font(.headline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    Text(sectionSummary(section))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    addSlot(in: section.id)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add set to \(section.name)")

                Menu {
                    Button {
                        addSlot(in: section.id)
                    } label: {
                        Label("Add Set", systemImage: "plus")
                    }
                    if let firstSlot = section.effectiveSlots.first {
                        Button {
                            openBrowser(.addDrop(section.id, firstSlot.id))
                        } label: {
                            Label("Add Drop Set", systemImage: "arrow.down.right")
                        }
                    }
                    Button {
                        var copy = section
                        copy.id = UUID()
                        copy.name = "\(section.name) Copy"
                        copy.slots = section.effectiveSlots.map { slot in
                            var copied = slot
                            copied.id = UUID()
                            copied.restRow?.id = UUID()
                            copied.drops = slot.drops.map { drop in
                                var copiedDrop = drop
                                copiedDrop.id = UUID()
                                return copiedDrop
                            }
                            return copied
                        }
                        if var bigRest = copy.bigRestRow {
                            bigRest.id = copy.id
                            copy.bigRestRow = bigRest
                        }
                        store.addSection(to: workout, section: copy)
                        sectionIDs = store.workout(id: workoutID)?.sections.map(\.id) ?? []
                        expandedSectionIDs.insert(copy.id)
                    } label: {
                        Label("Duplicate Section", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) {
                        sectionToDelete = section
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Section", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 26, height: 28)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Actions for \(section.name)")

                Button {
                    toggleSection(section.id)
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse \(section.name)" : "Expand \(section.name)")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sectionSummary(_ section: Section) -> String {
        var parts = [section.mode == .bundle ? "Bundle" : "\(section.slotCount) sets"]
        if let reps = section.repCount {
            parts.append("\(reps) reps")
        }
        return parts.joined(separator: " · ")
    }

    private func preparationRow(section: Section, slot: SetSlot) -> some View {
        let seconds = section.preparationTime(for: slot)

        return HStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "timer")
                    .font(.caption.weight(.semibold))
                Text(formatCompactDuration(seconds))
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Preparation for that set")
                .font(.caption.weight(.medium))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Button(role: .destructive) {
                disablePreparation(in: section.id, slotID: slot.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.red)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete preparation for set \(slot.displayName)")
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func setRow(section: Section, slot: SetSlot, index: Int) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                durationButton(
                    text: formatCompactDuration(slot.duration),
                    title: "Set \(index + 1) duration",
                    seconds: slot.duration,
                    foreground: .black
                ) {
                    durationEdit = DurationEditTarget(
                        title: "Set \(index + 1) duration",
                        seconds: slot.duration,
                        kind: .slot(section.id, slot.id)
                    )
                }

                pageThumbnailButton(
                    pageID: slot.exercisePageID,
                    size: 34,
                    fallbackIcon: "figure.run"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                inspectedPageID = slot.exercisePageID
            } label: {
                VStack(spacing: 2) {
                    Text(slot.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    Text("Set \(index + 1)")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.black.opacity(0.56))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Menu {
                    if slot.prepareTime == 0 {
                        Button {
                            enablePreparation(in: section.id, slotID: slot.id)
                        } label: {
                            Label("Add Preparation", systemImage: "timer")
                        }
                    }
                    Button {
                        openBrowser(.addDrop(section.id, slot.id))
                    } label: {
                        Label("Add Drop Set", systemImage: "arrow.down.right")
                    }
                    Button {
                        openBrowser(.setRestExercise(section.id, slot.id))
                    } label: {
                        Label("Set Rest Exercise", systemImage: "figure.cooldown")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.black)
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Add to set \(index + 1)")

                Button(role: .destructive) {
                    requestSlotRemoval(slot, from: section)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete set \(index + 1)")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func dropRow(section: Section, slot: SetSlot, drop: DropSet) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                durationButton(
                    text: formatCompactDuration(drop.duration),
                    title: "\(drop.displayName) duration",
                    seconds: drop.duration,
                    foreground: .black
                ) {
                    durationEdit = DurationEditTarget(
                        title: "\(drop.displayName) duration",
                        seconds: drop.duration,
                        kind: .drop(section.id, slot.id, drop.id)
                    )
                }

                pageThumbnailButton(
                    pageID: drop.exercisePageID,
                    size: 28,
                    fallbackIcon: "arrow.down.right"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                inspectedPageID = drop.exercisePageID
            } label: {
                VStack(spacing: 2) {
                    Text(drop.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    Text("Drop")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.black.opacity(0.56))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                removeDrop(sectionID: section.id, slotID: slot.id, dropID: drop.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.red)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(drop.displayName)")
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func durationButton(
        text: String,
        title: String,
        seconds: Int,
        foreground: Color = Theme.textPrimary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundColor(foreground)
                .lineLimit(1)
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

        return HStack(spacing: 12) {
            HStack(spacing: 7) {
                durationButton(
                    text: formatCompactDuration(row.duration),
                    title: row.kind == .big ? "Big rest duration" : "Rest duration",
                    seconds: row.duration,
                    foreground: .black
                ) {
                    durationEdit = DurationEditTarget(
                        title: row.kind == .big ? "Big rest duration" : "Rest duration",
                        seconds: row.duration,
                        kind: .rest(target)
                    )
                }

                Image(systemName: row.kind == .big ? "square.stack.3d.up.fill" : "pause.fill")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.kind == .big ? "Big Rest" : "Rest")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)

            HStack(spacing: 4) {
                restActionMenu(target: target)

                Button {
                    if isExpanded {
                        expandedRestRowIDs.remove(row.id)
                    } else {
                        expandedRestRowIDs.insert(row.id)
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.black)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse rest contents" : "Expand rest contents")

                Button(role: .destructive) {
                    removeRestRow(target)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(row.kind == .big ? "Clear big rest" : "Delete rest")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.restAccent)
        .clipShape(RoundedRectangle(cornerRadius: row.kind == .big ? 11 : 8))
    }

    private func restExerciseRow(pageID: UUID) -> some View {
        HStack(spacing: 12) {
            pageThumbnailButton(
                pageID: pageID,
                size: 24,
                fallbackIcon: "figure.cooldown"
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(databaseStore.page(id: pageID)?.title ?? "Rest exercise")
                .font(.caption.weight(.medium))
                .foregroundColor(.black)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Color.clear
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.restAccent)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var restEmptyHint: some View {
        Text("Add a note, stretch, or rest exercise")
            .font(.caption)
            .foregroundColor(.black.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.restAccent.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func restActionMenu(target: RestTarget) -> some View {
        Menu {
            Button("Add Note", systemImage: "note.text") {
                noteEditTarget = RestNoteTarget(target: target, contentID: nil, text: "")
            }
            Button("Add Stretch", systemImage: "figure.cooldown") {
                openBrowser(.restStretch(target))
            }
            if !target.isBig, target.dropID == nil, let slotID = target.slotID {
                Button("Add Rest Exercise", systemImage: "figure.cooldown") {
                    openBrowser(.setRestExercise(target.sectionID, slotID))
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .foregroundColor(.black)
                .frame(width: 26, height: 26)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Add rest content")
    }

    @ViewBuilder
    private func restDetailRows(row: RestRow, target: RestTarget, depth: Int) -> some View {
        if expandedRestRowIDs.contains(row.id) {
            let restPageID = restExercisePageID(for: target)

            if let restPageID {
                builderListRow(
                    restExerciseRow(pageID: restPageID),
                    insets: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12),
                    depth: depth
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        clearRestExercise(sectionID: target.sectionID, slotID: target.slotID)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }

            if row.contents.isEmpty && restPageID == nil {
                builderListRow(
                    restEmptyHint,
                    insets: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12),
                    depth: depth
                )
            } else {
                ForEach(row.contents) { content in
                    builderListRow(
                        restContentRow(content, target: target),
                        insets: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12),
                        depth: depth
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            removeRestContent(target, contentID: content.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }

    private func restContentRow(_ content: RestContent, target: RestTarget) -> some View {
        HStack(spacing: 12) {
            pageThumbnailButton(
                pageID: content.pageID,
                size: 24,
                fallbackIcon: content.kind == .stretch ? "figure.cooldown" : "note.text"
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(content.text.isEmpty ? (content.kind == .stretch ? "Stretch" : "Note") : content.text)
                .font(.caption.weight(.medium))
                .foregroundColor(.black)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            HStack(spacing: 4) {
                if content.kind == .note {
                    Button {
                        noteEditTarget = RestNoteTarget(target: target, contentID: content.id, text: content.text)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .destructive) {
                    removeRestContent(target, contentID: content.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete rest content")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.restAccent)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func toggleSection(_ id: UUID) {
        if expandedSectionIDs.contains(id) {
            expandedSectionIDs.remove(id)
        } else {
            expandedSectionIDs.insert(id)
        }
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

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 6)],
                spacing: 6
            ) {
                inlineStepper(label: "Duration", value: Binding(
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
                inlineStepper(label: "After Rest", value: Binding(
                    get: { pending.restAfter },
                    set: { pendingSection?.restAfter = $0 }
                ), range: 0...120, step: 5, unit: "s")
                inlineStepper(label: "Between", value: Binding(
                    get: { pending.restBetweenSets },
                    set: { pendingSection?.restBetweenSets = $0 }
                ), range: 0...120, step: 5, unit: "s")
                inlineStepper(label: "Prepare", value: Binding(
                    get: { pending.prepareTime },
                    set: { pendingSection?.prepareTime = $0 }
                ), range: 0...30, step: 1, unit: "s")
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
        let configuration = WorkoutSectionImportConfiguration(
            duration: pending.duration,
            sets: pending.sets,
            repCount: pending.repCount,
            restAfter: pending.restAfter,
            restBetweenSets: pending.restBetweenSets,
            prepareTime: pending.prepareTime
        )

        let section: Section?
        switch pending.mode {
        case .timed:
            section = pending.sourcePages.first.flatMap {
                WorkoutSectionBuilder.makeSection(page: $0, configuration: configuration)
            }
        case .bundle:
            section = WorkoutSectionBuilder.makeBundle(
                sources: pending.bundleSources,
                configuration: configuration
            )
        }

        guard let section else { return }
        store.addSection(to: workout, section: section)
        sectionIDs = store.workout(id: workoutID)?.sections.map(\.id) ?? []
        expandedSectionIDs.insert(section.id)
        pendingSection = nil
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
        AppToolbar.iconItem(placement: .primaryAction) {
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
                    .foregroundStyle(.orange)
            }
            .accessibilityLabel("Workout actions")
        }
        AppToolbar.iconItem(placement: .primaryAction) {
            Button {
                showingAddOptions = true
            } label: {
                Image(systemName: "plus")
                    .foregroundStyle(.orange)
            }
            .accessibilityLabel("Add to workout")
        }
        AppToolbar.iconItem(placement: .primaryAction) {
            Button {
                openBrowser(.newSection)
            } label: {
                Image(systemName: "folder.fill.badge.plus")
                    .foregroundStyle(.orange)
            }
            .accessibilityLabel("Browse exercises")
        }
    }

    // MARK: - Helpers

    private func handleAddContentType(_ type: WorkoutAddContentType) {
        showingAddOptions = false

        switch type {
        case .bundle:
            Task { @MainActor in
                await Task.yield()
                openBrowser(.newSection, bundleMode: true)
            }
        case .workout:
            Task { @MainActor in
                await Task.yield()
                showingSavedWorkoutPicker = true
            }
        case .bike:
            addOutdoorSection(kind: .bike)
        case .runWalk:
            addOutdoorSection(kind: .runWalk)
        }
    }

    private func addSavedWorkoutSection(_ savedWorkout: Workout) {
        showingSavedWorkoutPicker = false
        pendingSection = PendingSectionConfig(
            name: "Workout: \(savedWorkout.name)",
            pageID: nil,
            bundleSources: [.workout(savedWorkout)],
            duration: max(5, savedWorkout.totalDuration),
            sets: 1,
            repCount: nil,
            restAfter: 0,
            restBetweenSets: 0,
            prepareTime: 0,
            mode: .bundle
        )
    }

    private func addOutdoorSection(kind: OutdoorActivityKind) {
        let duration = 30 * 60
        let section = Section(
            name: kind.displayName,
            duration: duration,
            sets: 1,
            restBetweenSets: 0,
            customRestAfter: 0,
            prepareTime: 0,
            mode: .timed,
            slots: [
                SetSlot(
                    name: kind.displayName,
                    duration: duration,
                    restAfter: 0,
                    prepareTime: 0
                )
            ]
        )
        store.addSection(to: workout, section: section)
        sectionIDs = store.workout(id: workoutID)?.sections.map(\.id) ?? []
    }

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
        restBetween: Int,
        prepareTime: Int
    ) {
        switch browserTarget {
        case .newSection:
            pendingSection = PendingSectionConfig(
                name: page.title,
                pageID: page.id,
                sourcePages: [page],
                duration: duration,
                sets: sets,
                repCount: reps > 0 ? reps : nil,
                restAfter: restAfter,
                restBetweenSets: restBetween,
                prepareTime: prepareTime
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


    private func openBrowser(
        _ target: BuilderBrowserTarget,
        bundleMode: Bool = false
    ) {
        browserTarget = target
        browserStartsInBundleMode = bundleMode
        databaseStore.reload()
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

    private func addSlot(in sectionID: UUID) {
        mutateSection(id: sectionID) { section in
            var slots = section.effectiveSlots
            guard let source = slots.last else { return }

            if let previousIndex = slots.indices.last {
                let previousID = slots[previousIndex].id
                slots[previousIndex].restAfter = max(0, section.restBetweenSets)
                slots[previousIndex].restRow = RestRow(
                    id: previousID,
                    kind: .normal,
                    duration: max(0, section.restBetweenSets)
                )
            }

            var newSlot = source
            newSlot.id = UUID()
            newSlot.prepareTime = nil
            newSlot.drops = []
            newSlot.children = []
            newSlot.restExercisePageID = nil
            newSlot.restAfter = 0
            newSlot.restRow = nil
            slots.append(newSlot)
            section.slots = slots
            section.sets = slots.count
        }
    }

    private func requestSlotRemoval(_ slot: SetSlot, from section: Section) {
        let slots = section.effectiveSlots
        guard let index = slots.firstIndex(where: { $0.id == slot.id }) else { return }
        guard slots.count > 1 else {
            sectionToDelete = section
            showingDeleteAlert = true
            return
        }
        removeSlot(in: section.id, at: index)
    }

    private func removeDrop(sectionID: UUID, slotID: UUID, dropID: UUID) {
        mutateSection(id: sectionID) { section in
            var slots = section.effectiveSlots
            guard let slotIndex = slots.firstIndex(where: { $0.id == slotID }) else { return }
            slots[slotIndex].drops.removeAll { $0.id == dropID }
            section.slots = slots
        }
    }

    private func removeRestRow(_ target: RestTarget) {
        mutateSection(id: target.sectionID) { section in
            if target.isBig {
                var row = section.bigRestRow ?? RestRow(
                    id: section.id,
                    kind: .big,
                    duration: section.customRestAfter ?? workout.restBetweenSections
                )
                row.duration = 0
                row.contents.removeAll()
                section.bigRestRow = row
                section.customRestAfter = 0
                return
            }

            var slots = section.effectiveSlots
            guard let slotID = target.slotID,
                  let slotIndex = slots.firstIndex(where: { $0.id == slotID }) else { return }

            if let dropID = target.dropID,
               let dropIndex = slots[slotIndex].drops.firstIndex(where: { $0.id == dropID }) {
                slots[slotIndex].drops[dropIndex].restAfter = 0
            } else {
                slots[slotIndex].restAfter = 0
                slots[slotIndex].restRow = nil
                slots[slotIndex].restExercisePageID = nil
            }
            section.slots = slots
        }
    }

    private func disablePreparation(in sectionID: UUID, slotID: UUID) {
        mutateSection(id: sectionID) { section in
            var slots = section.effectiveSlots
            guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
            slots[index].prepareTime = 0
            section.slots = slots
        }
    }

    private func enablePreparation(in sectionID: UUID, slotID: UUID) {
        mutateSection(id: sectionID) { section in
            var slots = section.effectiveSlots
            guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
            slots[index].prepareTime = nil
            section.slots = slots
        }
    }

    private func clearRestExercise(sectionID: UUID, slotID: UUID?) {
        guard let slotID else { return }
        mutateSection(id: sectionID) { section in
            var slots = section.effectiveSlots
            guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
            slots[index].restExercisePageID = nil
            section.slots = slots
        }
    }

    private func restExercisePageID(for target: RestTarget) -> UUID? {
        guard !target.isBig, target.dropID == nil, let slotID = target.slotID else { return nil }
        return workout.sections
            .first(where: { $0.id == target.sectionID })?
            .effectiveSlots
            .first(where: { $0.id == slotID })?
            .restExercisePageID
    }

}

private struct WorkoutSummaryFramePreferenceKey: PreferenceKey {
    static var defaultValue = CGRect.zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct PendingSectionConfig {
    var name: String
    var pageID: UUID?
    var sourcePages: [ExercisePage] = []
    var bundleSources: [WorkoutBundleSource] = []
    var duration: Int
    var sets: Int
    var repCount: Int?
    var restAfter: Int
    var restBetweenSets: Int
    var prepareTime: Int = 4
    var mode: SectionMode = .timed
}
private enum WorkoutAddContentType {
    case bundle
    case workout
    case bike
    case runWalk
}

private struct WorkoutAddContentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (WorkoutAddContentType) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose what to add to this workout.")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)

                    option(
                        title: "Bundle",
                        subtitle: "Select multiple exercises together",
                        icon: "rectangle.stack.fill",
                        type: .bundle
                    )
                    option(
                        title: "Workout",
                        subtitle: "Add a saved workout",
                        icon: "figure.strengthtraining.traditional",
                        type: .workout
                    )
                    option(
                        title: "Bike",
                        subtitle: "Add a timed bike section",
                        icon: "bicycle",
                        type: .bike
                    )
                    option(
                        title: "Walk & Run",
                        subtitle: "Add a timed outdoor section",
                        icon: "figure.run",
                        type: .runWalk
                    )
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Add to Workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 430)
        #endif
    }

    private func option(
        title: String,
        subtitle: String,
        icon: String,
        type: WorkoutAddContentType
    ) -> some View {
        Button {
            onSelect(type)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct SavedWorkoutPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkoutStore

    let excludingWorkoutID: UUID
    let onSelect: (Workout) -> Void

    private var savedWorkouts: [Workout] {
        store.workouts
            .filter {
                $0.id != excludingWorkoutID &&
                store.canNestWorkout($0.id, in: excludingWorkoutID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if savedWorkouts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(savedWorkouts) { savedWorkout in
                                Button {
                                    onSelect(savedWorkout)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: savedWorkout.type.iconName)
                                            .font(.title3)
                                            .foregroundColor(Color(hex: savedWorkout.colorHex))
                                            .frame(width: 42, height: 42)
                                            .background(Theme.surface2)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(savedWorkout.name)
                                                .font(.headline)
                                                .foregroundColor(Theme.textPrimary)
                                            Text("\(savedWorkout.sections.count) sections · \(formatDuration(savedWorkout.totalDuration))")
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }

                                        Spacer(minLength: 8)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Add Saved Workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 420)
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 58))
                .foregroundColor(Theme.textSecondary)
            Text("No saved workouts yet")
                .font(.title2.weight(.semibold))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Create a workout first, then add it here as a nested section.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                dismiss()
                NotificationCenter.default.post(name: .newWorkoutCommand, object: nil)
            } label: {
                Text("Create New Workout")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes > 0 ? "\(minutes) min" : "\(max(0, seconds)) sec"
    }
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

    @State private var coverStyle: WorkoutCoverStyle
    @State private var coverFilename: String?
    @State private var showingCoverImporter = false
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
        _coverStyle = State(initialValue: w.coverStyle)
        _coverFilename = State(initialValue: w.imageFilename)
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
                        coverSection
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

    private var coverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Cover")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            Picker("Cover style", selection: $coverStyle) {
                ForEach(WorkoutCoverStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if coverStyle == .customImage {
                HStack(spacing: 12) {
                    AsyncCoverImage(
                        url: coverFilename.map { PhotoManager.shared.photoURL(for: $0) },
                        fallbackIcon: workout.type.iconName,
                        fallbackColor: Color(hex: workout.type.colorHex),
                        height: 64,
                        contentMode: .fill,
                        overlayGradient: false
                    )
                    .frame(width: 82, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("Choose image") {
                        showingCoverImporter = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(Theme.textPrimary)

                    Spacer()
                }
                .fileImporter(
                    isPresented: $showingCoverImporter,
                    allowedContentTypes: [.image],
                    allowsMultipleSelection: false
                ) { result in
                    importCover(result)
                }
            }
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

    private func importCover(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url) else { return }

        #if os(iOS)
        guard let image = UIImage(data: data) else { return }
        #elseif os(macOS)
        guard let image = NSImage(data: data) else { return }
        #endif

        if let filename = PhotoManager.shared.savePhoto(image) {
            coverFilename = filename
            coverStyle = .customImage
        }
    }

    private func saveSettings() {
        var w = workout
        w.restBetweenSections = restBetweenSections
        w.colorHex = colorHex
        w.coverStyle = coverStyle
        w.imageFilename = coverFilename
        w.musicTrackFilenames = useGlobalLibrary ? [] : selectedTrackIndices.sorted().map {
            musicManager.trackFilenames[$0]
        }
        store.updateWorkout(w)
        dismiss()
    }
}

private struct BuilderThreadedRow<Content: View>: View {
    let depth: Int
    let content: Content

    init(depth: Int, @ViewBuilder content: () -> Content) {
        self.depth = max(0, depth)
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            if depth > 0 {
                BuilderThread(depth: depth)
            }
            content
        }
        .padding(.vertical, depth > 0 ? 2 : 0)
    }
}

private struct BuilderThread: View {
    let depth: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<depth, id: \.self) { level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(level == depth - 1 ? 0.38 : 0.16))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .frame(width: 16)
            }
        }
        .overlay(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.38))
                .frame(width: 16, height: 1)
                .offset(x: 8)
        }
        .accessibilityHidden(true)
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
