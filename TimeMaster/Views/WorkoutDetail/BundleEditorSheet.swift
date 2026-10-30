import SwiftUI

struct BundleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Section
    @State private var inspectedPageID: UUID?
    private let isNew: Bool
    let onSave: (Section) -> Void

    init(section: Section? = nil, onSave: @escaping (Section) -> Void) {
        isNew = section == nil
        var value = section ?? Section(
            name: "Bundle", duration: 5, restBetweenSets: 10, customRestAfter: 30,
            prepareTime: 4, mode: .bundle,
            slots: [SetSlot(name: "Set 1", duration: 5, restAfter: 10, children: [])]
        )
        if section != nil { value.slots = value.bundleSets }
        _draft = State(initialValue: value)
        self.onSave = onSave
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.slots.isEmpty && draft.slots.allSatisfy { !$0.children.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    TextField("Bundle name", text: $draft.name)
                        .font(TimeMasterFont.black(22, relativeTo: .title2))
                        .textFieldStyle(.plain)
                        .padding(18)
                        .foregroundStyle(.black)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 18))
                    BundleSectionEditor(section: $draft, normalizesLegacy: false) { id in
                        inspectedPageID = id
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .timeMasterNavigationTitle(isNew ? "New Bundle" : "Edit Bundle")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Save") {
                        draft.sets = draft.slots.count
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: Binding(get: { inspectedPageID != nil }, set: { if !$0 { inspectedPageID = nil } })) {
                if let id = inspectedPageID {
                    WorkoutAttachmentBrowser(workout: Workout(name: draft.name, sections: [draft]), pageID: id)
                }
            }
        }
        .font(TimeMasterFont.body())
        .keyNavHost()
    }
}
