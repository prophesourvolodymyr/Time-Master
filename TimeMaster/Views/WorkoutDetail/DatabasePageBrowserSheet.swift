import SwiftUI
import UniformTypeIdentifiers

struct DatabasePageBrowserSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DatabaseStore
    @EnvironmentObject var workoutStore: WorkoutStore

    let workout: Workout
    let onAdd: (ExercisePage, Int, Int, Int, Int, Int) -> Void
    let onAddBundle: ([ExercisePage], Int, Int, Int, Int, Int) -> Void

    @State private var isGridMode = false
    @State private var sortOption: PageSortOption = .name
    @State private var filterOption: PageFilterOption = .all
    @State private var searchText = ""
    @State private var isBundleMode = false
    @State private var selectedBundleIDs: Set<String> = []
    @State private var bundleOrder: [String] = []
    @State private var draggedBundleID: String?
    @State private var previewPage: ExercisePage?
    @State private var detailPreviewPage: ExercisePage?

    @State private var duration: Int = 30
    @State private var sets: Int = 1
    @State private var reps: Int = 0
    @State private var restAfter: Int = 5
    @State private var restBetweenSets: Int = 10
    @State private var showToast = false

    private var pages: [ExercisePage] {
        store.allPagesFlat
    }

    private var filteredPages: [ExercisePage] {
        var result = pages
        switch filterOption {
        case .all: break
        case .container: result = result.filter { $0.isContainer }
        case .leaf: result = result.filter { $0.isLeaf }
        case .type(let typeId): result = result.filter { $0.manifest.workoutType?.id == typeId }
        }
        if !searchText.isEmpty {
            result = result.filter { page in
                page.title.localizedCaseInsensitiveContains(searchText) ||
                page.manifest.markdownBody.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOption {
        case .name: result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .dateCreated: result.sort { $0.manifest.createdAt > $1.manifest.createdAt }
        case .workoutType: result.sort { ($0.manifest.workoutType?.name ?? "zzz") < ($1.manifest.workoutType?.name ?? "zzz") }
        }
        return result
    }

    private var uniqueWorkoutTypes: [FilterTypeChip] {
        var seen = Set<String>()
        var result: [FilterTypeChip] = []
        for page in pages {
            if let wt = page.effectiveWorkoutType, !seen.contains(wt.id) {
                seen.insert(wt.id)
                result.append(FilterTypeChip(id: wt.id, name: wt.name, colorHex: wt.colorHex))
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    private var selectedBundlePages: [ExercisePage] {
        bundleOrder.compactMap { id in
            pages.first { $0.manifest.id == id }
        }
    }

    private func previewConfig(for page: ExercisePage) {
        previewPage = page
        duration = page.manifest.duration ?? 30
        sets = page.manifest.sets ?? 1
        reps = page.manifest.sets != nil ? 12 : 0
        restAfter = page.manifest.restAfter ?? 5
        restBetweenSets = page.manifest.restBetweenSets ?? 10
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBarView
                    filterChipsRow

                    if filteredPages.isEmpty {
                        noResultsView
                    } else {
                        pageContentView
                    }
                }

                VStack {
                    Spacer()
                    if previewPage != nil, !isBundleMode {
                        previewBar
                    }
            if isBundleMode, !selectedBundleIDs.isEmpty {
                        bundleBar
                    }
                }
            }
            .navigationTitle(isBundleMode ? "Bundle Mode" : "Browse Pages")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isGridMode.toggle()
                        }
                    } label: {
                        Image(systemName: isGridMode ? "list.bullet" : "square.grid.2x2")
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(PageSortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                Label(option.label, systemImage: option == sortOption ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isBundleMode.toggle()
                            if !isBundleMode {
                                selectedBundleIDs.removeAll()
                                bundleOrder.removeAll()
                            }
                        }
                    } label: {
                        Image(systemName: isBundleMode ? "rectangle.stack.fill" : "rectangle.stack")
                    }
                    .foregroundColor(isBundleMode ? .yellow : .white)
                }
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    toastBanner
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $detailPreviewPage) { page in
                ExercisePageQuickPreview(
                    page: page,
                    canAdd: page.isLeaf,
                    onAdd: {
                        onAdd(page, duration, sets, reps, restAfter, restBetweenSets)
                        detailPreviewPage = nil
                        previewPage = nil
                    }
                )
            }
        }
    }

    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textSecondary.opacity(0.6))
            TextField("Search pages...", text: $searchText)
                .foregroundColor(Theme.textPrimary)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                }
            }
        }
        .padding(10)
        .background(Theme.surface)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(.all, label: "All")
                filterChip(.container, label: "Containers")
                filterChip(.leaf, label: "Leaves")
                ForEach(uniqueWorkoutTypes) { type in
                    filterChip(.type(type.id), label: type.name)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(_ option: PageFilterOption, label: String) -> some View {
        let isActive = filterOption == option
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { filterOption = option }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .black : Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? Color.white : Theme.surface)
                .cornerRadius(14)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(Theme.textSecondary.opacity(0.4))
            Text("No pages found")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    private var pageContentView: some View {
        Group {
            if isGridMode {
                gridView
            } else {
                listView
            }
        }
    }

    private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(filteredPages) { page in
                    pageGridCard(page)
                        .onDrag { NSItemProvider(object: page.manifest.id as NSString) }
                        .onTapGesture {
                            if isBundleMode, page.isLeaf {
                                toggleBundleSelection(page)
                            } else {
                                previewConfig(for: page)
                                detailPreviewPage = page
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
    }

    private var listView: some View {
        List {
            ForEach(filteredPages) { page in
                pageListRow(page)
                    .onDrag { NSItemProvider(object: page.manifest.id as NSString) }
                    .listRowBackground(Theme.surface)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isBundleMode, page.isLeaf {
                            toggleBundleSelection(page)
                        } else {
                            previewConfig(for: page)
                            detailPreviewPage = page
                        }
                    }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
    }

    private func pageGridCard(_ page: ExercisePage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let iconName = page.manifest.iconName {
                    Color(hex: page.effectiveWorkoutType?.colorHex ?? "FFFFFF").opacity(0.25)
                        .overlay(
                            Image(systemName: iconName)
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: page.effectiveWorkoutType?.colorHex ?? "FFFFFF").opacity(0.5))
                        )
                } else {
                    Color.white.opacity(0.06)
                        .overlay(
                            Image(systemName: page.isContainer ? "folder.fill" : "doc.text.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.textSecondary.opacity(0.3))
                        )
                }
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                if isBundleMode {
                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: selectedBundleIDs.contains(page.manifest.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(selectedBundleIDs.contains(page.manifest.id) ? .yellow : .white.opacity(0.6))
                    }
                    .padding(8)
                }
            }
            .frame(height: 100)

            VStack(alignment: .leading, spacing: 2) {
                Text(page.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)
                if let wt = page.effectiveWorkoutType {
                    Text(wt.name)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(hex: wt.colorHex))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color(hex: wt.colorHex).opacity(0.2))
                        .cornerRadius(3)
                }
            }
            .padding(8)
        }
        .background(Theme.surface)
        .cornerRadius(12)
        .clipped()
    }

    private func pageListRow(_ page: ExercisePage) -> some View {
        HStack(spacing: 12) {
            if isBundleMode {
                Image(systemName: selectedBundleIDs.contains(page.manifest.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(selectedBundleIDs.contains(page.manifest.id) ? .yellow : Color.white.opacity(0.3))
            }
            coverThumb(page)
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if page.isContainer {
                        Text("\(page.totalChildCount) pages")
                    }
                    if page.hasWorkoutConfig {
                        Text("\(page.manifest.duration ?? 0)s")
                    }
                    if let wt = page.effectiveWorkoutType {
                        Text(wt.name)
                    }
                }
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary.opacity(0.4))
        }
        .padding(.vertical, 4)
    }

    private func coverThumb(_ page: ExercisePage) -> some View {
        Group {
            if let iconName = page.manifest.iconName {
                let color = page.effectiveWorkoutType?.colorHex ?? "FFFFFF"
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: color).opacity(0.25))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: color))
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: page.isContainer ? "folder.fill" : "doc.text.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textSecondary.opacity(0.4))
                    )
            }
        }
    }

    private func toggleBundleSelection(_ page: ExercisePage) {
        guard page.isLeaf else { return }
        if selectedBundleIDs.contains(page.manifest.id) {
            selectedBundleIDs.remove(page.manifest.id)
            bundleOrder.removeAll { $0 == page.manifest.id }
        } else {
            selectedBundleIDs.insert(page.manifest.id)
            bundleOrder.append(page.manifest.id)
        }
    }

    private var previewBar: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.separator)

            VStack(alignment: .leading, spacing: 8) {
                if let page = previewPage {
                    HStack {
                        Text(page.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Button { previewPage = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textSecondary.opacity(0.6))
                        }
                    }

                    HStack(spacing: 6) {
                        compactStepper(label: "Dur", value: $duration, range: 5...600, step: 5, unit: "s")
                        compactStepper(label: "Sets", value: $sets, range: 1...20, step: 1, unit: "")
                        compactStepper(label: "Reps", value: $reps, range: 0...100, step: 1, unit: "")
                        compactStepper(label: "Rest", value: $restAfter, range: 0...120, step: 5, unit: "s")
                        compactStepper(label: "Btwn", value: $restBetweenSets, range: 0...120, step: 5, unit: "s")
                    }

                    Button {
                        onAdd(page, duration, sets, reps, restAfter, restBetweenSets)
                        showToastMessage("Added \(page.title)")
                        previewPage = nil
                    } label: {
                        HStack {
                            Image(systemName: page.isLeaf ? "plus.circle.fill" : "folder")
                            Text(page.isLeaf ? "Add Section" : "Container cannot be added")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                    .disabled(!page.isLeaf)
                    .opacity(page.isLeaf ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.surface)
        }
        .onDrop(
            of: [.text],
            delegate: PageDropDelegate { providers in
                handlePageDrop(providers, asBundle: false)
            }
        )
    }

    private var bundleBar: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.separator)

            VStack(spacing: 8) {
                let selectedPages = selectedBundlePages
                Text("\(selectedPages.count) pages selected")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.textPrimary)

                HStack(spacing: 6) {
                    compactStepper(label: "Dur", value: $duration, range: 5...600, step: 5, unit: "s")
                    compactStepper(label: "Sets", value: $sets, range: 1...20, step: 1, unit: "")
                    compactStepper(label: "Reps", value: $reps, range: 0...100, step: 1, unit: "")
                    compactStepper(label: "Rest", value: $restAfter, range: 0...120, step: 5, unit: "s")
                    compactStepper(label: "Btwn", value: $restBetweenSets, range: 0...120, step: 5, unit: "s")
                }

                if !selectedPages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedPages) { page in
                                HStack(spacing: 5) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.caption2)
                                    Text(page.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Button {
                                        toggleBundleSelection(page)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(Color.yellow.opacity(0.18))
                                .clipShape(Capsule())
                                .onDrag {
                                    draggedBundleID = page.manifest.id
                                    return NSItemProvider(object: page.manifest.id as NSString)
                                }
                                .onDrop(
                                    of: [.text],
                                    delegate: BundlePageDropDelegate(
                                        sourceID: draggedBundleID,
                                        targetID: page.manifest.id,
                                        move: { source, target in moveBundlePage(source, before: target) }
                                    )
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                Button {
                    onAddBundle(selectedPages, duration, sets, reps, restAfter, restBetweenSets)
                    showToastMessage("Bundle created")
                    selectedBundleIDs.removeAll()
                    bundleOrder.removeAll()
                    isBundleMode = false
                } label: {
                    HStack {
                        Image(systemName: "rectangle.stack.fill")
                        Text("Create Bundle Section")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.yellow)
                    .cornerRadius(10)
                }
                .disabled(selectedBundleIDs.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.surface)
        }
        .onDrop(
            of: [.text],
            delegate: PageDropDelegate { providers in
                handlePageDrop(providers, asBundle: true)
            }
        )
    }

    private func handlePageDrop(_ providers: [NSItemProvider], asBundle: Bool) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let rawID = (object as? NSString)?.description,
                  let page = pages.first(where: { $0.manifest.id == rawID }) else { return }
            DispatchQueue.main.async {
                guard page.isLeaf else { return }
                if asBundle {
                    if !selectedBundleIDs.contains(page.manifest.id) {
                        selectedBundleIDs.insert(page.manifest.id)
                        bundleOrder.append(page.manifest.id)
                    }
                    isBundleMode = true
                } else {
                    previewConfig(for: page)
                    previewPage = page
                }
            }
        }
        return true
    }

    private func moveBundlePage(_ sourceID: String?, before targetID: String) {
        guard let sourceID, sourceID != targetID,
              let sourceIndex = bundleOrder.firstIndex(of: sourceID) else { return }
        bundleOrder.remove(at: sourceIndex)
        let targetIndex = bundleOrder.firstIndex(of: targetID) ?? bundleOrder.endIndex
        bundleOrder.insert(sourceID, at: targetIndex)
        draggedBundleID = nil
    }

    private func compactStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(Theme.textSecondary)
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
                Button {
                    let new = value.wrappedValue + step
                    if new <= range.upperBound { value.wrappedValue = new }
                } label: {
                    Image(systemName: "plus").font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white).frame(width: 16, height: 16)
                        .background(Theme.surface).cornerRadius(3)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Theme.surface2)
        .cornerRadius(6)
    }

    private func showToastMessage(_ message: String) {
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) { showToast = false }
        }
    }

    private var toastBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Added to \(workout.name)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.85))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

