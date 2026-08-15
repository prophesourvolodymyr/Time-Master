import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif

private struct PendingPageMedia {
    let temporaryURL: URL
}

struct PageCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var databaseStore: DatabaseStore

    let existingPage: ExercisePage?
    let parentID: String?
    let leafFirst: Bool

    let onSave: (ExercisePageManifest, String?) throws -> Void
    let onSaveWithMedia: ((ExercisePageManifest, String?, Data?, [(filename: String, data: Data)]) throws -> Void)?

    @State private var title: String
    @State private var pageKind: ExercisePageManifest.PageKind
    @State private var iconName: String = ""
    @State private var workoutType: WorkoutType? = nil
    @State private var markdownBody: String = ""
    @State private var duration: Int = 30
    @State private var prepareTime: Int = 4
    @State private var restAfter: Int = 0
    @State private var sets: Int = 1
    @State private var restBetweenSets: Int = 0
    @State private var dropSetTemplates: [PageDropSetTemplate] = []
    @State private var linkURLsText: String = ""
    @State private var showIconPicker = false
    @State private var showDeleteConfirm = false
    @State private var showCoverPicker = false
    @State private var showMediaPicker = false
    @State private var showDropSetPicker = false
    @State private var coverImageFilename: String?
    @State private var mediaFilenames: [String] = []
    @State private var pendingCoverData: Data?
    @State private var pendingMediaFiles: [PendingPageMedia] = []
    @State private var saveErrorMessage: String?
    #if os(iOS)
    @State private var pendingCoverItem: PhotosPickerItem?
    @State private var pendingMediaItems: [PhotosPickerItem] = []
    #endif
    @State private var coverPreviewImage: Image?
    @State private var mediaPreviewThumbnails: [(filename: String, image: Image?)] = []

    init(
        page: ExercisePage? = nil,
        parentID: String? = nil,
        leafFirst: Bool = false,
        onSave: @escaping (ExercisePageManifest, String?) throws -> Void,
        onSaveWithMedia: ((ExercisePageManifest, String?, Data?, [(filename: String, data: Data)]) throws -> Void)? = nil
    ) {
        self.existingPage = page
        self.parentID = parentID ?? page?.manifest.parentID
        self.leafFirst = leafFirst
        self.onSave = onSave
        self.onSaveWithMedia = onSaveWithMedia
        _title = State(initialValue: page?.manifest.title ?? "")
        _pageKind = State(initialValue: page?.manifest.pageKind ?? (leafFirst || parentID != nil ? .leaf : .container))
        _iconName = State(initialValue: page?.manifest.iconName ?? "")
        if let wt = page?.manifest.workoutType {
            _workoutType = State(initialValue: WorkoutType(id: wt.id, name: wt.name, iconName: wt.iconName, colorHex: wt.colorHex))
        }
        _markdownBody = State(initialValue: page?.manifest.markdownBody ?? "")
        _duration = State(initialValue: page?.manifest.duration ?? 30)
        _restAfter = State(initialValue: page?.manifest.restAfter ?? 0)
        _prepareTime = State(initialValue: page?.manifest.prepareTime ?? 4)
        _sets = State(initialValue: page?.manifest.sets ?? 1)
        _restBetweenSets = State(initialValue: page?.manifest.restBetweenSets ?? 0)
        _dropSetTemplates = State(initialValue: page?.manifest.dropSetTemplates ?? [])
        _linkURLsText = State(initialValue: page?.manifest.linkURLs.joined(separator: "\n") ?? "")
        _coverImageFilename = State(initialValue: page?.manifest.coverImageFilename)
        _mediaFilenames = State(initialValue: page?.manifest.mediaFilenames ?? [])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        titleCard
                        if let saveErrorMessage {
                            Text(saveErrorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        pageKindCard
                        iconCard
                        if pageKind == .container {
                            coverImageCard
                        } else {
                            mediaUploadCard
                        }
                        if pageKind == .container && parentID == nil {
                            workoutTypeCard
                        } else {
                            inheritedWorkoutTypeCard
                        }
                        if pageKind == .leaf {
                            timingCard
                            dropSetTemplatesCard
                        }
                        markdownCard
                        linksCard
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
            #if os(macOS)
            .fileImporter(
                isPresented: $showCoverPicker,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                handleMacCoverPick(url)
            }
            .fileImporter(
                isPresented: $showMediaPicker,
                allowedContentTypes: [.image, .movie],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                urls.forEach(stageMedia)
            }
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerSheet(selectedIcon: $iconName)
            }
            .sheet(isPresented: $showDropSetPicker) {
                DatabasePageBrowserSheet(
                    workout: Workout(name: "Drop Set Templates"),
                    onAdd: { page, _, _, _, _, _, _ in
                        dropSetTemplates.append(
                            PageDropSetTemplate(
                                setIndex: max(0, sets - 1),
                                exerciseID: page.manifest.id,
                                name: page.manifest.title,
                                duration: page.manifest.duration ?? 30,
                                restAfter: page.manifest.restAfter ?? 0
                            )
                        )
                        showDropSetPicker = false
                    },
                    onAddBundle: { sources, _, _, _, _, _, _ in
                        for source in sources {
                            guard case .page(let page) = source else { continue }
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
                        showDropSetPicker = false
                    }
                )
                .environmentObject(databaseStore)
                .environmentObject(workoutStore)
            }
            #if os(iOS)
            .photosPicker(
                isPresented: $showCoverPicker,
                selection: $pendingCoverItem,
                matching: .images
            )
            .photosPicker(
                isPresented: $showMediaPicker,
                selection: $pendingMediaItems,
                maxSelectionCount: 10,
                matching: .any(of: [.images, .videos])
            )
            .onChange(of: pendingCoverItem) { item in
                guard let item = item else { return }
                handleCoverPick(item: item)
            }
            .onChange(of: pendingMediaItems) { items in
                guard !items.isEmpty else { return }
                handleMediaPicks(items: items)
            }
            #endif
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

    private var pageKindCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Page Type")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            if parentID != nil {
                Label("Pages inside a container are exercises.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            } else {
                HStack(spacing: 8) {
                    kindButton(.container, title: "Container", icon: "folder.fill")
                    kindButton(.leaf, title: "Exercise", icon: "figure.run")
                }
            }
        }
    }

    private func kindButton(
        _ kind: ExercisePageManifest.PageKind,
        title: String,
        icon: String
    ) -> some View {
        Button {
            pageKind = kind
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(pageKind == kind ? .semibold : .regular))
                .foregroundColor(pageKind == kind ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(pageKind == kind ? Color.white : Theme.surface)
                .cornerRadius(9)
        }
        .buttonStyle(.plain)
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

    private var coverImageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cover Image").font(.headline).foregroundColor(Theme.textPrimary)
            if let fileName = coverImageFilename, let page = existingPage {
                let coverURL = page.coverImageURL
                if let url = coverURL {
                    coverPreview(for: url)
                        .overlay(alignment: .topTrailing) {
                            Button {
                                coverImageFilename = nil
                                coverPreviewImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(6)
                            }
                        }
                }
            } else if let preview = coverPreviewImage {
                preview
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            coverImageFilename = nil
                            coverPreviewImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(6)
                        }
                    }
            }
            Button { showCoverPicker = true } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(Theme.textSecondary)
                    Text(coverImageFilename != nil || coverPreviewImage != nil ? "Change Cover Image" : "Upload Cover Image")
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(10)
            }
        }
    }

    @ViewBuilder
    private func coverPreview(for url: URL) -> some View {
        #if os(iOS)
        if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 160)
                .clipped()
                .cornerRadius(10)
        }
        #elseif os(macOS)
        if let data = try? Data(contentsOf: url), let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 160)
                .clipped()
                .cornerRadius(10)
        }
        #endif
    }

    @ViewBuilder
    private var mediaUploadCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Media").font(.headline).foregroundColor(Theme.textPrimary)

            if !mediaFilenames.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(mediaFilenames, id: \.self) { filename in
                        ZStack(alignment: .topTrailing) {
                            if let preview = mediaPreviewThumbnails.first(where: { $0.filename == filename })?.image {
                                preview
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 80)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.surface)
                                    .frame(height: 80)
                                    .overlay(Image(systemName: "photo")
                                        .foregroundColor(Theme.textSecondary.opacity(0.4)))
                            }
                            Button {
                                removeMedia(filename: filename)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                                    .padding(4)
                            }
                        }
                    }
                }
            }

            if mediaFilenames.count < 20 {
                Button { showMediaPicker = true } label: {
                    HStack {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .foregroundColor(Theme.textSecondary)
                        Text("Add Media (\(mediaFilenames.count)/20)")
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(14)
                    .background(Theme.surface)
                    .cornerRadius(10)
                }
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
                    Text(inheritedWorkoutType.map { "Inherit \($0.name)" } ?? "None")
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
    private var inheritedWorkoutTypeCard: some View {
        if let inheritedWorkoutType {
            HStack(spacing: 8) {
                Image(systemName: inheritedWorkoutType.iconName)
                    .foregroundColor(Color(hex: inheritedWorkoutType.colorHex))
                Text("Uses \(inheritedWorkoutType.name) from its container")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(12)
            .background(Theme.surface)
            .cornerRadius(10)
        }
    }

    private var inheritedWorkoutType: TimeMasterCore.WorkoutType? {
        guard let parentID, let uuid = UUID(uuidString: parentID) else { return nil }
        return databaseStore.page(id: uuid)?.effectiveWorkoutType
    }

    @ViewBuilder
    private var timingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Config").font(.headline).foregroundColor(Theme.textPrimary)
            VStack(spacing: 8) {
                stepperRow(label: "Duration", value: $duration, range: 5...600, step: 5, unit: "s")
                stepperRow(label: "Prepare Time", value: $prepareTime, range: 0...30, step: 1, unit: "s")
                stepperRow(label: "Rest After", value: $restAfter, range: 0...120, step: 5, unit: "s")
                stepperRow(label: "Sets", value: $sets, range: 1...20, step: 1, unit: "")
                stepperRow(label: "Rest Between Sets", value: $restBetweenSets, range: 0...120, step: 5, unit: "s")
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
    private var dropSetTemplatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Drop Sets")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button {
                    showDropSetPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.textPrimary)
                .accessibilityLabel("Add drop set exercise")
            }

            if dropSetTemplates.isEmpty {
                Text("Add a drop-set exercise from the database, then choose the set it follows.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else {
                ForEach($dropSetTemplates) { $template in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.right")
                                .foregroundColor(Theme.textSecondary)
                            Text(template.name)
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                dropSetTemplates.removeAll { $0.id == template.id }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(template.name)")
                        }

                        HStack {
                            Text("After set")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Stepper(
                                "\(template.setIndex + 1)",
                                value: $template.setIndex,
                                in: 0...max(0, sets - 1)
                            )
                            .labelsHidden()
                            Text("\(template.setIndex + 1)")
                                .foregroundColor(Theme.textPrimary)
                                .monospacedDigit()
                                .frame(minWidth: 24, alignment: .trailing)
                        }

                        HStack {
                            Text("Duration \(template.duration)s · Rest \(template.restAfter)s")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(Theme.surface)
                    .cornerRadius(10)
                }
            }
        }
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

        let parsedURLs = linkURLsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let coreWT: TimeMasterCore.WorkoutType? = {
            guard pageKind == .container, parentID == nil, let wt = workoutType else { return nil }
            return TimeMasterCore.WorkoutType(id: wt.id, name: wt.name, iconName: wt.iconName, colorHex: wt.colorHex)
        }()
        let normalizedDropSetTemplates = dropSetTemplates.map {
            PageDropSetTemplate(
                id: $0.id,
                setIndex: min(max(0, $0.setIndex), max(0, sets - 1)),
                exerciseID: $0.exerciseID,
                name: $0.name,
                duration: $0.duration,
                restAfter: $0.restAfter
            )
        }
        let normalizedPrepareTime = min(30, max(0, prepareTime))

        var manifest: ExercisePageManifest
        if let existing = existingPage {
            manifest = existing.manifest
            manifest.title = trimmedTitle
            manifest.iconName = iconName.isEmpty ? nil : iconName
            manifest.pageKind = pageKind
            manifest.workoutType = coreWT
            manifest.markdownBody = markdownBody
            manifest.duration = pageKind == .leaf ? duration : nil
            manifest.restAfter = pageKind == .leaf ? restAfter : nil
            manifest.sets = pageKind == .leaf ? sets : nil
            manifest.restBetweenSets = pageKind == .leaf ? restBetweenSets : nil
            manifest.prepareTime = pageKind == .leaf ? normalizedPrepareTime : nil
            manifest.linkURLs = parsedURLs
            manifest.coverImageFilename = pageKind == .container ? coverImageFilename : nil
            manifest.mediaFilenames = pageKind == .leaf ? mediaFilenames : []
            manifest.dropSetTemplates = pageKind == .leaf
                ? normalizedDropSetTemplates
                : []
            manifest.updatedAt = Date()
        } else {
            manifest = ExercisePageManifest(
                title: trimmedTitle,
                pageKind: pageKind,
                coverImageFilename: pageKind == .container ? coverImageFilename : nil,
                iconName: iconName.isEmpty ? nil : iconName,
                markdownBody: markdownBody,
                mediaFilenames: pageKind == .leaf ? mediaFilenames : [],
                linkURLs: parsedURLs,
                workoutType: coreWT,
                duration: pageKind == .leaf ? duration : nil,
                restAfter: pageKind == .leaf ? restAfter : nil,
                prepareTime: pageKind == .leaf ? normalizedPrepareTime : nil,
                sets: pageKind == .leaf ? sets : nil,
                restBetweenSets: pageKind == .leaf ? restBetweenSets : nil,
                dropSetTemplates: pageKind == .leaf ? normalizedDropSetTemplates : [],
                parentID: parentID
            )
        }

        do {
            if existingPage == nil, let onSaveWithMedia {
                let mediaData: [(filename: String, data: Data)] = pendingMediaFiles.compactMap { media in
                    guard let data = try? Data(contentsOf: media.temporaryURL) else { return nil }
                    return (filename: media.temporaryURL.lastPathComponent, data: data)
                }
                try onSaveWithMedia(manifest, parentID, pendingCoverData, mediaData)
                pendingMediaFiles.forEach { try? FileManager.default.removeItem(at: $0.temporaryURL) }
            } else {
                try onSave(manifest, parentID)

                if existingPage == nil {
                    let pageID = manifest.id
                    let coverData = pendingCoverData
                    let mediaFiles = pendingMediaFiles
                    DispatchQueue.global(qos: .userInitiated).async { [weak databaseStore] in
                        if let coverData = coverData, manifest.pageKind == .container {
                            let temporaryCoverURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString + "-" + (manifest.coverImageFilename ?? "cover.jpg"))
                            do {
                                try coverData.write(to: temporaryCoverURL)
                                let uploadedFilename = try DatabaseManager.shared.uploadCoverImage(
                                    pageID: pageID,
                                    sourceURL: temporaryCoverURL
                                )
                                databaseStore?.publishUploadedMedia(pageID: pageID, coverFilename: uploadedFilename)
                            } catch {}
                            try? FileManager.default.removeItem(at: temporaryCoverURL)
                        }
                        for media in mediaFiles {
                            do {
                                let uploadedFilename = try DatabaseManager.shared.uploadMediaToPage(
                                    pageID: pageID,
                                    sourceURL: media.temporaryURL
                                )
                                databaseStore?.publishUploadedMedia(pageID: pageID, mediaFilenames: [uploadedFilename])
                            } catch {}
                            try? FileManager.default.removeItem(at: media.temporaryURL)
                        }
                    }
                }
            }
        } catch {
            saveErrorMessage = error.localizedDescription
            return
        }

        dismiss()
    }

    #if os(iOS)
    private func handleCoverPick(item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            guard case .success(let data?) = result else { return }
            if let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    coverPreviewImage = Image(uiImage: uiImage)
                }
            }
            let pageID = existingPage?.manifest.id
            if let id = pageID {
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent("cover_tmp.jpg")
                do {
                    try data.write(to: tempURL)
                    let filename = try DatabaseManager.shared.uploadCoverImage(pageID: id, sourceURL: tempURL)
                    DispatchQueue.main.async {
                        coverImageFilename = filename
                        DatabaseStore.shared.reload()
                    }
                    try? FileManager.default.removeItem(at: tempURL)
                } catch {}
            } else {
                DispatchQueue.main.async {
                    coverImageFilename = "cover.jpg"
                    pendingCoverData = data
                }
            }
        }
    }

    private func handleMediaPicks(items: [PhotosPickerItem]) {
        Task { @MainActor in
            for item in items {
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
        } catch {}
    }

    private func stageMedia(_ sourceURL: URL) {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-" + (sourceURL.lastPathComponent.isEmpty ? "media.jpg" : sourceURL.lastPathComponent))
        do {
            try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
            if let pageID = existingPage?.manifest.id {
                let uploaded = try DatabaseManager.shared.uploadMediaToPage(pageID: pageID, sourceURL: temporaryURL)
                try? FileManager.default.removeItem(at: temporaryURL)
                if !mediaFilenames.contains(uploaded) {
                    mediaFilenames.append(uploaded)
                }
                databaseStore.updatePageMedia(pageID: pageID, mediaFilenames: [uploaded])
                let mediaURL = try? DatabaseManager.shared.pageMediaURL(pageID: pageID, filename: uploaded)
                loadMediaPreview(filename: uploaded, url: mediaURL)
            } else {
                let previewName = temporaryURL.lastPathComponent
                if !mediaFilenames.contains(previewName) {
                    mediaFilenames.append(previewName)
                    pendingMediaFiles.append(PendingPageMedia(temporaryURL: temporaryURL))
                    loadMediaPreview(filename: previewName, url: temporaryURL)
                } else {
                    try? FileManager.default.removeItem(at: temporaryURL)
                }
            }
        } catch {}
    }

    private func loadMediaPreview(filename: String, url: URL?) {
        guard let url else { return }
        Task {
            let image = await PhotoManager.shared.asyncLoadImage(from: url)
            guard let image else { return }
            #if os(iOS)
            let preview = Image(uiImage: image)
            #elseif os(macOS)
            let preview = Image(nsImage: image)
            #endif
            await MainActor.run {
                mediaPreviewThumbnails.removeAll { $0.filename == filename }
                mediaPreviewThumbnails.append((filename: filename, image: preview))
            }
        }
    }

    #if os(macOS)
    private func handleMacCoverPick(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        if let pageID = existingPage?.manifest.id {
            let temporaryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("cover." + (url.pathExtension.isEmpty ? "jpg" : url.pathExtension))
            do {
                try data.write(to: temporaryURL)
                let filename = try DatabaseManager.shared.uploadCoverImage(pageID: pageID, sourceURL: temporaryURL)
                coverImageFilename = filename
                try? FileManager.default.removeItem(at: temporaryURL)
                databaseStore.publishUploadedMedia(pageID: pageID, coverFilename: filename)
            } catch {}
        } else {
            coverImageFilename = "cover." + (url.pathExtension.isEmpty ? "jpg" : url.pathExtension)
            pendingCoverData = data
            if let image = NSImage(data: data) {
                coverPreviewImage = Image(nsImage: image)
            }
        }
    }
    #endif
    private func removeMedia(filename: String) {
        guard let page = existingPage else {
            mediaFilenames.removeAll { $0 == filename }
            return
        }
        do {
            try DatabaseManager.shared.removeMediaFromPage(pageID: page.manifest.id, filename: filename)
            mediaFilenames.removeAll { $0 == filename }
        } catch {
            mediaFilenames.removeAll { $0 == filename }
        }
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
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
            }
        }
    }
}
