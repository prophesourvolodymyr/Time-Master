import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif

private struct PendingPageMedia {
    let temporaryURL: URL

    var filename: String { temporaryURL.lastPathComponent }
}

private struct PageCreationLinkRow: Identifiable, Equatable {
    let id: UUID
    var url: String
    var metadata: LinkMetadata?
    var isLoading = false

    init(id: UUID = UUID(), url: String, metadata: LinkMetadata? = nil) {
        self.id = id
        self.url = url
        self.metadata = metadata
    }
}

struct PageCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var databaseStore: DatabaseStore

    let existingPage: ExercisePage?
    let onSave: (ExercisePageManifest, String?) throws -> Void
    let onSaveWithMedia: ((ExercisePageManifest, String?, Data?, [(filename: String, data: Data)]) throws -> Void)?

    @State private var pageKind: ExercisePageManifest.PageKind
    @State private var draftParentID: String?
    @State private var title: String
    @State private var workoutType: WorkoutType?
    @State private var markdownBody: String
    @State private var duration: Int
    @State private var prepareTime: Int
    @State private var restAfter: Int
    @State private var sets: Int
    @State private var restBetweenSets: Int
    @State private var dropSetTemplates: [PageDropSetTemplate]
    @State private var linkRows: [PageCreationLinkRow]
    @State private var mediaFilenames: [String]
    @State private var pendingMediaFiles: [PendingPageMedia] = []
    @State private var mediaPreviewThumbnails: [(filename: String, image: Image?)] = []
    @State private var draggedMediaFilename: String?
    @FocusState private var focusedDropSetID: String?
    @State private var showDropSetPicker = false
    @State private var showMediaPicker = false
    @State private var showDeleteConfirm = false
    @State private var showDraftList = false
    @State private var draftID: UUID
    @State private var didSavePage = false
    @State private var draftSavedMessage: String?
    @State private var saveErrorMessage: String?
    @State private var markdownEditorHeight: CGFloat = 180
    @State private var markdownResizeStartHeight: CGFloat?
    @State private var autosaveTask: Task<Void, Never>?
    #if os(iOS)
    @State private var pendingMediaItems: [PhotosPickerItem] = []
    #endif

    init(
        page: ExercisePage? = nil,
        parentID: String? = nil,
        leafFirst: Bool = false,
        onSave: @escaping (ExercisePageManifest, String?) throws -> Void,
        onSaveWithMedia: ((ExercisePageManifest, String?, Data?, [(filename: String, data: Data)]) throws -> Void)? = nil
    ) {
        self.existingPage = page
        self.onSave = onSave
        self.onSaveWithMedia = onSaveWithMedia

        let resolvedParentID = parentID ?? page?.manifest.parentID
        let initialKind = page?.manifest.pageKind ?? (leafFirst || resolvedParentID != nil ? .leaf : .container)
        let initialLinks = Self.makeLinkRows(
            urls: page?.manifest.linkURLs ?? [],
            metadata: page?.manifest.linkMetadata ?? []
        )
        let initialMedia = page.map(Self.orderedMediaFilenames) ?? []

        _pageKind = State(initialValue: initialKind)
        _draftParentID = State(initialValue: resolvedParentID)
        _title = State(initialValue: page?.manifest.title ?? "")
        if let type = page?.manifest.workoutType {
            _workoutType = State(initialValue: WorkoutType(
                id: type.id,
                name: type.name,
                iconName: type.iconName,
                colorHex: type.colorHex
            ))
        } else {
            _workoutType = State(initialValue: nil)
        }
        _markdownBody = State(initialValue: page?.manifest.markdownBody ?? "")
        _duration = State(initialValue: page?.manifest.duration ?? 30)
        _prepareTime = State(initialValue: page?.manifest.prepareTime ?? 4)
        _restAfter = State(initialValue: page?.manifest.restAfter ?? 0)
        _sets = State(initialValue: page?.manifest.sets ?? 1)
        _restBetweenSets = State(initialValue: page?.manifest.restBetweenSets ?? 0)
        _dropSetTemplates = State(initialValue: page?.manifest.dropSetTemplates ?? [])
        _linkRows = State(initialValue: initialLinks)
        _mediaFilenames = State(initialValue: initialMedia)
        _draftID = State(initialValue: UUID())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        titleCard
                        if let saveErrorMessage {
                            Text(saveErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        pageKindCard
                        mediaCard
                        if pageKind == .container && draftParentID == nil {
                            workoutTypeCard
                        } else if draftParentID != nil {
                            inheritedWorkoutTypeCard
                        }
                        if pageKind == .leaf {
                            timingCard
                            dropSetTemplatesCard
                        }
                        markdownCard
                        linksCard
                        if existingPage != nil {
                            deleteCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
            .overlay(alignment: .bottom) {
                if let draftSavedMessage {
                    Text(draftSavedMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Theme.surface2, in: Capsule())
                        .overlay(Capsule().stroke(Theme.primary.opacity(0.7), lineWidth: 1))
                        .padding(.bottom, 84)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(existingPage == nil ? "New Page" : "Edit Page")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                        .tint(Theme.primary)
                }
                if existingPage == nil {
                    AppToolbar.iconItem(placement: .primaryAction) {
                        Button {
                            PageCreationDraftStore.shared.reload()
                            showDraftList = true
                        } label: {
                            Image(systemName: "doc.badge.clock")
                        }
                        .foregroundStyle(Theme.primary)
                        .accessibilityLabel("Open page drafts")
                    }
                }
            }
            .sheet(isPresented: $showDraftList) {
                PageCreationDraftListSheet { draft in
                    apply(draft: draft)
                    showDraftList = false
                }
            }
            .sheet(isPresented: $showDropSetPicker) {
                DatabasePageBrowserSheet(
                    workout: Workout(name: "Drop Set Templates"),
                    onAdd: { page, _, _, _, _, _, _ in
                        addDatabaseDropSet(from: page)
                        showDropSetPicker = false
                    },
                    onAddBundle: { sources, _, _, _, _, _, _ in
                        for source in sources {
                            guard case .page(let page) = source else { continue }
                            addDatabaseDropSet(from: page)
                        }
                        showDropSetPicker = false
                    }
                )
                .environmentObject(databaseStore)
                .environmentObject(workoutStore)
            }
            #if os(iOS)
            .photosPicker(
                isPresented: $showMediaPicker,
                selection: $pendingMediaItems,
                maxSelectionCount: max(1, 20 - mediaFilenames.count),
                matching: .any(of: [.images, .videos])
            )
            .onChange(of: pendingMediaItems) { items in
                guard !items.isEmpty else { return }
                handleMediaPicks(items)
            }
            #else
            .fileImporter(
                isPresented: $showMediaPicker,
                allowedContentTypes: [.image, .movie],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                urls.forEach(stageMedia)
            }
            #endif
            .confirmationDialog(
                "Delete \"\(title)\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let page = existingPage else { return }
                    try? databaseStore.deletePage(id: page.manifest.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This moves the page and all its children to trash.")
            }
            .task {
                PageCreationDraftStore.shared.reload()
                loadMediaPreviews()
                refreshLinkMetadata()
            }
            .onChange(of: draftFingerprint) { _ in
                scheduleAutosave()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .inactive || phase == .background {
                    persistDraftIfNeeded()
                }
            }
            .onDisappear {
                autosaveTask?.cancel()
                persistDraftIfNeeded()
            }
        }
    }

    private var titleCard: some View {
        formCard {
            formHeading("Title", required: true)
            TextField("Page title", text: $title)
                .textFieldStyle(.plain)
                .padding(13)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private var pageKindCard: some View {
        formCard {
            formHeading("Page Type", required: true)
            HStack(spacing: 8) {
                kindButton(.container, title: "Container", systemImage: "square.stack.3d.up")
                kindButton(.leaf, title: "Exercise", systemImage: "figure.run")
            }
            Text(draftParentID == nil
                 ? "Root pages can be containers or exercises."
                 : "This page is inside a container and can hold its own media and content.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func kindButton(
        _ kind: ExercisePageManifest.PageKind,
        title: String,
        systemImage: String
    ) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                pageKind = kind
            }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(pageKind == kind ? .semibold : .regular))
                .foregroundStyle(pageKind == kind ? .black : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(pageKind == kind ? Theme.primary : Theme.surface, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private var mediaCard: some View {
        formCard {
            HStack(alignment: .firstTextBaseline) {
                formHeading("Media", optional: true)
                Spacer()
                Text("First item = Cover")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }

            if mediaFilenames.isEmpty {
                Text("Add photos or videos. The first item becomes the cover and stays visible in the gallery.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(mediaFilenames, id: \.self) { filename in
                            mediaTile(filename: filename, isCover: filename == mediaFilenames.first)
                                .onDrag {
                                    draggedMediaFilename = filename
                                    return NSItemProvider(object: filename as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: PageMediaDropDelegate(
                                        targetFilename: filename,
                                        items: $mediaFilenames,
                                        draggedFilename: $draggedMediaFilename
                                    )
                                )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if mediaFilenames.count < 20 {
                Button {
                    showMediaPicker = true
                } label: {
                    Label("Add Media (\(mediaFilenames.count)/20)", systemImage: "plus.rectangle.on.rectangle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(OrangeFormButtonStyle())
            }
        }
    }

    private func mediaTile(filename: String, isCover: Bool) -> some View {
        let width: CGFloat = isCover ? 176 : 138
        let aspectRatio: CGFloat = isCover ? 1 : 1080.0 / 1480.0

        return ZStack(alignment: .topTrailing) {
            Group {
                if let preview = mediaPreviewThumbnails.first(where: { $0.filename == filename })?.image {
                    preview
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.surface)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(Theme.textSecondary.opacity(0.45))
                        }
                }
            }
            .frame(width: width, height: width / aspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCover ? Theme.primary : Color.white.opacity(0.08), lineWidth: isCover ? 2 : 1)
            }

            if isCover {
                Label("Cover", systemImage: "pin.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Theme.primary, in: Capsule())
                    .padding(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                removeMedia(filename: filename)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.45))
                    .padding(7)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove media")
        }
        .contentShape(Rectangle())
    }

    private var workoutTypeCard: some View {
        formCard {
            formHeading("Workout Type", optional: true)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                Button {
                    workoutType = nil
                } label: {
                    Text("None")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OrangeChoiceButtonStyle(isSelected: workoutType == nil))

                ForEach(WorkoutType.all(custom: workoutStore.customWorkoutTypes), id: \.id) { type in
                    Button {
                        workoutType = type
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: type.iconName)
                            Text(type.name)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OrangeChoiceButtonStyle(isSelected: workoutType == type))
                }
            }
        }
    }

    private var inheritedWorkoutTypeCard: some View {
        Group {
            if let inheritedWorkoutType {
                HStack(spacing: 8) {
                    Image(systemName: inheritedWorkoutType.iconName)
                        .foregroundStyle(Color(hex: inheritedWorkoutType.colorHex))
                    Text("Uses \(inheritedWorkoutType.name) from its container")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var timingCard: some View {
        formCard {
            formHeading("Workout Config", required: true)
            VStack(spacing: 8) {
                stepperRow(label: "Duration", value: $duration, range: 5...600, step: 5, unit: "s", required: true)
                stepperRow(label: "Prepare Time", value: $prepareTime, range: 0...30, step: 1, unit: "s", optional: true)
                stepperRow(label: "Sets", value: $sets, range: 1...20, step: 1, unit: "", required: true)
                if sets > 1 {
                    stepperRow(label: "Rest Between Sets", value: $restBetweenSets, range: 0...120, step: 5, unit: "s", optional: true)
                    stepperRow(label: "Big Rest", value: $restAfter, range: 0...120, step: 5, unit: "s", optional: true)
                } else {
                    stepperRow(label: "Rest", value: $restAfter, range: 0...120, step: 5, unit: "s", optional: true)
                }
            }
        }
    }

    private func stepperRow(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String,
        required: Bool = false,
        optional: Bool = false
    ) -> some View {
        HStack {
            formHeading(label, required: required, optional: optional)
            Spacer()
            Text("\(value.wrappedValue)\(unit)")
                .foregroundStyle(Theme.primary)
                .monospacedDigit()
                .frame(minWidth: 42, alignment: .trailing)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .tint(Theme.primary)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private var dropSetTemplatesCard: some View {
        formCard {
            HStack(alignment: .firstTextBaseline) {
                formHeading("Drop Sets", optional: true)
                Spacer()
                Button {
                    addManualDropSet()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.primary)
                .accessibilityLabel("Add manual drop set")

                Button {
                    showDropSetPicker = true
                } label: {
                    Image(systemName: "externaldrive.badge.plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.primary)
                .accessibilityLabel("Add drop set from database")
            }

            if dropSetTemplates.isEmpty {
                Text("Use + for a typed drop set or the database button to choose an exercise page.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach($dropSetTemplates) { $template in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: template.exerciseID.isEmpty ? "pencil" : "externaldrive")
                                .foregroundStyle(Theme.primary)
                            TextField("Drop-set exercise name", text: $template.name)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Theme.textPrimary)
                                .focused($focusedDropSetID, equals: template.id)
                            Spacer()
                            Button(role: .destructive) {
                                dropSetTemplates.removeAll { $0.id == template.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove drop set")
                        }

                        HStack {
                            Text("After set")
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Stepper(
                                "",
                                value: $template.setIndex,
                                in: 0...max(0, sets - 1)
                            )
                            .labelsHidden()
                            .tint(Theme.primary)
                            Text("\(template.setIndex + 1)")
                                .foregroundStyle(Theme.primary)
                                .monospacedDigit()
                                .frame(minWidth: 24, alignment: .trailing)
                        }

                        HStack(spacing: 12) {
                            stepperValue("Duration", value: $template.duration, range: 5...600, step: 5, unit: "s")
                            stepperValue("Rest", value: $template.restAfter, range: 0...120, step: 5, unit: "s")
                        }
                    }
                    .padding(12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func stepperValue(
        _ label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 4) {
                Text("\(value.wrappedValue)\(unit)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                    .monospacedDigit()
                Stepper("", value: value, in: range, step: step)
                    .labelsHidden()
                    .scaleEffect(0.85, anchor: .trailing)
                    .tint(Theme.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var markdownCard: some View {
        formCard {
            HStack(alignment: .firstTextBaseline) {
                formHeading("Guide", optional: true)
                Spacer()
                Text("Markdown")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if markdownBody.isEmpty {
                        Text("Write a guide here… supports **bold**, *italic*, headings, and lists")
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary.opacity(0.65))
                            .padding(.top, 14)
                            .padding(.horizontal, 14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $markdownBody)
                        .frame(height: markdownEditorHeight)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(Theme.textPrimary)
                }

                HStack {
                    Text("Live Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                    Spacer()
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Resize markdown editor")
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if markdownResizeStartHeight == nil {
                                        markdownResizeStartHeight = markdownEditorHeight
                                    }
                                    let start = markdownResizeStartHeight ?? markdownEditorHeight
                                    markdownEditorHeight = min(600, max(150, start + value.translation.height))
                                }
                                .onEnded { _ in
                                    markdownResizeStartHeight = nil
                                }
                        )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                Group {
                    if markdownBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Rendered markdown will appear here as you type.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        MarkdownTextView(text: markdownBody)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.background.opacity(0.55))
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var linksCard: some View {
        formCard {
            HStack(alignment: .firstTextBaseline) {
                formHeading("External Links", optional: true)
                Spacer()
                Button {
                    linkRows.append(PageCreationLinkRow(url: ""))
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.primary)
                .accessibilityLabel("Add external link")
            }

            if linkRows.isEmpty {
                Text("Paste one link per row. A live preview appears when the URL responds.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach($linkRows) { $row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("Paste URL", text: $row.url)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Theme.textPrimary)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                #endif
                                .onChange(of: row.url) { _ in
                                    refreshLinkMetadata(for: row.id)
                                }
                            if row.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Theme.primary)
                            }
                            Button {
                                linkRows.removeAll { $0.id == row.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityLabel("Remove external link")
                        }
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))

                        if let metadata = row.metadata {
                            PageCreationLinkPreview(metadata: metadata)
                        } else if !row.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !row.isLoading {
                            Text("Enter a valid http(s) link to load its preview.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Button {
                            insertLink(after: row.id)
                        } label: {
                            Label("Add link below", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(OrangeFormButtonStyle())
                    }
                }
            }
        }
    }

    private var deleteCard: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Text("Delete Page")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if existingPage == nil {
                Button {
                    saveDraft()
                } label: {
                    Label("Draft", systemImage: "doc.badge.clock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OrangeSecondaryButtonStyle())
                .disabled(!canDraft)
            }

            Button {
                savePage()
            } label: {
                Text(existingPage == nil ? "Create Page" : "Save Changes")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OrangePrimaryButtonStyle())
            .disabled(!canSave)
        }
        .padding(.horizontal, 16)
        .padding(.top, 11)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.primary.opacity(0.55))
                .frame(height: 1)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var draftFingerprint: String {
        [
            title,
            pageKind.rawValue,
            draftParentID ?? "",
            markdownBody,
            "\(duration)",
            "\(prepareTime)",
            "\(restAfter)",
            "\(sets)",
            "\(restBetweenSets)",
            dropSetTemplates.map { "\($0.id):\($0.exerciseID):\($0.name):\($0.setIndex):\($0.duration):\($0.restAfter)" }.joined(separator: "|"),
            linkRows.map { "\($0.id):\($0.url)" }.joined(separator: "|"),
            mediaFilenames.joined(separator: "|")
        ].joined(separator: "\u{1F}")
    }

    private func scheduleAutosave() {
        guard existingPage == nil, !didSavePage else { return }
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            persistDraftIfNeeded()
        }
    }

    private var canDraft: Bool {
        existingPage == nil && hasDraftContent
    }

    private var hasDraftContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !markdownBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !linkRows.allSatisfy { $0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || !mediaFilenames.isEmpty
            || pageKind == .leaf
            || !dropSetTemplates.isEmpty
    }

    private var inheritedWorkoutType: TimeMasterCore.WorkoutType? {
        guard let parentID = draftParentID,
              let parentUUID = UUID(uuidString: parentID) else { return nil }
        return databaseStore.page(id: parentUUID)?.effectiveWorkoutType
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
    }

    @ViewBuilder
    private func formHeading(_ title: String, required: Bool = false, optional: Bool = false) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if required {
                Text("Required")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            } else if optional {
                Text("Optional")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func addManualDropSet() {
        let template = PageDropSetTemplate(
            setIndex: max(0, sets - 1),
            exerciseID: "",
            name: "",
            duration: 30,
            restAfter: 0
        )
        dropSetTemplates.append(template)
        focusedDropSetID = template.id
    }

    private func addDatabaseDropSet(from page: ExercisePage) {
        dropSetTemplates.append(
            PageDropSetTemplate(
                setIndex: max(0, sets - 1),
                exerciseID: page.manifest.id,
                name: page.manifest.title,
                duration: page.manifest.duration ?? 30,
                restAfter: page.manifest.restAfter ?? 0
            )
        )
    }

    private func removeMedia(filename: String) {
        if let page = existingPage {
            try? DatabaseManager.shared.removeMediaFromPage(pageID: page.manifest.id, filename: filename)
            databaseStore.reload()
        }
        mediaFilenames.removeAll { $0 == filename }
        mediaPreviewThumbnails.removeAll { $0.filename == filename }
        pendingMediaFiles.removeAll { pending in
            guard pending.filename == filename else { return false }
            if pending.temporaryURL.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
                try? FileManager.default.removeItem(at: pending.temporaryURL)
            }
            return true
        }
    }

    private func saveDraft() {
        persistDraftIfNeeded(showConfirmation: true)
    }

    private func persistDraftIfNeeded(showConfirmation: Bool = false) {
        guard existingPage == nil, !didSavePage, hasDraftContent else { return }
        let draft = makeDraft()
        let sources = Dictionary(uniqueKeysWithValues: pendingMediaFiles.map { ($0.filename, $0.temporaryURL) })
        do {
            try PageCreationDraftStore.shared.save(draft, mediaSources: sources)
            if showConfirmation {
                withAnimation(.easeOut(duration: 0.2)) {
                    draftSavedMessage = "Draft saved"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        draftSavedMessage = nil
                    }
                }
            }
        } catch {
            saveErrorMessage = "Could not save draft: \(error.localizedDescription)"
        }
    }

    private func makeDraft() -> PageCreationDraft {
        let now = Date()
        let createdAt = PageCreationDraftStore.shared.drafts.first(where: { $0.id == draftID })?.createdAt ?? now
        let links = linkRows.compactMap { row -> (String, LinkMetadata?)? in
            let url = normalizedLinkURL(row.url)
            return url.isEmpty ? nil : (url, row.metadata)
        }
        let normalizedDropSets = normalizedDropSetTemplates()

        return PageCreationDraft(
            id: draftID,
            title: title,
            pageKind: pageKind,
            parentID: draftParentID,
            workoutType: workoutType.map {
                TimeMasterCore.WorkoutType(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex)
            },
            markdownBody: markdownBody,
            duration: duration,
            prepareTime: prepareTime,
            restAfter: restAfter,
            sets: sets,
            restBetweenSets: restBetweenSets,
            dropSetTemplates: normalizedDropSets,
            linkURLs: links.map(\.0),
            linkMetadata: links.map { $0.1 ?? LinkMetadata(url: $0.0) },
            mediaFilenames: mediaFilenames,
            createdAt: createdAt,
            updatedAt: now
        )
    }

    private func savePage() {
        guard canSave else { return }
        let mediaData = mediaFilenames.compactMap { filename -> (filename: String, data: Data)? in
            guard let pending = pendingMediaFiles.first(where: { $0.filename == filename }),
                  let data = try? Data(contentsOf: pending.temporaryURL) else {
                return nil
            }
            return (filename: filename, data: data)
        }
        var manifest = makeManifest()
        if existingPage == nil {
            manifest.mediaFilenames = []
        }

        do {
            if existingPage == nil, let onSaveWithMedia {
                try onSaveWithMedia(manifest, draftParentID, nil, mediaData)
            } else {
                try onSave(manifest, draftParentID)
                if existingPage == nil && !mediaData.isEmpty {
                    uploadMediaAfterFallbackSave(pageID: manifest.id, mediaData: mediaData)
                }
            }
            didSavePage = true
            autosaveTask?.cancel()
            if existingPage == nil {
                PageCreationDraftStore.shared.delete(id: draftID)
            }
            cleanupTemporaryMedia()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func makeManifest() -> ExercisePageManifest {
        let links = linkRows.compactMap { row -> (String, LinkMetadata?)? in
            let url = normalizedLinkURL(row.url)
            return url.isEmpty ? nil : (url, row.metadata)
        }
        let normalizedDropSets = normalizedDropSetTemplates()
        let coreWorkoutType: TimeMasterCore.WorkoutType? = pageKind == .container && draftParentID == nil
            ? workoutType.map {
                TimeMasterCore.WorkoutType(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex)
            }
            : nil
        let restBetweenSetsValue = pageKind == .leaf && sets > 1 ? restBetweenSets : nil

        if let existingPage {
            var manifest = existingPage.manifest
            manifest.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            manifest.pageKind = pageKind
            manifest.parentID = draftParentID
            manifest.coverImageFilename = nil
            manifest.iconName = nil
            manifest.workoutType = coreWorkoutType
            manifest.markdownBody = markdownBody
            manifest.mediaFilenames = mediaFilenames
            manifest.linkURLs = links.map(\.0)
            manifest.linkMetadata = links.map { $0.1 ?? LinkMetadata(url: $0.0) }
            manifest.duration = pageKind == .leaf ? duration : nil
            manifest.prepareTime = pageKind == .leaf ? prepareTime : nil
            manifest.restAfter = pageKind == .leaf ? restAfter : nil
            manifest.sets = pageKind == .leaf ? sets : nil
            manifest.restBetweenSets = restBetweenSetsValue
            manifest.dropSetTemplates = pageKind == .leaf ? normalizedDropSets : []
            manifest.childIDs = pageKind == .container ? existingPage.manifest.childIDs : []
            manifest.updatedAt = Date()
            return manifest
        }

        return ExercisePageManifest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            pageKind: pageKind,
            iconName: nil,
            markdownBody: markdownBody,
            mediaFilenames: mediaFilenames,
            linkURLs: links.map(\.0),
            linkMetadata: links.map { $0.1 ?? LinkMetadata(url: $0.0) },
            workoutType: coreWorkoutType,
            duration: pageKind == .leaf ? duration : nil,
            restAfter: pageKind == .leaf ? restAfter : nil,
            prepareTime: pageKind == .leaf ? prepareTime : nil,
            sets: pageKind == .leaf ? sets : nil,
            restBetweenSets: restBetweenSetsValue,
            dropSetTemplates: pageKind == .leaf ? normalizedDropSets : [],
            parentID: draftParentID
        )
    }

    private func normalizedDropSetTemplates() -> [PageDropSetTemplate] {
        dropSetTemplates.map {
            PageDropSetTemplate(
                id: $0.id,
                setIndex: min(max(0, $0.setIndex), max(0, sets - 1)),
                exerciseID: $0.exerciseID,
                name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                duration: $0.duration,
                restAfter: $0.restAfter
            )
        }
    }

    private func uploadMediaAfterFallbackSave(
        pageID: String,
        mediaData: [(filename: String, data: Data)]
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            for (_, data) in mediaData {
                let temporaryURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".jpg")
                do {
                    try data.write(to: temporaryURL)
                    _ = try DatabaseManager.shared.uploadMediaToPage(pageID: pageID, sourceURL: temporaryURL)
                } catch {}
                try? FileManager.default.removeItem(at: temporaryURL)
            }
            databaseStore.reload()
        }
    }

    private func cleanupTemporaryMedia() {
        for pending in pendingMediaFiles where pending.temporaryURL.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
            try? FileManager.default.removeItem(at: pending.temporaryURL)
        }
    }

    private func apply(draft: PageCreationDraft) {
        draftID = draft.id
        title = draft.title
        pageKind = draft.pageKind
        draftParentID = draft.parentID
        workoutType = draft.workoutType.map {
            WorkoutType(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex)
        }
        markdownBody = draft.markdownBody
        duration = draft.duration
        prepareTime = draft.prepareTime
        restAfter = draft.restAfter
        sets = max(1, draft.sets)
        restBetweenSets = draft.restBetweenSets
        dropSetTemplates = draft.dropSetTemplates
        linkRows = Self.makeLinkRows(urls: draft.linkURLs, metadata: draft.linkMetadata)

        let availableMedia = draft.mediaFilenames.filter { filename in
            let url = PageCreationDraftStore.shared.mediaURL(for: draft, filename: filename)
            return FileManager.default.fileExists(atPath: url.path)
        }
        mediaFilenames = availableMedia
        pendingMediaFiles = availableMedia.map { filename in
            PendingPageMedia(temporaryURL: PageCreationDraftStore.shared.mediaURL(for: draft, filename: filename))
        }
        mediaPreviewThumbnails = []
        loadMediaPreviews()
        refreshLinkMetadata()
    }

    private func loadMediaPreviews() {
        for (index, filename) in mediaFilenames.enumerated() {
            let url: URL?
            if let pending = pendingMediaFiles.first(where: { $0.filename == filename }) {
                url = pending.temporaryURL
            } else if let page = existingPage {
                url = page.mediaURLs[safe: index]
            } else {
                url = nil
            }
            loadMediaPreview(filename: filename, url: url)
        }
    }

    private func loadMediaPreview(filename: String, url: URL?) {
        guard let url else { return }
        Task {
            let image = await PhotoManager.shared.asyncLoadImage(from: url)
            guard let image else { return }
            #if os(iOS)
            let preview = Image(uiImage: image)
            #else
            let preview = Image(nsImage: image)
            #endif
            await MainActor.run {
                mediaPreviewThumbnails.removeAll { $0.filename == filename }
                mediaPreviewThumbnails.append((filename: filename, image: preview))
            }
        }
    }

    #if os(iOS)
    private func handleMediaPicks(_ items: [PhotosPickerItem]) {
        Task { @MainActor in
            for item in items where mediaFilenames.count < 20 {
                let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .audiovisualContent) }
                if isVideo, let movie = try? await item.loadTransferable(type: MovieFile.self) {
                    stageMedia(movie.url)
                } else if let data = try? await item.loadTransferable(type: Data.self) {
                    stageMedia(data: data, pathExtension: "jpg")
                }
            }
            pendingMediaItems = []
        }
    }
    #endif

    private func stageMedia(data: Data, pathExtension: String) {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + pathExtension)
        do {
            try data.write(to: temporaryURL)
            stageMedia(temporaryURL)
            try? FileManager.default.removeItem(at: temporaryURL)
        } catch {
            saveErrorMessage = "Could not stage media: \(error.localizedDescription)"
        }
    }

    private func stageMedia(_ sourceURL: URL) {
        guard mediaFilenames.count < 20 else { return }
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-" + (sourceURL.lastPathComponent.isEmpty ? "media.jpg" : sourceURL.lastPathComponent))
        do {
            try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
            if let page = existingPage {
                let uploaded = try DatabaseManager.shared.uploadMediaToPage(pageID: page.manifest.id, sourceURL: temporaryURL)
                if !mediaFilenames.contains(uploaded) {
                    mediaFilenames.append(uploaded)
                    databaseStore.updatePageMedia(pageID: page.manifest.id, mediaFilenames: [uploaded])
                    let mediaURL = try? DatabaseManager.shared.pageMediaURL(pageID: page.manifest.id, filename: uploaded)
                    loadMediaPreview(filename: uploaded, url: mediaURL)
                }
                try? FileManager.default.removeItem(at: temporaryURL)
            } else {
                let filename = temporaryURL.lastPathComponent
                mediaFilenames.append(filename)
                pendingMediaFiles.append(PendingPageMedia(temporaryURL: temporaryURL))
                loadMediaPreview(filename: filename, url: temporaryURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            saveErrorMessage = "Could not add media: \(error.localizedDescription)"
        }
    }

    private func refreshLinkMetadata() {
        for row in linkRows where row.metadata == nil && !row.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            refreshLinkMetadata(for: row.id)
        }
    }

    private func refreshLinkMetadata(for rowID: UUID) {
        guard let row = linkRows.first(where: { $0.id == rowID }) else { return }
        let normalized = normalizedLinkURL(row.url)
        guard !normalized.isEmpty else {
            updateLinkRow(rowID) {
                $0.metadata = nil
                $0.isLoading = false
            }
            return
        }
        guard isValidHTTPURL(normalized) else {
            updateLinkRow(rowID) {
                $0.metadata = nil
                $0.isLoading = false
            }
            return
        }

        updateLinkRow(rowID) {
            $0.metadata = nil
            $0.isLoading = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let metadata = await LinkMetadataFetcher.fetchMetadata(for: [normalized], existing: [])
                .first
            await MainActor.run {
                guard let current = linkRows.first(where: { $0.id == rowID }), normalizedLinkURL(current.url) == normalized else { return }
                updateLinkRow(rowID) {
                    $0.metadata = metadata
                    $0.isLoading = false
                }
            }
        }
    }

    private func updateLinkRow(_ rowID: UUID, mutate: (inout PageCreationLinkRow) -> Void) {
        guard let index = linkRows.firstIndex(where: { $0.id == rowID }) else { return }
        mutate(&linkRows[index])
    }

    private func insertLink(after rowID: UUID) {
        guard let index = linkRows.firstIndex(where: { $0.id == rowID }) else { return }
        linkRows.insert(PageCreationLinkRow(url: ""), at: index + 1)
    }

    private func normalizedLinkURL(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) != nil {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    private func isValidHTTPURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              (components.scheme?.lowercased() == "http" || components.scheme?.lowercased() == "https"),
              let host = components.host,
              !host.isEmpty else {
            return false
        }
        return true
    }

    private static func makeLinkRows(urls: [String], metadata: [LinkMetadata]) -> [PageCreationLinkRow] {
        urls.enumerated().map { index, url in
            let candidate = metadata[safe: index]
            let hasPreview = candidate?.title != nil
                || candidate?.description != nil
                || candidate?.thumbnailURL != nil
            return PageCreationLinkRow(
                url: url,
                metadata: hasPreview ? candidate : nil
            )
        }
    }

    private static func orderedMediaFilenames(for page: ExercisePage) -> [String] {
        var filenames = page.manifest.mediaFilenames
        if let legacyCover = page.manifest.coverImageFilename, !filenames.contains(legacyCover) {
            filenames.insert(legacyCover, at: 0)
        }
        return filenames
    }
}

private struct PageCreationLinkPreview: View {
    let metadata: LinkMetadata

    var body: some View {
        HStack(spacing: 10) {
            if let thumbnailURL = metadata.thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        placeholder
                    }
                }
                .frame(width: 74, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                placeholder
                    .frame(width: 74, height: 54)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(metadata.title ?? URL(string: metadata.url)?.host ?? metadata.url)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                if let description = metadata.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                Text(metadata.url)
                    .font(.caption2)
                    .foregroundStyle(Theme.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.primary.opacity(0.22), lineWidth: 1))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Theme.primary.opacity(0.14))
            .overlay {
                Image(systemName: "link")
                    .foregroundStyle(Theme.primary)
            }
    }
}

private struct PageCreationDraftListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store: PageCreationDraftStore
    let onSelect: (PageCreationDraft) -> Void

    init(onSelect: @escaping (PageCreationDraft) -> Void) {
        self.onSelect = onSelect
        _store = ObservedObject(wrappedValue: PageCreationDraftStore.shared)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if store.drafts.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.badge.clock")
                            .font(.system(size: 38))
                            .foregroundStyle(Theme.primary)
                        Text("No drafts")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Drafts are kept for 30 days.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(store.drafts) { draft in
                            Button {
                                onSelect(draft)
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(Theme.primary.opacity(0.14))
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            Text(draft.pageKind == .leaf ? "E" : "C")
                                                .font(.headline.weight(.bold))
                                                .foregroundStyle(Theme.primary)
                                        }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(draft.title.isEmpty ? "Untitled page" : draft.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                            .lineLimit(1)
                                        Text("\(draft.pageKind == .leaf ? "Exercise" : "Container") · \(draft.mediaFilenames.count) media · \(draft.updatedAt, style: .relative)")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Theme.primary)
                                }
                                .padding(.vertical, 5)
                            }
                            .listRowBackground(Theme.surface)
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.delete(id: draft.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Drafts")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                        .tint(Theme.primary)
                }
            }
            .task { store.reload() }
        }
    }
}

private struct PageMediaDropDelegate: DropDelegate {
    let targetFilename: String
    @Binding var items: [String]
    @Binding var draggedFilename: String?

    func dropEntered(info: DropInfo) {
        guard let draggedFilename,
              draggedFilename != targetFilename,
              let from = items.firstIndex(of: draggedFilename),
              let to = items.firstIndex(of: targetFilename) else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedFilename = nil
        return true
    }
}

private struct OrangePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(isEnabled ? .black : Theme.textSecondary)
            .padding(.vertical, 14)
            .background(
                isEnabled
                    ? Theme.primary.opacity(configuration.isPressed ? 0.72 : 1)
                    : Theme.surface2,
                in: RoundedRectangle(cornerRadius: 11)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct OrangeSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? Theme.primary : Theme.textSecondary)
            .padding(.vertical, 13)
            .background(
                isEnabled
                    ? Theme.primary.opacity(configuration.isPressed ? 0.25 : 0.12)
                    : Theme.surface2,
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(isEnabled ? Theme.primary.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct OrangeFormButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? Theme.primary : Theme.textSecondary)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                isEnabled
                    ? Theme.primary.opacity(configuration.isPressed ? 0.22 : 0.1)
                    : Theme.surface2,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isEnabled ? Theme.primary.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct OrangeChoiceButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isEnabled ? (isSelected ? .black : Theme.textPrimary) : Theme.textSecondary)
            .padding(.vertical, 10)
            .background(
                isEnabled && isSelected ? Theme.primary : Theme.surface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled && isSelected ? Theme.primary : Color.white.opacity(0.08), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}
