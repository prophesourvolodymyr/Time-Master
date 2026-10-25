import SwiftUI
import UniformTypeIdentifiers

struct BundleSectionEditor: View {
    @Binding var section: Section
    @EnvironmentObject private var databaseStore: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedSetIDs: Set<UUID> = []
    @State private var draggedID: UUID?
    @State private var addingToSetID: UUID?
    @State private var showingPages = false
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
                Button {
                    section.bundleVoiceEnabled.toggle()
                } label: {
                    Image(systemName: section.bundleVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .frame(width: 44, height: 44)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Spoken callouts")
                .accessibilityValue(section.bundleVoiceEnabled ? "On" : "Off")
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
            if normalizesLegacy { section.slots = section.bundleSets }
            section.sets = section.slots.count
            expandedSetIDs = Set(section.slots.map(\.id))
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
        }
        .sheet(isPresented: $showingPhrase) {
            NavigationStack {
                VStack(spacing: 20) {
                    TextField("Sprawl", text: $phrase)
                        .textFieldStyle(.plain)
                        .font(TimeMasterFont.black(24, relativeTo: .title2))
                        .padding(16)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
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
        }
    }

    private func setCard(_ set: SetSlot, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(Theme.textSecondary)
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        if !expandedSetIDs.insert(set.id).inserted { expandedSetIDs.remove(set.id) }
                    }
                } label: {
                    HStack {
                        Text("Set \(index + 1)")
                            .font(TimeMasterFont.black(17, relativeTo: .headline))
                        Text("\(set.leafExercises.count)")
                            .font(TimeMasterFont.caption().monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(expandedSetIDs.contains(set.id) ? 180 : 0))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set \(index + 1)")
                .accessibilityValue(expandedSetIDs.contains(set.id) ? "Expanded" : "Collapsed")
                Menu {
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
                    Image(systemName: "plus").frame(width: 44, height: 44)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Add exercise or edit set \(index + 1)")
            }
            .padding(.horizontal, 12)
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
            if expandedSetIDs.contains(set.id) {
                ForEach(Array(set.children.enumerated()), id: \.element.id) { exerciseIndex, exercise in
                    exerciseRow(exercise, setID: set.id, index: exerciseIndex)
                        .padding(.leading, 18)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Theme.separator).frame(width: 2).padding(.leading, 8)
                        }
                }
                HStack {
                    Label("Between sets", systemImage: "pause.fill")
                    Spacer()
                    DurationPickerView(seconds: slotValue(setID: set.id, exerciseID: nil, rest: true), range: 0...120, step: 1, compact: true)
                }
                .font(TimeMasterFont.caption())
                .padding(12)
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func exerciseRow(_ exercise: SetSlot, setID: UUID, index: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal").font(.caption)
                Button {
                    if let id = exercise.exercisePageID { onOpenPage?(id) }
                } label: {
                    BundleExerciseThumbnail(slot: exercise, size: 42)
                }
                .buttonStyle(.plain)
                .disabled(exercise.exercisePageID == nil || onOpenPage == nil)
                .accessibilityLabel("Open \(exercise.displayName)")
                Text(exercise.displayName)
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DurationPickerView(seconds: slotValue(setID: setID, exerciseID: exercise.id, rest: false), range: 1...600, step: 1, compact: true)
                Menu {
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
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Actions for \(exercise.displayName)")
            }
            HStack {
                Label("Rest", systemImage: "pause.fill")
                Spacer()
                DurationPickerView(seconds: slotValue(setID: setID, exerciseID: exercise.id, rest: true), range: 0...120, step: 1, compact: true)
            }
            .font(TimeMasterFont.caption())
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(10)
        .background(Theme.toolbarOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
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
                    } else {
                        set.children[index].duration = value
                    }
                } else if rest {
                    set.restAfter = value
                    set.restRow?.duration = value
                }
            }
        }
    }

    private func mutateSet(_ id: UUID, _ change: (inout SetSlot) -> Void) {
        guard let index = section.slots.firstIndex(where: { $0.id == id }) else { return }
        change(&section.slots[index])
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
