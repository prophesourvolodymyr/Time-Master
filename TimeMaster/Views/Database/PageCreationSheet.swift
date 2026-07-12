import SwiftUI
import TimeMasterCore

struct PageCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutStore: WorkoutStore

    let existingPage: ExercisePage?
    let parentID: String?

    let onSave: (ExercisePageManifest, String?) -> Void

    @State private var title: String
    @State private var iconName: String = ""
    @State private var workoutType: WorkoutType? = nil
    @State private var markdownBody: String = ""
    @State private var tags: String = ""
    @State private var duration: Int = 30
    @State private var restAfter: Int = 0
    @State private var sets: Int = 1
    @State private var restBetweenSets: Int = 0
    @State private var linkURLsText: String = ""
    @State private var showIconPicker = false
    @State private var showDeleteConfirm = false

    init(page: ExercisePage? = nil, parentID: String? = nil, onSave: @escaping (ExercisePageManifest, String?) -> Void) {
        self.existingPage = page
        self.parentID = parentID
        self.onSave = onSave
        _title = State(initialValue: page?.manifest.title ?? "")
        _iconName = State(initialValue: page?.manifest.iconName ?? "")
        if let wt = page?.manifest.workoutType {
            _workoutType = State(initialValue: WorkoutType(id: wt.id, name: wt.name, iconName: wt.iconName, colorHex: wt.colorHex))
        }
        _markdownBody = State(initialValue: page?.manifest.markdownBody ?? "")
        _tags = State(initialValue: page?.manifest.tags.joined(separator: ", ") ?? "")
        _duration = State(initialValue: page?.manifest.duration ?? 30)
        _restAfter = State(initialValue: page?.manifest.restAfter ?? 0)
        _sets = State(initialValue: page?.manifest.sets ?? 1)
        _restBetweenSets = State(initialValue: page?.manifest.restBetweenSets ?? 0)
        _linkURLsText = State(initialValue: page?.manifest.linkURLs.joined(separator: "\n") ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        titleCard
                        iconCard
                        workoutTypeCard
                        timingCard
                        markdownCard
                        linksCard
                        tagsCard
                        if existingPage != nil { deleteCard }
                        saveButton
                    }
                    .padding(16)
                }
            }
            .navigationTitle(existingPage == nil ? "New Page" : "Edit Page")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerSheet(selectedIcon: $iconName)
            }
            .confirmationDialog(
                "Delete \"\(title)\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let p = existingPage else { return }
                    try? DatabaseStore.shared.deletePage(id: p.manifest.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This moves the page and all its children to trash.")
            }
        }
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title").font(.headline).foregroundColor(Theme.textPrimary)
            TextField("Page title", text: $title)
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(10)
                .foregroundColor(Theme.textPrimary)
        }
    }

    private var iconCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon").font(.headline).foregroundColor(Theme.textPrimary)
            Button { showIconPicker = true } label: {
                HStack {
                    if !iconName.isEmpty {
                        Image(systemName: iconName)
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        Text(iconName)
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(Theme.textSecondary)
                        Text("Choose SF Symbol")
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary.opacity(0.4))
                }
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(10)
            }
        }
    }

    private var workoutTypeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Type").font(.headline).foregroundColor(Theme.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                Button {
                    workoutType = nil
                } label: {
                    Text("None")
                        .font(.subheadline.weight(workoutType == nil ? .semibold : .regular))
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(workoutType == nil ? Color.white.opacity(0.2) : Theme.surface)
                        .cornerRadius(8)
                }
                ForEach(WorkoutType.all(custom: workoutStore.customWorkoutTypes), id: \.id) { type in
                    Button {
                        workoutType = type
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: type.iconName).font(.system(size: 11))
                            Text(type.name)
                        }
                        .font(.subheadline.weight(workoutType == type ? .semibold : .regular))
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(workoutType == type ? Color.white.opacity(0.2) : Theme.surface)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var timingCard: some View {
        if workoutType != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text("Workout Config").font(.headline).foregroundColor(Theme.textPrimary)
                VStack(spacing: 8) {
                    stepperRow(label: "Duration", value: $duration, range: 5...600, step: 5, unit: "s")
                    stepperRow(label: "Rest After", value: $restAfter, range: 0...120, step: 5, unit: "s")
                    stepperRow(label: "Sets", value: $sets, range: 1...20, step: 1, unit: "")
                    stepperRow(label: "Rest Between Sets", value: $restBetweenSets, range: 0...120, step: 5, unit: "s")
                }
            }
        }
    }

    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack {
            Text(label).foregroundColor(Theme.textPrimary)
            Spacer()
            Text("\(value.wrappedValue)\(unit)").foregroundColor(Theme.textSecondary).frame(minWidth: 40, alignment: .trailing)
            Stepper("", value: value, in: range, step: step).labelsHidden()
        }
        .padding(14)
        .background(Theme.surface)
        .cornerRadius(10)
    }

    private var markdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Guide (Markdown)").font(.headline).foregroundColor(Theme.textPrimary)
                Spacer()
                Text("CommonMark")
                    .font(.caption2).foregroundColor(Theme.textSecondary)
            }
            ZStack(alignment: .topLeading) {
                if markdownBody.isEmpty {
                    Text("Write your guide here…\n\nSupports **bold**, *italic*, `code`, # Headings, - lists")
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                        .padding(.top, 14).padding(.leading, 14)
                        .allowsHitTesting(false)
                        .font(.body)
                }
                TextEditor(text: $markdownBody)
                    .frame(minHeight: 160).padding(10)
                    .scrollContentBackground(.hidden).foregroundColor(Theme.textPrimary)
            }
            .background(Theme.surface).cornerRadius(10)
        }
    }

    private var linksCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("External Links").font(.headline).foregroundColor(Theme.textPrimary)
            ZStack(alignment: .topLeading) {
                if linkURLsText.isEmpty {
                    Text("One URL per line\nYouTube, Instagram, TikTok, web…")
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                        .padding(.top, 14).padding(.leading, 14)
                        .allowsHitTesting(false)
                        .font(.body)
                }
                TextEditor(text: $linkURLsText)
                    .frame(minHeight: 80).padding(10)
                    .scrollContentBackground(.hidden).foregroundColor(Theme.textPrimary)
            }
            .background(Theme.surface).cornerRadius(10)
        }
    }

    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(.headline).foregroundColor(Theme.textPrimary)
            TextField("e.g., beginner, mobility, warmup", text: $tags)
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(10)
                .foregroundColor(Theme.textPrimary)
            Text("Comma-separated")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .padding(.leading, 4)
        }
    }

    @ViewBuilder
    private var deleteCard: some View {
        if existingPage != nil {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Text("Delete Page")
                    .font(.headline).foregroundColor(.red)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Theme.surface).cornerRadius(12)
            }
        }
    }

    private var saveButton: some View {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        return Button {
            savePage()
        } label: {
            Text(existingPage == nil ? "Create Page" : "Save Changes")
                .font(.headline)
                .foregroundColor(trimmed.isEmpty ? Color.white.opacity(0.3) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(trimmed.isEmpty ? Theme.surface : Color.white)
                .cornerRadius(12)
        }
        .disabled(trimmed.isEmpty)
    }

    private func savePage() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let parsedTags = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let parsedURLs = linkURLsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var coreWT: TimeMasterCore.WorkoutType? = nil
        if let wt = workoutType {
            coreWT = TimeMasterCore.WorkoutType(id: wt.id, name: wt.name, iconName: wt.iconName, colorHex: wt.colorHex)
        }

        var manifest: ExercisePageManifest
        if let existing = existingPage {
            manifest = existing.manifest
            manifest.title = trimmedTitle
            manifest.iconName = iconName.isEmpty ? nil : iconName
            manifest.workoutType = coreWT
            manifest.markdownBody = markdownBody
            manifest.duration = workoutType != nil ? duration : nil
            manifest.restAfter = workoutType != nil ? restAfter : nil
            manifest.sets = workoutType != nil ? sets : nil
            manifest.restBetweenSets = workoutType != nil ? restBetweenSets : nil
            manifest.tags = parsedTags
            manifest.linkURLs = parsedURLs
            manifest.updatedAt = Date()
        } else {
            manifest = ExercisePageManifest(
                title: trimmedTitle,
                iconName: iconName.isEmpty ? nil : iconName,
                markdownBody: markdownBody,
                linkURLs: parsedURLs,
                workoutType: coreWT,
                duration: workoutType != nil ? duration : nil,
                restAfter: workoutType != nil ? restAfter : nil,
                sets: workoutType != nil ? sets : nil,
                restBetweenSets: workoutType != nil ? restBetweenSets : nil,
                tags: parsedTags,
                parentID: parentID
            )
        }

        onSave(manifest, parentID)
        dismiss()
    }
}

