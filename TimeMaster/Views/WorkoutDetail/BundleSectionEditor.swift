import SwiftUI
import UniformTypeIdentifiers

struct BundleSectionEditor: View {
    @Binding var section: Section
    @EnvironmentObject private var databaseStore: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.workoutHeroSources) private var heroSources
    @State private var expandedSetIDs: Set<UUID> = []
    @State private var revealedSetCount = 1
    @State private var draggedID: UUID?
    @State private var addingToSetID: UUID?
    @State private var showingPages = false
    @State private var restPicker: RestExercisePicker?
    @State private var showingPhrase = false
    @State private var phrase = ""
    @State private var phraseDuration = 5
    var normalizesLegacy = true
    var onOpenPage: ((UUID) -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Picker("Exercise order", selection: $section.bundleOrder) {
                    Label("In order", systemImage: "list.number").tag(BundleOrder.ordered)
                    Label("Random", systemImage: "shuffle").tag(BundleOrder.random)
                }
                .pickerStyle(.segmented)
                .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: 8), action: { section.bundleOrder = section.bundleOrder == .ordered ? .random : .ordered })
                Button {
                    section.bundleVoiceEnabled.toggle()
                } label: {
                    Image(systemName: section.bundleVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .buttonStyle(BuilderChipButtonStyle())
                .accessibilityLabel("Spoken callouts")
                .accessibilityValue(section.bundleVoiceEnabled ? "On" : "Off")
                Button {
                    section.isTimerEnabled.toggle()
                } label: {
                    Image(systemName: section.isTimerEnabled ? "timer" : "hand.tap")
                }
                .buttonStyle(BuilderChipButtonStyle())
                .help(section.isTimerEnabled ? "Timer: each exercise counts down" : "Until Done: each exercise ends when you tap Done")
                .accessibilityLabel("Timing")
                .accessibilityValue(section.isTimerEnabled ? "Timer" : "Until Done")
                .accessibilityHint("Switches between a countdown and Until Done, where each exercise ends when you tap Done.")
            }
            ForEach(Array(section.slots.enumerated()), id: \.element.id) { index, set in
                setCard(set, index: index)
            }
            Button {
                addSet()
            } label: {
                Label("Set", systemImage: "plus")
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 44))
            HStack(spacing: 12) {
                Label("Prepare", systemImage: "timer")
                Spacer()
                DurationPickerView(seconds: $section.prepareTime, range: 0...30, step: 1, compact: true)
            }
            .font(TimeMasterFont.caption())
            HStack(spacing: 12) {
                Label("Big rest", systemImage: "pause.rectangle.fill")
                Spacer()
                DurationPickerView(seconds: Binding(
                    get: { section.bigRestRow?.duration ?? section.customRestAfter ?? 0 },
                    set: { seconds in
                        section.customRestAfter = seconds
                        if section.bigRestRow == nil { section.bigRestRow = RestRow(kind: .big, duration: seconds) }
                        section.bigRestRow?.duration = seconds
                    }
                ), range: 0...600, step: 5, compact: true)
            }
            .font(TimeMasterFont.caption())
        }
        .foregroundStyle(Theme.textPrimary)
        .font(TimeMasterFont.body())
        .onAppear {
            if normalizesLegacy {
                let normalized = section.bundleSets
                if section.slots != normalized { section.slots = normalized }
            }
            if section.sets != section.slots.count { section.sets = section.slots.count }
            expandedSetIDs = Set(section.slots.map(\.id))
            revealRemainingSets()
        }
        .sheet(isPresented: $showingPages) {
            DatabasePageBrowserSheet(
                workout: Workout(name: section.name),
                onAdd: { page, duration, _, _, _, _, _ in
                    appendExercise(SetSlot(exercisePageID: page.id, name: page.title, duration: duration, restAfter: 0, prepareTime: 0))
                    showingPages = false
                },
                onAddBundle: { sources, duration, _, _, _, _, _ in
                    for source in sources {
                        if case .page(let page) = source {
                            appendExercise(SetSlot(exercisePageID: page.id, name: page.title, duration: page.manifest.duration ?? duration, restAfter: 0, prepareTime: 0))
                        }
                    }
                    showingPages = false
                },
                initialBundleMode: true
            )
            .environmentObject(databaseStore)
            .environmentObject(workoutStore)
            .keyNavHost()
        }
        .sheet(item: $restPicker) { target in
            DatabasePageBrowserSheet(
                workout: Workout(name: section.name),
                onAdd: { page, _, _, _, _, _, _ in
                    if RestExercise.fits(page, restSeconds: target.seconds) {
                        updateRest(target.setID, target.exerciseID) { RestExercise.adding(page.id, to: $0) }
                    }
                    restPicker = nil
                },
                onAddBundle: { _, _, _, _, _, _, _ in },
                maxExerciseSeconds: target.seconds
            )
            .environmentObject(databaseStore)
            .environmentObject(workoutStore)
            .keyNavHost()
        }
        .sheet(isPresented: $showingPhrase) {
            NavigationStack {
                VStack(spacing: 20) {
                    TextField("Sprawl", text: $phrase)
                        .textFieldStyle(.plain)
                        .font(TimeMasterFont.black(24, relativeTo: .title2))
                        .padding(16)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 14))
                    DurationPickerView(seconds: $phraseDuration, range: 1...600, step: 1)
                    Spacer()
                }
                .padding(20)
                .background(Theme.background)
                .timeMasterNavigationTitle("New Callout")
                .toolbar {
                    AppToolbar.item(placement: .cancellationAction) {
                        Button("Cancel") { showingPhrase = false }
                    }
                    AppToolbar.item(placement: .confirmationAction) {
                        Button("Add") {
                            appendExercise(SetSlot(name: phrase.trimmingCharacters(in: .whitespacesAndNewlines), duration: phraseDuration, restAfter: 0, prepareTime: 0))
                            showingPhrase = false
                        }
                        .disabled(phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .font(TimeMasterFont.body())
            .keyNavHost()
        }
    }

    private func setCard(_ set: SetSlot, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BuilderHandle()
                Button {
                    toggleExpansion(of: set.id)
                } label: {
                    HStack {
                        Text("Set \(index + 1)")
                            .font(TimeMasterFont.black(17, relativeTo: .headline))
                        Text("\(set.leafExercises.count)")
                            .font(TimeMasterFont.caption().monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .rotationEffect(.degrees(expandedSetIDs.contains(set.id) ? 180 : 0))
                    }
                }
                .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Set \(index + 1)")
                .accessibilityValue(expandedSetIDs.contains(set.id) ? "Expanded" : "Collapsed")
                TmaxMenu {
                    Button("Page", systemImage: "book.pages") {
                        addingToSetID = set.id
                        showingPages = true
                    }
                    Button("Callout", systemImage: "text.bubble") {
                        addingToSetID = set.id
                        phrase = ""
                        showingPhrase = true
                    }
                    Button("Duplicate set", systemImage: "plus.square.on.square") {
                        var copy = set.duplicated()
                        copy.name = "Set \(section.slots.count + 1)"
                        section.slots.insert(copy, at: index + 1)
                        section.sets = section.slots.count
                        expandedSetIDs.insert(copy.id)
                    }
                    Button("Move up", systemImage: "arrow.up") { moveSet(index, to: index - 1) }
                        .disabled(index == 0)
                    Button("Move down", systemImage: "arrow.down") { moveSet(index, to: index + 1) }
                        .disabled(index + 1 == section.slots.count)
                    Button("Delete set", systemImage: "trash", role: .destructive) {
                        section.slots.removeAll { $0.id == set.id }
                        section.sets = section.slots.count
                    }
                    .disabled(section.slots.count == 1)
                } label: {
                    Image(systemName: "plus")
                }
                .builderChipMenu()
                .accessibilityLabel("Add exercise or edit set \(index + 1)")
            }
            .padding(.horizontal, 12)
            .keyNavTarget(id: set.id, role: .primary, shape: .roundedRectangle(cornerRadius: 14), action: { toggleExpansion(of: set.id) })
            .onDrag {
                draggedID = set.id
                return NSItemProvider(object: set.id.uuidString as NSString)
            }
            .onDrop(of: [.text], delegate: BundleItemDropDelegate(sourceID: draggedID, targetID: set.id) { source, target in
                guard let from = section.slots.firstIndex(where: { $0.id == source }),
                      let to = section.slots.firstIndex(where: { $0.id == target }) else { return }
                moveSet(from, to: to)
                draggedID = nil
            })
            if expandedSetIDs.contains(set.id), index < revealedSetCount {
                ForEach(Array(set.children.enumerated()), id: \.element.id) { exerciseIndex, exercise in
                    exerciseRow(exercise, setID: set.id, index: exerciseIndex)
                        .padding(.leading, 18)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: BuilderMetrics.rail)
                                .padding(.leading, 8)
                        }
                        .transition(.opacity)
                }
                HStack {
                    Label("Between sets", systemImage: "pause.fill")
                    Spacer()
                    DurationPickerView(seconds: slotValue(setID: set.id, exerciseID: nil, rest: true), range: 0...120, step: 1, compact: true)
                }
                .font(TimeMasterFont.caption())
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .transition(.opacity)
                restExercises(setID: set.id, exerciseID: nil, allowsAdding: index < section.slots.count - 1)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private func revealRemainingSets() {
        let total = section.slots.count
        revealedSetCount = min(max(1, total), 1)
        guard total > 1 else { return }
        Task { @MainActor in
            for next in 2...total {
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard !Task.isCancelled else { return }
                revealedSetCount = next
            }
        }
    }

    private func toggleExpansion(of id: UUID) {
        withAnimation(reduceMotion ? nil : EverMotion.disclosure) {
            if !expandedSetIDs.insert(id).inserted { expandedSetIDs.remove(id) }
        }
    }

    private func exerciseRow(_ exercise: SetSlot, setID: UUID, index: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal").font(.caption)
                Button {
                    if let id = exercise.exercisePageID {
                        heroSources?.markTapped("bundle-exercise-\(exercise.id)")
                        onOpenPage?(id)
                    }
                } label: {
                    BundleExerciseThumbnail(slot: exercise, size: 42)
                        .workoutHeroSource("bundle-exercise-\(exercise.id)")
                }
                .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 10))
                .disabled(exercise.exercisePageID == nil || onOpenPage == nil)
                .accessibilityLabel("Open \(exercise.displayName)")
                Text(exercise.displayName)
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if section.isTimerEnabled {
                    DurationPickerView(seconds: slotValue(setID: setID, exerciseID: exercise.id, rest: false), range: 1...600, step: 1, compact: true)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Label(exercise.repCount.map { "\($0) reps" } ?? "Estimated time", systemImage: "hand.tap")
                            .font(TimeMasterFont.black(11, relativeTo: .caption2))
                            .foregroundStyle(Theme.toolbarOrange)
                            .lineLimit(1)
                        DurationPickerView(seconds: slotValue(setID: setID, exerciseID: exercise.id, rest: false), range: 1...600, step: 1, compact: true)
                            .help("Estimated time, used for the workout's total")
                    }
                }
                TmaxMenu {
                    Button("Repeat", systemImage: "plus.square.on.square") {
                        mutateSet(setID) { $0.children.insert(exercise.duplicated(), at: index + 1) }
                    }
                    Button("Move up", systemImage: "arrow.up") { moveExercise(setID: setID, source: exercise.id, offset: -1) }
                        .disabled(index == 0)
                    Button("Move down", systemImage: "arrow.down") { moveExercise(setID: setID, source: exercise.id, offset: 1) }
                        .disabled(section.slots.first(where: { $0.id == setID })?.children.last?.id == exercise.id)
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        mutateSet(setID) { $0.children.removeAll { $0.id == exercise.id } }
                    }
                    .disabled(section.slots.first(where: { $0.id == setID })?.children.count == 1)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .builderChipMenu()
                .accessibilityLabel("Actions for \(exercise.displayName)")
            }
            HStack {
                Label("Rest", systemImage: "pause.fill")
                Spacer()
                DurationPickerView(seconds: slotValue(setID: setID, exerciseID: exercise.id, rest: true), range: 0...120, step: 1, compact: true)
            }
            .font(TimeMasterFont.caption())
            .foregroundStyle(Theme.textSecondary)
            if section.slots.first(where: { $0.id == setID })?.children.last?.id != exercise.id {
                restExercises(setID: setID, exerciseID: exercise.id, allowsAdding: true)
            }
        }
        .padding(10)
        .background(Theme.toolbarOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .keyNavTarget(id: exercise.id, role: .primary, shape: .roundedRectangle(cornerRadius: 10))
        .padding(.trailing, 8)
        .padding(.bottom, 6)
        .onDrag {
            draggedID = exercise.id
            return NSItemProvider(object: exercise.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: BundleItemDropDelegate(sourceID: draggedID, targetID: exercise.id) { source, target in
            mutateSet(setID) { set in
                guard let from = set.children.firstIndex(where: { $0.id == source }),
                      let to = set.children.firstIndex(where: { $0.id == target }) else { return }
                let child = set.children.remove(at: from)
                set.children.insert(child, at: to)
            }
            draggedID = nil
        })
    }

    private func slotValue(setID: UUID, exerciseID: UUID?, rest: Bool) -> Binding<Int> {
        Binding {
            guard let set = section.slots.first(where: { $0.id == setID }) else { return 0 }
            let slot = exerciseID.flatMap { id in set.children.first { $0.id == id } } ?? set
            return rest ? (slot.restRow?.duration ?? slot.restAfter) : slot.duration
        } set: { value in
            mutateSet(setID) { set in
                if let exerciseID, let index = set.children.firstIndex(where: { $0.id == exerciseID }) {
                    if rest {
                        set.children[index].restAfter = value
                        set.children[index].restRow?.duration = value
                        set.children[index].restExercisePageIDs = fitting(set.children[index].restExercisePageIDs, seconds: value)
                    } else {
                        set.children[index].duration = value
                    }
                } else if rest {
                    set.restAfter = value
                    set.restRow?.duration = value
                    set.restExercisePageIDs = fitting(set.restExercisePageIDs, seconds: value)
                }
            }
        }
    }

    private func mutateSet(_ id: UUID, _ change: (inout SetSlot) -> Void) {
        guard let index = section.slots.firstIndex(where: { $0.id == id }) else { return }
        change(&section.slots[index])
    }

    private func restSlot(setID: UUID, exerciseID: UUID?) -> SetSlot? {
        guard let set = section.slots.first(where: { $0.id == setID }) else { return nil }
        guard let exerciseID else { return set }
        return set.children.first { $0.id == exerciseID }
    }

    private func restSeconds(setID: UUID, exerciseID: UUID?) -> Int {
        restSlot(setID: setID, exerciseID: exerciseID)?.playbackRest ?? 0
    }

    private func updateRest(_ setID: UUID, _ exerciseID: UUID?, _ change: ([UUID]) -> [UUID]) {
        mutateSet(setID) { set in
            if let exerciseID {
                guard let index = set.children.firstIndex(where: { $0.id == exerciseID }) else { return }
                set.children[index].restExercisePageIDs = change(set.children[index].restExercisePageIDs)
            } else {
                set.restExercisePageIDs = change(set.restExercisePageIDs)
            }
        }
    }

    private func fitting(_ ids: [UUID], seconds: Int) -> [UUID] {
        guard seconds > 0 else { return [] }
        return ids.filter { id in
            databaseStore.page(id: id).map { RestExercise.fits($0, restSeconds: seconds) } ?? true
        }
    }

    @ViewBuilder
    private func restExercises(setID: UUID, exerciseID: UUID?, allowsAdding: Bool) -> some View {
        let ids = restSlot(setID: setID, exerciseID: exerciseID)?.restExercisePageIDs ?? []
        let seconds = restSeconds(setID: setID, exerciseID: exerciseID)
        let canAdd = allowsAdding && seconds > 0
        if !ids.isEmpty || canAdd {
            VStack(alignment: .leading, spacing: 6) {
                if !ids.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(ids, id: \.self) { pageID in
                                restChip(pageID, isDefault: ids.first == pageID, hasChoices: ids.count > 1, setID: setID, exerciseID: exerciseID)
                            }
                        }
                    }
                }
                if canAdd {
                    Button {
                        restPicker = RestExercisePicker(setID: setID, exerciseID: exerciseID, seconds: seconds)
                    } label: {
                        Label("Rest exercise", systemImage: "plus")
                            .font(TimeMasterFont.black(12, relativeTo: .caption))
                            .foregroundStyle(Theme.toolbarOrange)
                            .frame(minHeight: 28)
                    }
                    .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(ids.isEmpty ? "Add rest exercise" : "Add another rest exercise")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func restChip(_ pageID: UUID, isDefault: Bool, hasChoices: Bool, setID: UUID, exerciseID: UUID?) -> some View {
        let title = databaseStore.page(id: pageID)?.title ?? "Rest exercise"
        return TmaxMenu {
            if let onOpenPage {
                Button("Open", systemImage: "book.pages") { onOpenPage(pageID) }
            }
            if !isDefault {
                Button("Make Default", systemImage: "star") {
                    updateRest(setID, exerciseID) { RestExercise.making(pageID, defaultIn: $0) }
                }
            }
            Divider()
            Button("Remove", systemImage: "trash", role: .destructive) {
                updateRest(setID, exerciseID) { RestExercise.removing(pageID, from: $0) }
            }
        } label: {
            HStack(spacing: 6) {
                BundlePageThumbnail(pageID: pageID, size: 24, fallbackIcon: "figure.cooldown")
                Text(title)
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .lineLimit(1)
                if isDefault && hasChoices {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.toolbarOrange)
                }
            }
            .padding(.leading, 3)
            .padding(.trailing, 9)
            .padding(.vertical, 3)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.separator, lineWidth: 1))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityLabel(isDefault && hasChoices ? "\(title), default rest exercise" : "\(title), rest exercise")
        .accessibilityHint("Opens, makes default or removes this rest exercise")
    }

    private func appendExercise(_ exercise: SetSlot) {
        if section.slots.isEmpty { addSet() }
        guard let id = addingToSetID ?? section.slots.last?.id else { return }
        mutateSet(id) { $0.children.append(exercise) }
        expandedSetIDs.insert(id)
    }

    private func addSet() {
        var set = section.slots.last?.duplicated() ?? SetSlot(name: "Set 1", duration: 5, restAfter: section.restBetweenSets, prepareTime: nil)
        set.name = "Set \(section.slots.count + 1)"
        if set.children.isEmpty { set.children = [] }
        section.slots.append(set)
        section.sets = section.slots.count
        expandedSetIDs.insert(set.id)
        addingToSetID = set.id
    }

    private func moveSet(_ source: Int, to destination: Int) {
        guard section.slots.indices.contains(source), section.slots.indices.contains(destination), source != destination else { return }
        let set = section.slots.remove(at: source)
        section.slots.insert(set, at: destination)
    }

    private func moveExercise(setID: UUID, source: UUID, offset: Int) {
        mutateSet(setID) { set in
            guard let index = set.children.firstIndex(where: { $0.id == source }), set.children.indices.contains(index + offset) else { return }
            let exercise = set.children.remove(at: index)
            set.children.insert(exercise, at: index + offset)
        }
    }
}

private struct RestExercisePicker: Identifiable {
    let id = UUID()
    let setID: UUID
    let exerciseID: UUID?
    let seconds: Int
}

struct BundleItemDropDelegate: DropDelegate {
    let sourceID: UUID?
    let targetID: UUID
    let move: (UUID, UUID) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let sourceID, sourceID != targetID else { return false }
        move(sourceID, targetID)
        return true
    }
}
