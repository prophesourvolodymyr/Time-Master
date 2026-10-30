import SwiftUI
import TimeMasterCore
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif

struct PageCreationRequest: Identifiable {
    let id = UUID()
    var pageType: PageType?
    var parentID: String? = nil
}

private struct PendingPageMedia {
    let temporaryURL: URL

    var filename: String { temporaryURL.lastPathComponent }
}

private struct PageCreationComment: Identifiable {
    let filename: String
    let url: URL
    var id: String { filename }
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

enum PageMediaLayout {
    static let galleryAspect: CGFloat = 1080.0 / 1480.0

    static func galleryWidth(forHeight height: CGFloat) -> CGFloat {
        (height * galleryAspect).rounded()
    }
}

private enum PageFormTag {
    case required
    case optional
}

private struct PageFormTagLabel: View {
    let tag: PageFormTag

    var body: some View {
        let isRequired = tag == .required
        Text(isRequired ? "REQUIRED" : "OPTIONAL")
            .font(TimeMasterFont.black(10, relativeTo: .caption2))
            .tracking(0.6)
            .foregroundStyle(isRequired ? Theme.toolbarOrange : Theme.textPrimary.opacity(0.62))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(isRequired ? Theme.toolbarOrange.opacity(0.14) : Color.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(isRequired ? Theme.toolbarOrange.opacity(0.7) : Color.white.opacity(0.16), lineWidth: 1))
            .accessibilityLabel(isRequired ? "Required" : "Optional")
    }
}

private struct PageFormSelectorStyle: ButtonStyle {
    let isSelected: Bool
    var minHeight: CGFloat = 46

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        configuration.label
            .font(isSelected ? TimeMasterFont.black(15, relativeTo: .subheadline) : TimeMasterFont.body(15, relativeTo: .subheadline))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(shape.fill(isSelected ? Theme.toolbarOrange : Theme.surface))
            .overlay(shape.strokeBorder(isSelected ? Color.white.opacity(0.55) : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 1))
            .contentShape(shape)
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: 12))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PageFormFieldSurface: ViewModifier {
    var isFocused = false
    var isValid = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        content
            .background(Theme.surface, in: shape)
            .overlay(
                shape.strokeBorder(
                    isFocused ? Theme.toolbarOrange : (isValid ? Theme.toolbarOrange.opacity(0.45) : Color.white.opacity(0.1)),
                    lineWidth: isFocused ? 1.5 : 1
                )
                .allowsHitTesting(false)
            )
    }
}