private struct IconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String

    private let icons: [(String, String)] = [
        ("figure.strengthtraining.traditional", "Strength"),
        ("figure.cooldown", "Stretch"),
        ("heart.fill", "Cardio"),
        ("flame.fill", "HIIT"),
        ("figure.mind.and.body", "Yoga"),
        ("figure.run", "Run"),
        ("figure.walk", "Walk"),
        ("figure.step.training", "Step"),
        ("figure.core.training", "Core"),
        ("figure.mixed.cardio", "Mixed"),
        ("dumbbell.fill", "Dumbbell"),
        ("figure.strengthtraining.functional", "Functional"),
        ("figure.cross.training", "Cross"),
        ("figure.pilates", "Pilates"),
        ("figure.dance", "Dance"),
        ("figure.taichi", "Tai Chi"),
        ("figure.boxing", "Boxing"),
        ("figure.wrestling", "Wrestling"),
        ("figure.open.water.swim", "Swim"),
        ("figure.outdoor.cycle", "Cycle"),
        ("figure.hiking", "Hike"),
        ("figure.jumprope", "Jump Rope"),
        ("figure.rolling", "Rolling"),
        ("star.fill", "Star"),
        ("book.fill", "Book"),
        ("doc.text.fill", "Doc"),
        ("note.text", "Note"),
        ("folder.fill", "Folder"),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(icons, id: \.0) { icon in
                            Button {
                                selectedIcon = icon.0
                                dismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: icon.0)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedIcon == icon.0 ? .white : Theme.textSecondary)
                                        .frame(height: 32)
                                    Text(icon.1)
                                        .font(.system(size: 10))
                                        .foregroundColor(selectedIcon == icon.0 ? .white : Theme.textSecondary)
                                        .lineLimit(1)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIcon == icon.0 ? Color.white.opacity(0.15) : Theme.surface)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Choose Icon")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
            }
        }
    }
}
