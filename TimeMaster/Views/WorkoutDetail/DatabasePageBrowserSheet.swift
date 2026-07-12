import SwiftUI

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
    @State private var previewPage: ExercisePage?

    @State private var duration: Int = 30
    @State private var sets: Int = 1
    @State private var reps: Int = 0
    @State private var restAfter: Int = 10
    @State private var restBetweenSets: Int = 10
    @State private var showToast = false

    private var pages: [ExercisePage] { store.rootPages }

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
                page.manifest.markdownBody.localizedCaseInsensitiveContains(searchText) ||
                page.manifest.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
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
            if let wt = page.manifest.workoutType, !seen.contains(wt.id) {
                seen.insert(wt.id)
                result.append(FilterTypeChip(id: wt.id, name: wt.name, colorHex: wt.colorHex))
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    private func previewConfig(for page: ExercisePage) {
        previewPage = page
        duration = page.manifest.duration ?? 30
        sets = page.manifest.sets ?? 1
        reps = page.manifest.sets != nil ? 12 : 0
        restAfter = page.manifest.restAfter ?? 10
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
                        .onTapGesture {
                            if isBundleMode {
                                toggleBundleSelection(page)
                            } else {
                                previewConfig(for: page)
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
                    .listRowBackground(Theme.surface)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isBundleMode {
                            toggleBundleSelection(page)
                        } else {
                            previewConfig(for: page)
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
                    Color(hex: page.manifest.workoutType?.colorHex ?? "FFFFFF").opacity(0.25)
                        .overlay(
                            Image(systemName: iconName)
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: page.manifest.workoutType?.colorHex ?? "FFFFFF").opacity(0.5))
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
                if let wt = page.manifest.workoutType {
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
                    if let wt = page.manifest.workoutType {
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
                let color = page.manifest.workoutType?.colorHex ?? "FFFFFF"
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
        if selectedBundleIDs.contains(page.manifest.id) {
            selectedBundleIDs.remove(page.manifest.id)
        } else {
            selectedBundleIDs.insert(page.manifest.id)
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
                            Image(systemName: "plus.circle.fill")
                            Text("Add Section")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.surface)
        }
    }

    private var bundleBar: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.separator)

            VStack(spacing: 8) {
                let selectedPages = pages.filter { selectedBundleIDs.contains($0.manifest.id) }
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

                Button {
                    onAddBundle(selectedPages, duration, sets, reps, restAfter, restBetweenSets)
                    showToastMessage("Bundle created")
                    selectedBundleIDs.removeAll()
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