struct PageCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var databaseStore: DatabaseStore
    @ObservedObject private var draftStore = PageCreationDraftStore.shared

    let existingPage: ExercisePage?
    let onSave: (ExercisePageManifest, String?) throws -> Void
    let onSaveWithMedia: ((ExercisePageManifest, String?, Data?, [(filename: String, data: Data)]) throws -> Void)?
    @State private var libraryToken: ExerciseLibraryAccess.Token

    @State private var pageKind: ExercisePageManifest.PageKind
    @State private var pageType: PageType?
    @State private var skillStatus: SkillStatus?
    @State private var skillBoardSectionID: String?
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
    @State private var mediaComments: [String: String]
    @State private var editingMediaComment: PageCreationComment?
    @State private var pendingMediaFiles: [PendingPageMedia] = []
    @State private var mediaPreviewThumbnails: [(filename: String, image: Image?)] = []
    @State private var draggedMediaFilename: String?
    @FocusState private var focusedDropSetID: String?
    @FocusState private var focusedLinkID: UUID?
    @FocusState private var titleFocused: Bool
    @State private var showDropSetPicker = false
    @State private var showMediaPicker = false
    @State private var showDeleteConfirm = false
    @State private var showDraftList = false
    @State private var showCancelConfirm = false
    @State private var showGuideFullScreen = false
    @State private var guideHeight: CGFloat = 220
    @State private var guideDragOrigin: CGFloat?
    @State private var draftID: UUID
    @State private var openedFromDraft = false
    @State private var draftSavedExplicitly = false
    @State private var didSavePage = false
    @State private var didDiscard = false
    @State private var draftSavedMessage: String?
    @State private var saveErrorMessage: String?
    @State private var autosaveTask: Task<Void, Never>?
    #if os(iOS)
    @State private var pendingMediaItems: [PhotosPickerItem] = []
    #endif

    private static let mediaHeight: CGFloat = 200
    private static let guideHeightRange: ClosedRange<CGFloat> = 140...760

    init(
        page: ExercisePage? = nil,
        parentID: String? = nil,
        initialPageType: PageType? = nil,
        onSave: @escaping (ExercisePageManifest, String?) throws -> Void,
        onSaveWithMedia: ((ExercisePageManifest, String?, Data?, [(filename: String, data: Data)]) throws -> Void)? = nil
    ) {
        self.existingPage = page
        self.onSave = onSave
        self.onSaveWithMedia = onSaveWithMedia
        _libraryToken = State(initialValue: ExerciseLibraryAccess.shared.capture())

        let resolvedParentID = parentID ?? page?.manifest.parentID
        let defaultPageType: PageType? = initialPageType ?? (resolvedParentID != nil ? .exercise : nil)
        let initialType = page?.manifest.pageType
            ?? (page?.manifest.pageKind == .leaf ? .exercise : (page == nil ? defaultPageType : nil))
        let initialKind: ExercisePageManifest.PageKind = {
            if initialType == .skill || initialType == .tutorial {
                return .container
            }
            return initialType == .exercise ? .leaf : (page?.manifest.pageKind ?? .container)
        }()
        let initialLinks = Self.makeLinkRows(
            urls: page?.manifest.linkURLs ?? [],
            metadata: page?.manifest.linkMetadata ?? []
        )
        let initialMedia = page.map(Self.orderedMediaFilenames) ?? []

        _pageKind = State(initialValue: initialKind)
        _pageType = State(initialValue: initialType)
        _skillStatus = State(initialValue: page?.manifest.skillStatus)
        _skillBoardSectionID = State(initialValue: page?.manifest.skillBoardSectionID)
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
        _linkRows = State(initialValue: initialLinks.isEmpty ? [PageCreationLinkRow(url: "")] : initialLinks)
        _mediaFilenames = State(initialValue: initialMedia)
        _mediaComments = State(initialValue: page?.manifest.mediaComments ?? [:])
        _draftID = State(initialValue: UUID())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        titleCard
                        if let saveErrorMessage {
                            Label(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(TimeMasterFont.body(14, relativeTo: .footnote))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        pageKindCard
                        mediaCard
                        workoutTypeCard
                        if isSkillLikePage {
                            skillTrackingCard
                        }
                        if isExercisePage {
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
                    .padding(.bottom, 28)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: pageType)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
            .overlay(alignment: .bottom) {
                if let draftSavedMessage {
                    Label(draftSavedMessage, systemImage: "checkmark.circle.fill")
                        .font(TimeMasterFont.black(13, relativeTo: .footnote))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Theme.surface2, in: Capsule())
                        .overlay(Capsule().stroke(Theme.toolbarOrange.opacity(0.7), lineWidth: 1))
                        .padding(.bottom, 96)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .timeMasterNavigationTitle(existingPage == nil ? "New Page" : "Edit Page")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { requestCancel() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
                if existingPage == nil {
                    AppToolbar.item(placement: .primaryAction) {
                        draftsButton
                    }
                }
            }
            .confirmationDialog(
                "Keep this page as a draft?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Save Draft") {
                    saveDraft()
                    dismiss()
                }
                Button("Discard", role: .destructive) {
                    discardDraft()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Drafts stay in the drafts list for 30 days.")
            }
            .sheet(isPresented: $showDraftList) {
                PageCreationDraftListSheet(currentDraftID: draftID) { draft in
                    persistDraftIfNeeded()
                    apply(draft: draft)
                    showDraftList = false
                }
            }
            .sheet(isPresented: $showGuideFullScreen) {
                MarkdownEditorSheet(title: "Guide", text: $markdownBody, assets: pageAssets)
                    .keyNavHost()
            }
            .sheet(item: $editingMediaComment) { attachment in
                MediaCommentEditor(mediaURL: attachment.url, comment: mediaComments[attachment.filename] ?? "", assets: pageAssets) { comment in
                    guard mediaFilenames.contains(attachment.filename) else {
                        throw FileSystemHelper.Error.notFound(attachment.filename)
                    }
                    try ExerciseLibraryAccess.shared.perform(token: libraryToken) {
                        if let existingPage {
                            try databaseStore.updateMediaComment(pageID: existingPage.manifest.id, filename: attachment.filename, comment: comment)
                        }
                        mediaComments[attachment.filename] = comment.isEmpty ? nil : comment
                    }
                }
                .id(attachment.filename)
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
                draftStore.reload()
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
                if !didDiscard { persistDraftIfNeeded() }
            }
        }
    }

    private var draftsButton: some View {
        Button {
            persistDraftIfNeeded()
            draftStore.reload()
            showDraftList = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "tray.full")
                    .font(.system(size: 15, weight: .bold))
                Text(draftStore.drafts.isEmpty ? "Drafts" : "\(draftStore.drafts.count)")
                    .monospacedDigit()
            }
        }
        .buttonStyle(TimeMasterToolbarTextButtonStyle())
        .accessibilityLabel("Open page drafts")
        .accessibilityValue(draftStore.drafts.isEmpty ? "No drafts" : "\(draftStore.drafts.count) drafts")
    }

    private var titleCard: some View {
        formCard {
            sectionHeading("Title", tag: .required)
            TextField("Page title", text: $title)
                .textFieldStyle(.plain)
                .font(TimeMasterFont.body(17))
                .focused($titleFocused)
                .padding(14)
                .foregroundStyle(Theme.textPrimary)
                .modifier(PageFormFieldSurface(isFocused: titleFocused))
                .accessibilityLabel("Page title")
        }
    }

    private var pageKindCard: some View {
        formCard {
            sectionHeading("Page Type", tag: .required)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                pageTypeButton(nil, title: "Container", systemImage: "square.stack.3d.up")
                pageTypeButton(.exercise, title: "Exercise", systemImage: "figure.run")
                pageTypeButton(.skill, title: "Skill", systemImage: "flag.checkered")
                pageTypeButton(.tutorial, title: "Tutorial", systemImage: "book.closed")
            }
            if pageType == .exercise, draftParentID == nil {
                Text("Saved at the top of the Database, outside any container.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func pageTypeButton(
        _ type: PageType?,
        title: String,
        systemImage: String
    ) -> some View {
        let isSelected = pageType == type && (type != nil || pageKind == .container)
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                pageType = type
                switch type {
                case .exercise:
                    pageKind = .leaf
                    skillStatus = nil
                    skillBoardSectionID = nil
                case .skill, .tutorial:
                    pageKind = .container
                    skillStatus = skillStatus ?? .notStarted
                case nil:
                    pageKind = .container
                    skillStatus = nil
                    skillBoardSectionID = nil
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
            }
        }
        .buttonStyle(PageFormSelectorStyle(isSelected: isSelected))
        .accessibilityLabel(title)
    }

    private var mediaCard: some View {
        formCard {
            sectionHeading("Media", tag: .optional) {
                if !mediaFilenames.isEmpty {
                    Text("\(mediaFilenames.count)/20")
                        .font(TimeMasterFont.caption().monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            mediaStrip
            Text(mediaFilenames.isEmpty
                 ? "The first picture becomes the square cover; the rest form the gallery."
                 : "The first item is the cover. Press and drag any item to reorder.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
    }

    private var mediaStrip: some View {
        let height = Self.mediaHeight
        let galleryWidth = PageMediaLayout.galleryWidth(forHeight: height)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 10) {
                if let cover = mediaFilenames.first {
                    mediaColumn(label: "Cover", accent: true) {
                        draggableTile(filename: cover, width: height, height: height, isCover: true)
                    }
                } else {
                    mediaColumn(label: "Cover", accent: true) {
                        addMediaTile(width: height, height: height, title: "Add cover")
                    }
                }

                Capsule()
                    .fill(Theme.toolbarOrange.opacity(0.75))
                    .frame(width: 3, height: height - 24)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 12)
                    .accessibilityHidden(true)

                mediaColumn(label: mediaFilenames.count > 1 ? "Gallery · \(mediaFilenames.count - 1)" : "Gallery", accent: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(mediaFilenames.dropFirst()), id: \.self) { filename in
                            draggableTile(filename: filename, width: galleryWidth, height: height, isCover: false)
                        }
                        if mediaFilenames.count < 20 {
                            addMediaTile(width: galleryWidth, height: height, title: "Add")
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: mediaFilenames)
        }
    }

    private func mediaColumn<Content: View>(label: String, accent: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(TimeMasterFont.black(10, relativeTo: .caption2))
                .tracking(0.6)
                .foregroundStyle(accent ? Theme.toolbarOrange : Theme.textSecondary)
            content()
        }
    }

    private func draggableTile(filename: String, width: CGFloat, height: CGFloat, isCover: Bool) -> some View {
        mediaTile(filename: filename, width: width, height: height, isCover: isCover)
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

    private func addMediaTile(width: CGFloat, height: CGFloat, title: String) -> some View {
        Button {
            showMediaPicker = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Theme.toolbarOrange.opacity(0.75), in: Circle())
                Text(title)
                    .font(TimeMasterFont.black(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: width, height: height)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.toolbarOrange.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
        .accessibilityLabel(title == "Add cover" ? "Add cover and media" : "Add media")
    }

    private func mediaTile(filename: String, width: CGFloat, height: CGFloat, isCover: Bool) -> some View {
        let isVideo = mediaURL(filename: filename).map(PageMediaKind.isVideo) ?? false
        return ZStack {
            Group {
                if let preview = mediaPreviewThumbnails.first(where: { $0.filename == filename })?.image {
                    preview
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Theme.surface
                        .overlay {
                            Image(systemName: isVideo ? "play.rectangle" : "photo")
                                .foregroundStyle(Theme.textSecondary.opacity(0.45))
                        }
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: width, height: height)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isCover ? Theme.toolbarOrange : Color.white.opacity(0.1), lineWidth: isCover ? 2 : 1)
        }
        .overlay(alignment: .topTrailing) {
            Button(role: .destructive) {
                removeMedia(filename: filename)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .black))
            }
            .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 30))
            .padding(4)
            .accessibilityLabel("Remove media")
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                if let url = mediaURL(filename: filename) {
                    editingMediaComment = PageCreationComment(filename: filename, url: url)
                }
            } label: {
                Image(systemName: mediaComments[filename] == nil ? "text.bubble" : "text.bubble.fill")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 32))
            .padding(4)
            .accessibilityLabel(mediaComments[filename] == nil ? "Add media comment" : "Edit media comment")
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isCover ? "Cover" : "Gallery item")
    }

    private var workoutTypeCard: some View {
        formCard {
            sectionHeading("Workout Type", tag: .optional)
            if let inheritedWorkoutType {
                Text("Uses \(inheritedWorkoutType.name) from the container by default.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                Button {
                    workoutType = nil
                } label: {
                    Text(inheritedWorkoutType == nil ? "None" : "Container default")
                }
                .buttonStyle(PageFormSelectorStyle(isSelected: workoutType == nil))

                ForEach(WorkoutType.all(custom: workoutStore.customWorkoutTypes), id: \.id) { type in
                    Button {
                        workoutType = type
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.iconName)
                            Text(type.name)
                        }
                    }
                    .buttonStyle(PageFormSelectorStyle(isSelected: workoutType == type))
                }
            }
        }
    }

    private var skillTrackingCard: some View {
        formCard {
            sectionHeading(pageType == .tutorial ? "Tutorial Status" : "Skill Status", tag: .required)
            HStack(spacing: 8) {
                ForEach(SkillStatus.allCases, id: \.self) { status in
                    Button {
                        skillStatus = status
                    } label: {
                        Text(skillStatusTitle(status))
                    }
                    .buttonStyle(PageFormSelectorStyle(isSelected: effectiveSkillStatus == status))
                }
            }
            if !availableSkillBoardSections.isEmpty {
                Menu {
                    Button("Unsectioned") {
                        skillBoardSectionID = nil
                    }
                    ForEach(availableSkillBoardSections) { section in
                        Button(section.title) {
                            skillBoardSectionID = section.id
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedSkillBoardSection?.title ?? "Unsectioned")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                    .padding(13)
                    .modifier(PageFormFieldSurface())
                }
                .foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private var timingCard: some View {
        formCard {
            sectionHeading("Workout Config", tag: .required)
            VStack(spacing: 8) {
                stepperRow(label: "Duration", value: $duration, range: 5...600, step: 5, unit: "s")
                stepperRow(label: "Prepare Time", value: $prepareTime, range: 0...30, step: 1, unit: "s", tag: .optional)
                stepperRow(label: "Sets", value: $sets, range: 1...20, step: 1, unit: "")
                if sets > 1 {
                    stepperRow(
                        label: "Rest Between Sets",
                        detail: "After every set except the last",
                        value: $restBetweenSets,
                        range: 0...120,
                        step: 5,
                        unit: "s",
                        tag: .optional
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                stepperRow(
                    label: sets > 1 ? "Big Rest" : "Rest",
                    detail: sets > 1 ? "After the last set" : "After the exercise",
                    value: $restAfter,
                    range: 0...120,
                    step: 5,
                    unit: "s",
                    tag: .optional
                )
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: sets > 1)
        }
    }

    private func stepperRow(
        label: String,
        detail: String? = nil,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String,
        tag: PageFormTag? = nil
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(TimeMasterFont.black(16, relativeTo: .callout))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if tag != nil || detail != nil {
                    HStack(spacing: 6) {
                        if let tag {
                            PageFormTagLabel(tag: tag)
                        }
                        if let detail {
                            Text(detail)
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
            Spacer(minLength: 4)
            Text("\(value.wrappedValue)\(unit)")
                .font(TimeMasterFont.black(16, relativeTo: .callout).monospacedDigit())
                .foregroundStyle(Theme.toolbarOrange)
                .frame(minWidth: 40, alignment: .trailing)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .tint(Theme.toolbarOrange)
        }
        .padding(12)
        .modifier(PageFormFieldSurface())
        .accessibilityElement(children: .combine)
    }

    private var dropSetTemplatesCard: some View {
        formCard {
            sectionHeading("Drop Sets", tag: .optional)
            HStack(spacing: 10) {
                Button {
                    addManualDropSet()
                } label: {
                    Label {
                        Text("Add")
                    } icon: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .black))
                    }
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 48, fillsWidth: true))
                .accessibilityLabel("Add drop set by name")

                Button {
                    showDropSetPicker = true
                } label: {
                    Label {
                        Text("From Database")
                    } icon: {
                        DatabasePlusIcon()
                    }
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 48, fillsWidth: true))
                .accessibilityLabel("Add drop set from the database")
            }

            ForEach($dropSetTemplates) { $template in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Group {
                            if template.exerciseID.isEmpty {
                                Image(systemName: "pencil")
                            } else {
                                Image(systemName: "cylinder.split.1x2")
                            }
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.toolbarOrange)
                        .frame(width: 22)
                        .accessibilityHidden(true)
                        TextField("Drop-set exercise name", text: $template.name)
                            .textFieldStyle(.plain)
                            .font(TimeMasterFont.body(16))
                            .foregroundStyle(Theme.textPrimary)
                            .focused($focusedDropSetID, equals: template.id)
                        Button(role: .destructive) {
                            dropSetTemplates.removeAll { $0.id == template.id }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 34))
                        .accessibilityLabel("Remove drop set")
                    }

                    HStack {
                        Text("After set")
                            .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(template.setIndex + 1)")
                            .font(TimeMasterFont.black(15, relativeTo: .subheadline).monospacedDigit())
                            .foregroundStyle(Theme.toolbarOrange)
                            .frame(minWidth: 24, alignment: .trailing)
                        Stepper("", value: $template.setIndex, in: 0...max(0, sets - 1))
                            .labelsHidden()
                            .tint(Theme.toolbarOrange)
                    }

                    HStack(spacing: 12) {
                        stepperValue("Duration", value: $template.duration, range: 5...600, step: 5, unit: "s")
                        stepperValue("Rest", value: $template.restAfter, range: 0...120, step: 5, unit: "s")
                    }
                }
                .padding(12)
                .modifier(PageFormFieldSurface(isFocused: focusedDropSetID == template.id))
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
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 4) {
                Text("\(value.wrappedValue)\(unit)")
                    .font(TimeMasterFont.black(13, relativeTo: .caption).monospacedDigit())
                    .foregroundStyle(Theme.toolbarOrange)
                Stepper("", value: value, in: range, step: step)
                    .labelsHidden()
                    .scaleEffect(0.85, anchor: .trailing)
                    .tint(Theme.toolbarOrange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pageAssets: MarkdownAssets? {
        existingPage.map { FolderMarkdownAssets(folder: databaseStore.folderURL(for: $0)) }
    }

    private var markdownCard: some View {
        formCard {
            sectionHeading("Guide", tag: .optional)
            MarkdownEditorView(text: $markdownBody, assets: pageAssets, showsBar: false, trailingSpace: 56)
                .frame(height: guideHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .modifier(PageFormFieldSurface())
                .overlay(alignment: .topTrailing) {
                    Button {
                        showGuideFullScreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .black))
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 34))
                    .padding(6)
                    .accessibilityLabel("Open the guide full screen")
                }
                .overlay(alignment: .bottomLeading) {
                    guideResizeHandle(mirrored: true)
                }
                .overlay(alignment: .bottomTrailing) {
                    guideResizeHandle(mirrored: false)
                }
            Text("Markdown renders as you type. Drag a bottom corner to resize, or expand to full screen for formatting tools.")
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
    }

    private func guideResizeHandle(mirrored: Bool) -> some View {
        GuideResizeGrip()
            .stroke(Theme.textPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 14, height: 14)
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            .frame(width: 34, height: 34)
            .background(Theme.toolbarOrange.opacity(0.8), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .padding(6)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in
                        let origin = guideDragOrigin ?? guideHeight
                        if guideDragOrigin == nil { guideDragOrigin = guideHeight }
                        guideHeight = min(Self.guideHeightRange.upperBound, max(Self.guideHeightRange.lowerBound, origin + value.translation.height))
                    }
                    .onEnded { _ in
                        guideDragOrigin = nil
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    guideHeight = guideHeight < 400 ? 520 : 220
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Resize guide editor")
            .accessibilityValue("\(Int(guideHeight)) points tall")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: guideHeight = min(Self.guideHeightRange.upperBound, guideHeight + 80)
                case .decrement: guideHeight = max(Self.guideHeightRange.lowerBound, guideHeight - 80)
                @unknown default: break
                }
            }
    }

    private var linksCard: some View {
        formCard {
            sectionHeading("External Links", tag: .optional)
            ForEach($linkRows) { $row in
                linkRowView($row)
            }
            Button {
                addLinkRow()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .black))
            }
            .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 48))
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Add another link")
        }
    }

    private func linkRowView(_ row: Binding<PageCreationLinkRow>) -> some View {
        let value = row.wrappedValue
        let normalized = normalizedLinkURL(value.url)
        let isValid = !normalized.isEmpty && isValidHTTPURL(normalized)
        let isEmpty = value.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isValid ? Theme.toolbarOrange : Theme.textSecondary)
                    .accessibilityHidden(true)
                TextField("Paste a link", text: row.url)
                    .textFieldStyle(.plain)
                    .font(TimeMasterFont.body(16))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($focusedLinkID, equals: value.id)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    #endif
                    .onSubmit { submitLink(value.id) }
                    .onChange(of: value.url) { _ in
                        refreshLinkMetadata(for: value.id)
                    }
                if value.isLoading {
                    TmaxLoadingIndicator(size: 18)
                }
                if isEmpty {
                    PasteButton(payloadType: String.self) { strings in
                        let pasted = strings.first ?? ""
                        Task { @MainActor in pasteLink(pasted, into: value.id) }
                    }
                    .labelStyle(.titleOnly)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.toolbarOrange)
                    .controlSize(.small)
                    .accessibilityLabel("Paste link from clipboard")
                }
                if !isEmpty || linkRows.count > 1 {
                    Button(role: .destructive) {
                        removeLinkRow(value.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .black))
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 30))
                    .accessibilityLabel("Remove link")
                }
            }
            .padding(.leading, 13)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .frame(minHeight: 50)
            .modifier(PageFormFieldSurface(isFocused: focusedLinkID == value.id, isValid: isValid))

            if isValid {
                PageLinkRow(info: PageLinkInfo(urlString: normalized, metadata: value.metadata)) {
                    if let url = URL(string: normalized) { openURL(url) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if !isEmpty {
                Label("Not a valid web link yet. Links start with https://", systemImage: "exclamationmark.circle")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.toolbarOrange)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isValid)
    }

    private var deleteCard: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Delete Page", systemImage: "trash")
                .font(TimeMasterFont.sectionTitle())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 52, fillsWidth: true))
    }

    private var actionBar: some View {
        VStack(spacing: 6) {
            if !canSave {
                Text("Add a title to create this page")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 10) {
                if existingPage == nil {
                    Button {
                        saveDraft()
                    } label: {
                        Label {
                            Text("Draft")
                        } icon: {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .font(TimeMasterFont.black(16, relativeTo: .callout))
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(
                        minimumSize: 54,
                        horizontalPadding: 18,
                        tint: canDraft ? Theme.toolbarOrange : Color(white: 0.42)
                    ))
                    .disabled(!canDraft)
                    .accessibilityLabel("Save draft")
                }

                Button {
                    savePage()
                } label: {
                    Text(existingPage == nil ? "Create Page" : "Save Changes")
                        .font(TimeMasterFont.black(17, relativeTo: .body))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TimeMasterActionButtonStyle(
                    prominent: true,
                    minimumSize: 54,
                    fillsWidth: true,
                    tint: canSave ? Theme.toolbarOrange : Color(white: 0.42)
                ))
                .disabled(!canSave)
                .accessibilityHint(canSave ? "" : "Add a title first")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Theme.background.opacity(0.85))
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: canSave)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var draftFingerprint: String {
        [
            title,
            pageKind.rawValue,
            pageType?.rawValue ?? "",
            skillStatus?.rawValue ?? "",
            skillBoardSectionID ?? "",
            draftParentID ?? "",
            markdownBody,
            "\(duration)",
            "\(prepareTime)",
            "\(restAfter)",
            "\(sets)",
            "\(restBetweenSets)",
            dropSetTemplates.map { "\($0.id):\($0.exerciseID):\($0.name):\($0.setIndex):\($0.duration):\($0.restAfter)" }.joined(separator: "|"),
            linkRows.map { "\($0.id):\($0.url)" }.joined(separator: "|"),
            mediaFilenames.joined(separator: "|"),
            mediaComments.keys.sorted().map { "\($0):\(mediaComments[$0] ?? "")" }.joined(separator: "\u{1E}")
        ].joined(separator: "\u{1F}")
    }

    private func scheduleAutosave() {
        guard existingPage == nil, !didSavePage, !didDiscard else { return }
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
            || !dropSetTemplates.isEmpty
    }

    private var isExercisePage: Bool { pageType == .exercise }
    private var isSkillLikePage: Bool { pageType == .skill || pageType == .tutorial }
    private var effectiveSkillStatus: SkillStatus { skillStatus ?? .notStarted }

    private var inheritedWorkoutType: TimeMasterCore.WorkoutType? {
        guard let parentID = draftParentID,
              let parentUUID = UUID(uuidString: parentID) else { return nil }
        return databaseStore.page(id: parentUUID)?.effectiveWorkoutType
    }

    private var availableSkillBoardSections: [SkillBoardSection] {
        guard let parentID = draftParentID,
              let parentUUID = UUID(uuidString: parentID) else { return [] }
        return databaseStore.page(id: parentUUID)?.manifest.skillBoardSections ?? []
    }

    private var selectedSkillBoardSection: SkillBoardSection? {
        availableSkillBoardSections.first { $0.id == skillBoardSectionID }
    }

    private func skillStatusTitle(_ status: SkillStatus) -> String {
        status.title
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
    }

    private func sectionHeading(_ title: String, tag: PageFormTag) -> some View {
        sectionHeading(title, tag: tag) { EmptyView() }
    }

    private func sectionHeading<Accessory: View>(
        _ title: String,
        tag: PageFormTag,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            Text(title)
                .font(TimeMasterFont.heading())
                .foregroundStyle(Theme.textPrimary)
            PageFormTagLabel(tag: tag)
            accessory()
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func requestCancel() {
        if existingPage == nil, hasDraftContent, !draftSavedExplicitly, !openedFromDraft {
            showCancelConfirm = true
        } else {
            dismiss()
        }
    }

    private func discardDraft() {
        didDiscard = true
        autosaveTask?.cancel()
        draftStore.delete(id: draftID)
        cleanupTemporaryMedia()
        dismiss()
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
            do {
                try ExerciseLibraryAccess.shared.perform(token: libraryToken) {
                    try DatabaseManager.shared.removeMediaFromPage(pageID: page.manifest.id, filename: filename)
                }
                databaseStore.reload()
            } catch {
                saveErrorMessage = error.localizedDescription
                return
            }
        }
        mediaComments.removeValue(forKey: filename)
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
        guard persistDraftIfNeeded() else { return }
        draftSavedExplicitly = true
        withAnimation(.easeOut(duration: 0.2)) {
            draftSavedMessage = "Draft saved"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.2)) {
                draftSavedMessage = nil
            }
        }
    }

    @discardableResult
    private func persistDraftIfNeeded() -> Bool {
        guard existingPage == nil, !didSavePage, !didDiscard, hasDraftContent else { return false }
        let draft = makeDraft()
        let sources = Dictionary(uniqueKeysWithValues: pendingMediaFiles.map { ($0.filename, $0.temporaryURL) })
        do {
            try ExerciseLibraryAccess.shared.perform(token: libraryToken) {
                try draftStore.save(draft, mediaSources: sources)
            }
            return true
        } catch {
            saveErrorMessage = "Could not save draft: \(error.localizedDescription)"
            return false
        }
    }

    private func makeDraft() -> PageCreationDraft {
        let now = Date()
        let createdAt = draftStore.drafts.first(where: { $0.id == draftID })?.createdAt ?? now
        let links = linkRows.compactMap { row -> (String, LinkMetadata?)? in
            let url = normalizedLinkURL(row.url)
            return url.isEmpty ? nil : (url, row.metadata)
        }
        let normalizedDropSets = normalizedDropSetTemplates()

        return PageCreationDraft(
            id: draftID,
            title: title,
            pageKind: pageKind,
            pageType: pageType,
            skillStatus: skillStatus,
            skillBoardSectionID: skillBoardSectionID,
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
            mediaComments: mediaComments,
            createdAt: createdAt,
            updatedAt: now
        )
    }

    private func savePage() {
        guard canSave else { return }
        do {
            let mediaData = try mediaFilenames.compactMap { filename -> (filename: String, data: Data)? in
                guard let pending = pendingMediaFiles.first(where: { $0.filename == filename }) else {
                    if existingPage == nil { throw FileSystemHelper.Error.notFound(filename) }
                    return nil
                }
                return (filename: filename, data: try Data(contentsOf: pending.temporaryURL))
            }
            var manifest = makeManifest()
            if existingPage == nil { manifest.mediaFilenames = [] }
            try ExerciseLibraryAccess.shared.perform(token: libraryToken) {
                if existingPage == nil, let onSaveWithMedia {
                    try onSaveWithMedia(manifest, draftParentID, nil, mediaData)
                } else {
                    try onSave(manifest, draftParentID)
                    if existingPage == nil && !mediaData.isEmpty {
                        try uploadMediaAfterFallbackSave(pageID: manifest.id, mediaData: mediaData)
                    }
                }
                if existingPage == nil { draftStore.delete(id: draftID) }
            }
            didSavePage = true
            autosaveTask?.cancel()
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
        let coreWorkoutType: TimeMasterCore.WorkoutType? = workoutType.map {
            TimeMasterCore.WorkoutType(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex)
        }
        let resolvedPageType = pageType ?? (pageKind == .leaf ? .exercise : nil)
        let structuralKind: ExercisePageManifest.PageKind = resolvedPageType == .exercise ? .leaf : .container
        let isExercise = resolvedPageType == .exercise
        let isSkillLike = resolvedPageType == .skill || resolvedPageType == .tutorial
        let status = isSkillLike ? effectiveSkillStatus : nil
        let boardSectionID = isSkillLike ? skillBoardSectionID : nil

        if let existingPage {
            var manifest = existingPage.manifest
            manifest.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            manifest.pageKind = structuralKind
            manifest.pageType = resolvedPageType
            manifest.parentID = draftParentID
            manifest.coverImageFilename = nil
            if !isSkillLike { manifest.iconName = nil }
            manifest.workoutType = coreWorkoutType
            manifest.markdownBody = markdownBody
            manifest.mediaFilenames = mediaFilenames
            manifest.mediaComments = mediaComments.filter { mediaFilenames.contains($0.key) }
            manifest.linkURLs = links.map(\.0)
            manifest.linkMetadata = links.map { $0.1 ?? LinkMetadata(url: $0.0) }
            manifest.duration = isExercise ? duration : nil
            manifest.prepareTime = isExercise ? prepareTime : nil
            manifest.restAfter = isExercise ? restAfter : nil
            manifest.sets = isExercise ? sets : nil
            manifest.restBetweenSets = isExercise && sets > 1 ? restBetweenSets : nil
            manifest.dropSetTemplates = isExercise ? normalizedDropSets : []
            manifest.childIDs = structuralKind == .container ? existingPage.manifest.childIDs : []
            manifest.skillStatus = status
            manifest.skillBoardSectionID = boardSectionID
            manifest.skillBoardOrder = isSkillLike
                ? max(0, existingPage.manifest.skillBoardOrder ?? nextSkillBoardOrder)
                : nil
            if isExercise {
                manifest.linkedPageIDs = []
                manifest.skillBoardSections = []
            }
            manifest.updatedAt = Date()
            return manifest
        }

        return ExercisePageManifest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            pageKind: structuralKind,
            pageType: resolvedPageType,
            iconName: nil,
            markdownBody: markdownBody,
            mediaFilenames: mediaFilenames,
            mediaComments: mediaComments.filter { mediaFilenames.contains($0.key) },
            linkURLs: links.map(\.0),
            linkMetadata: links.map { $0.1 ?? LinkMetadata(url: $0.0) },
            workoutType: coreWorkoutType,
            skillStatus: status,
            skillBoardSectionID: boardSectionID,
            skillBoardOrder: isSkillLike ? nextSkillBoardOrder : nil,
            duration: isExercise ? duration : nil,
            restAfter: isExercise ? restAfter : nil,
            prepareTime: isExercise ? prepareTime : nil,
            sets: isExercise ? sets : nil,
            restBetweenSets: isExercise && sets > 1 ? restBetweenSets : nil,
            dropSetTemplates: isExercise ? normalizedDropSets : [],
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
    ) throws {
        do {
            for (filename, data) in mediaData {
                let temporaryURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "-" + URL(fileURLWithPath: filename).lastPathComponent)
                defer { try? FileManager.default.removeItem(at: temporaryURL) }
                try data.write(to: temporaryURL, options: .atomic)
                let savedFilename = try DatabaseManager.shared.uploadMediaToPage(pageID: pageID, sourceURL: temporaryURL)
                if let comment = mediaComments[filename] {
                    try DatabaseManager.shared.updateMediaComment(pageID: pageID, filename: savedFilename, comment: comment)
                }
            }
        } catch {
            let saveError = error
            do {
                try DatabaseManager.shared.deletePage(id: pageID)
            } catch {
                throw FileSystemHelper.Error.writeFailed("\(saveError.localizedDescription) Cleanup failed: \(error.localizedDescription)")
            }
            databaseStore.reloadImmediately()
            throw saveError
        }
        databaseStore.reloadImmediately()
    }

    private func cleanupTemporaryMedia() {
        for pending in pendingMediaFiles where pending.temporaryURL.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
            try? FileManager.default.removeItem(at: pending.temporaryURL)
        }
    }

    private var nextSkillBoardOrder: Int {
        guard let parentID = draftParentID,
              let parentUUID = UUID(uuidString: parentID) else { return 0 }
        return databaseStore.children(of: parentUUID)
            .filter { $0.isSkillLike }
            .filter { $0.manifest.skillStatus == effectiveSkillStatus }
            .filter { $0.manifest.skillBoardSectionID == skillBoardSectionID }
            .count
    }

    private func apply(draft: PageCreationDraft) {
        draftID = draft.id
        openedFromDraft = true
        draftSavedExplicitly = false
        title = draft.title
        pageKind = draft.pageKind
        pageType = draft.pageType ?? (draft.pageKind == .leaf ? .exercise : nil)
        skillStatus = draft.skillStatus
        skillBoardSectionID = draft.skillBoardSectionID
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
        let restoredLinks = Self.makeLinkRows(urls: draft.linkURLs, metadata: draft.linkMetadata)
        linkRows = restoredLinks.isEmpty ? [PageCreationLinkRow(url: "")] : restoredLinks

        let availableMedia = draft.mediaFilenames.filter { filename in
            let url = draftStore.mediaURL(for: draft, filename: filename)
            return FileManager.default.fileExists(atPath: url.path)
        }
        mediaFilenames = availableMedia
        mediaComments = (draft.mediaComments ?? [:]).filter { availableMedia.contains($0.key) }
        pendingMediaFiles = availableMedia.map { filename in
            PendingPageMedia(temporaryURL: draftStore.mediaURL(for: draft, filename: filename))
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
                url = page.mediaURLs.first { $0.lastPathComponent == filename } ?? page.mediaURLs[safe: index]
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
                do {
                    if isVideo, let movie = try? await item.loadTransferable(type: MovieFile.self) {
                        try ExerciseLibraryAccess.shared.perform(token: libraryToken) { stageMedia(movie.url) }
                    } else if let data = try? await item.loadTransferable(type: Data.self) {
                        try ExerciseLibraryAccess.shared.perform(token: libraryToken) { stageMedia(data: data, pathExtension: "jpg") }
                    }
                } catch {
                    saveErrorMessage = error.localizedDescription
                    return
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

    private func mediaURL(filename: String) -> URL? {
        if let pending = pendingMediaFiles.first(where: { $0.filename == filename }) {
            return pending.temporaryURL
        }
        return existingPage?.mediaURLs.first { $0.lastPathComponent == filename }
            ?? existingPage.flatMap { try? DatabaseManager.shared.pageMediaURL(pageID: $0.manifest.id, filename: filename) }
    }

    private func stageMedia(_ sourceURL: URL) {
        guard mediaFilenames.count < 20 else { return }
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-" + (sourceURL.lastPathComponent.isEmpty ? "media.jpg" : sourceURL.lastPathComponent))
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
            if let page = existingPage {
                let uploaded = try ExerciseLibraryAccess.shared.perform(token: libraryToken) {
                    try DatabaseManager.shared.uploadMediaToPage(pageID: page.manifest.id, sourceURL: temporaryURL)
                }
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

    private func addLinkRow(after rowID: UUID? = nil) {
        let row = PageCreationLinkRow(url: "")
        if let rowID, let index = linkRows.firstIndex(where: { $0.id == rowID }) {
            linkRows.insert(row, at: index + 1)
        } else {
            linkRows.append(row)
        }
        focusedLinkID = row.id
    }

    private func submitLink(_ rowID: UUID) {
        guard let index = linkRows.firstIndex(where: { $0.id == rowID }) else { return }
        let hasLink = !linkRows[index].url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let nextIsEmpty = linkRows.indices.contains(index + 1)
            && linkRows[index + 1].url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasLink, !nextIsEmpty {
            addLinkRow(after: rowID)
        } else if hasLink, nextIsEmpty {
            focusedLinkID = linkRows[index + 1].id
        } else {
            focusedLinkID = nil
        }
    }

    private func removeLinkRow(_ rowID: UUID) {
        if linkRows.count > 1 {
            linkRows.removeAll { $0.id == rowID }
        } else {
            updateLinkRow(rowID) {
                $0.url = ""
                $0.metadata = nil
                $0.isLoading = false
            }
        }
    }

    private func pasteLink(_ pasted: String, into rowID: UUID) {
        let value = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        updateLinkRow(rowID) { $0.url = value }
        refreshLinkMetadata(for: rowID)
    }

    private func refreshLinkMetadata() {
        for row in linkRows where row.metadata == nil && !row.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            refreshLinkMetadata(for: row.id)
        }
    }

    private func refreshLinkMetadata(for rowID: UUID) {
        guard let row = linkRows.first(where: { $0.id == rowID }) else { return }
        let normalized = normalizedLinkURL(row.url)
        guard !normalized.isEmpty, isValidHTTPURL(normalized) else {
            updateLinkRow(rowID) {
                $0.metadata = nil
                $0.isLoading = false
            }
            return
        }
        if row.metadata?.url == normalized { return }

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
              host.contains("."),
              !host.hasPrefix("."),
              !host.hasSuffix(".") else {
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

struct DatabasePlusIcon: View {
    var body: some View {
        Image(systemName: "cylinder.split.1x2")
            .font(.system(size: 15, weight: .bold))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 10, weight: .black))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.toolbarOrange, Theme.textPrimary)
                    .offset(x: 5, y: 4)
            }
            .padding(.trailing, 4)
            .accessibilityHidden(true)
    }
}

private struct GuideResizeGrip: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

private struct PageCreationDraftListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store: PageCreationDraftStore
    let currentDraftID: UUID
    let onSelect: (PageCreationDraft) -> Void

    init(currentDraftID: UUID, onSelect: @escaping (PageCreationDraft) -> Void) {
        self.currentDraftID = currentDraftID
        self.onSelect = onSelect
        _store = ObservedObject(wrappedValue: PageCreationDraftStore.shared)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if store.drafts.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(Theme.toolbarOrange)
                        Text("No drafts")
                            .font(TimeMasterFont.sectionTitle())
                            .foregroundStyle(Theme.textPrimary)
                        Text("Tap Draft while creating a page to keep it here. Drafts are kept for 30 days.")
                            .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(store.drafts) { draft in
                                draftRow(draft)
                            }
                            Text("Drafts are removed once the page is created, or after 30 days.")
                                .font(TimeMasterFont.caption())
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 6)
                        }
                        .padding(16)
                    }
                }
            }
            .timeMasterNavigationTitle("Drafts")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
            }
            .task { store.reload() }
        }
    }

    private func draftRow(_ draft: PageCreationDraft) -> some View {
        let isCurrent = draft.id == currentDraftID
        return HStack(spacing: 12) {
            Button {
                onSelect(draft)
            } label: {
                HStack(spacing: 12) {
                    DraftThumbnail(url: draft.mediaFilenames.first.map { store.mediaURL(for: draft, filename: $0) }, pageType: draft.pageType)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.title.isEmpty ? "Untitled page" : draft.title)
                            .font(TimeMasterFont.rowTitle())
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text("\(Self.typeTitle(draft.pageType)) · \(draft.mediaFilenames.count) media · \(Self.expiry(draft))")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        Text(isCurrent ? "Editing now" : "Edited \(draft.updatedAt.formatted(.relative(presentation: .named)))")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(isCurrent ? Theme.toolbarOrange : Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
            .accessibilityLabel("\(draft.title.isEmpty ? "Untitled page" : draft.title), \(Self.typeTitle(draft.pageType))")
            .accessibilityHint(isCurrent ? "This is the draft you are editing" : "Opens this draft")

            Button(role: .destructive) {
                store.delete(id: draft.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 36))
            .accessibilityLabel("Delete draft")
        }
        .padding(10)
        .modifier(PageFormFieldSurface(isValid: isCurrent))
    }

    private static func typeTitle(_ type: PageType?) -> String {
        switch type {
        case .exercise: "Exercise"
        case .skill: "Skill"
        case .tutorial: "Tutorial"
        case nil: "Container"
        }
    }

    private static func expiry(_ draft: PageCreationDraft) -> String {
        let remaining = draft.updatedAt.addingTimeInterval(PageCreationDraftStore.lifetime).timeIntervalSinceNow
        let days = max(0, Int((remaining / 86_400).rounded(.up)))
        return days == 1 ? "1 day left" : "\(days) days left"
    }
}

private struct DraftThumbnail: View {
    let url: URL?
    let pageType: PageType?
    @State private var image: Image?

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.toolbarOrange.opacity(0.14))
            .frame(width: 52, height: 52)
            .overlay {
                if let image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.toolbarOrange)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .task(id: url) {
                guard let url, let loaded = await PhotoManager.shared.asyncLoadImage(from: url, maxPixelSize: 160) else { return }
                #if os(iOS)
                image = Image(uiImage: loaded)
                #else
                image = Image(nsImage: loaded)
                #endif
            }
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch pageType {
        case .exercise: "figure.run"
        case .skill: "flag.checkered"
        case .tutorial: "book.closed"
        case nil: "square.stack.3d.up"
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