private struct ExercisePageQuickPreview: View {
    @Environment(\.dismiss) private var dismiss

    let page: ExercisePage
    let canAdd: Bool
    let onAdd: () -> Void

    @State private var selectedMediaIndex = 0
    @State private var showingMedia = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AsyncCoverImage(
                        url: page.coverImageURL,
                        fallbackIcon: page.isContainer ? "folder.fill" : "figure.run",
                        fallbackColor: page.effectiveWorkoutType.map { Color(hex: $0.colorHex) },
                        height: 190
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(page.title)
                            .font(.title2.weight(.bold))
                            .foregroundColor(Theme.textPrimary)

                        HStack(spacing: 8) {
                            metadataBadge(page.isContainer ? "Container" : "Exercise", systemImage: page.isContainer ? "folder" : "figure.run")
                            if let type = page.effectiveWorkoutType {
                                metadataBadge(type.name, systemImage: type.iconName)
                            }
                            metadataBadge("\(page.mediaURLs.count) media", systemImage: "photo.on.rectangle")
                            if page.hasLinks {
                                metadataBadge("\(page.manifest.linkURLs.count) links", systemImage: "link")
                            }
                        }
                    }

                    if page.hasMarkdown {
                        Text(page.manifest.markdownBody
                            .replacingOccurrences(of: "#", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(6)
                    }

                    if page.hasMedia {
                        PageMediaGalleryGrid(urls: page.mediaURLs) { index in
                            selectedMediaIndex = index
                            showingMedia = true
                        }
                    }

                    if canAdd {
                        Button {
                            onAdd()
                            dismiss()
                        } label: {
                            Label("Add to Workout", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Text("Containers organize exercises and cannot be added as workout sections.")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Preview")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingMedia) {
            PageMediaGallery(
                urls: page.mediaURLs,
                selectedIndex: $selectedMediaIndex,
                isPresented: $showingMedia
            )
        }
    }

    private func metadataBadge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2)
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Theme.surface)
            .clipShape(Capsule())
    }
}

private struct BundlePageDropDelegate: DropDelegate {
    let sourceID: String?
    let targetID: String
    let move: (String?, String) -> Void

    func dropEntered(info: DropInfo) {
        move(sourceID, targetID)
    }

    func performDrop(info: DropInfo) -> Bool { true }
}

private struct PageDropDelegate: DropDelegate {
    let handle: ([NSItemProvider]) -> Bool

    func performDrop(info: DropInfo) -> Bool {
        handle(info.itemProviders(for: [.text]))
    }
}
