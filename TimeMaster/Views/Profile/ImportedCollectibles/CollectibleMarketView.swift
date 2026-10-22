import SwiftUI

struct CollectibleMarketView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var expansion
    @State private var selectedItem: CollectibleItem?
    @State private var release: Int?
    @State private var category: CollectibleCategory?
    @State private var sort = 0
    @State private var query = ""
    @State private var showsSearch = false

    private var items: [CollectibleItem] {
        let filtered = CollectibleCatalog.items.filter { item in
            (release == nil || item.season == release)
                && (category == nil || category == item.category)
                && (query.isEmpty || "\(item.name) \(item.category.title)".localizedCaseInsensitiveContains(query))
        }
        return filtered.sorted {
            sort == 1 ? $0.name > $1.name : $0.name < $1.name
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EverSpacing.x5) {
                HStack(spacing: EverSpacing.x2) {
                    CollectibleCategoryRail(selection: $category)
                    Menu {
                        Button("All releases") { release = nil }
                        ForEach(Array(Set(CollectibleCatalog.items.map(\.season))).sorted(), id: \.self) { value in
                            Button("Release \(value)") { release = value }
                        }
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "square.stack.3d.up")
                            if let release {
                                Text("\(release)").font(TimeMasterFont.caption()).padding(EverSpacing.x1)
                                    .background(EverColor.background, in: Circle())
                            }
                        }
                    }
                    .accessibilityLabel(release.map { "Release \($0)" } ?? "All releases")
                    .accessibilityIdentifier("market-release")
                    Button { sort = sort == 0 ? 1 : 0 } label: {
                        Image(systemName: sort == 0 ? "arrow.up" : "arrow.down")
                    }
                    .accessibilityLabel(sort == 0 ? "Name: A to Z" : "Name: Z to A")
                    .accessibilityIdentifier("market-sort")
                }
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
                if items.isEmpty {
                    StoreCommerceEmptyRow(title: "No matching previews", detail: "Try another style or clear your search.", symbol: "square.grid.2x2")
                    Button("Clear filters") { category = nil; query = ""; release = nil }.buttonStyle(EverSecondaryButtonStyle())
                }
                Group {
                    let profile = profileStore.profile
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: EverSpacing.x3), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: EverSpacing.x5) {
                        ForEach(items) { item in
                                Button {
                                    withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.56, dampingFraction: 0.82)) {
                                        selectedItem = item
                                    }
                                } label: {
                                    CollectibleOfferCard(item: item, profile: profile, namespace: expansion, expanded: selectedItem?.id == item.id, active: selectedItem == nil)
                                }
                                .buttonStyle(EverPressButtonStyle())
                                .accessibilityIdentifier("market-\(item.id)")
                                .accessibilityLabel("\(item.name), local cosmetic preview")
                        }
                    }
                }
            }
            .padding(EverLayout.phoneInset)
            .padding(.bottom, EverSpacing.x8)
            .everReadableWidth()
            .accessibilityHidden(showsSearch)
        }
        .modifier(EverScrollMotion(appliesSmear: false))
        .everScreenBackground()
        .foregroundStyle(EverColor.textPrimary)
        .timeMasterNavigationTitle("Local previews")
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
                    .accessibilityLabel("Back to shop")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showsSearch = true } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
                    .accessibilityLabel("Search collectibles")
                    .accessibilityIdentifier("market-search")
            }
        }
        .everSheet(isPresented: $showsSearch) {
            Group {
                let profile = profileStore.profile
                CollectibleVisualSearch(profile: profile, query: $query, category: $category, items: CollectibleCatalog.items) {
                    showsSearch = false
                }
            }
        }
        .modifier(CollectibleExpansion(selectedItem: $selectedItem, namespace: expansion))
    }
}

struct CollectibleCollectionView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var expansion
    @State private var selectedItem: CollectibleItem?
    @State private var collectionTab = 0

    private var saved: Bool { collectionTab == 1 }
    private var items: [CollectibleItem] {
        CollectibleCatalog.items.filter { saved ? profileStore.snapshot.savedCollectibleIDs.contains($0.id) : CollectibleItem.selected($0.category, in: profileStore.snapshot)?.id == $0.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EverSpacing.x5) {
                CollectibleTabs(titles: ["Applied", "Saved"], selection: $collectionTab, identifier: "collectible-collection-tabs")
                if items.isEmpty {
                    StoreCommerceEmptyRow(title: saved ? "Keep your favorites close" : "Your collection starts here", detail: saved ? "Tap the heart on a collectible to save it." : "Explore the season and try a new look on your profile.", symbol: saved ? "heart" : "square.stack.3d.up")
                }
                Group {
                    let profile = profileStore.profile
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: EverSpacing.x3), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: EverSpacing.x5) {
                        ForEach(items) { item in
                            Button {
                                withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.56, dampingFraction: 0.82)) {
                                    selectedItem = item
                                }
                            } label: {
                                CollectibleCard(item: item, profile: profile, status: item.name, detail: CollectibleItem.selected(item.category, in: profileStore.snapshot)?.id == item.id ? "Applied locally" : "Saved preview", namespace: expansion, expanded: selectedItem?.id == item.id, active: selectedItem == nil)
                            }.buttonStyle(EverPressButtonStyle()).accessibilityIdentifier("collection-\(item.id)")
                        }
                    }
                }
            }
            .padding(EverLayout.phoneInset)
            .padding(.bottom, EverSpacing.x8)
            .everReadableWidth()
        }
        .modifier(EverScrollMotion()).everScreenBackground().foregroundStyle(EverColor.textPrimary)
        .timeMasterNavigationTitle("Your local styles")
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(TimeMasterToolbarIconButtonStyle())
                    .accessibilityLabel("Back to shop")
            }
        }
        .modifier(CollectibleExpansion(selectedItem: $selectedItem, namespace: expansion))
    }
}

struct CollectibleCategoryRail: View {
    @Binding var selection: CollectibleCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EverSpacing.x2) {
                categoryButton(nil)
                ForEach(CollectibleCategory.allCases) { category in categoryButton(category) }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func categoryButton(_ category: CollectibleCategory?) -> some View {
        Button {
            selection = category
            EverHaptic.selection()
        } label: {
            Image(systemName: category?.symbol ?? "square.grid.2x2")
                .font(.body.weight(.semibold))
                .frame(width: EverLayout.minimumTouchTarget, height: EverLayout.minimumTouchTarget)
        }
        .buttonStyle(TimeMasterActionButtonStyle(prominent: selection == category, circular: true))
        .accessibilityLabel(category?.title ?? "All styles")
        .accessibilityAddTraits(selection == category ? .isSelected : [])
        .accessibilityIdentifier("collectible-category-\(category?.rawValue ?? "all")")
    }
}

struct CollectibleVisualSearch: View {
    let profile: LocalUserProfile
    @Binding var query: String
    @Binding var category: CollectibleCategory?
    let items: [CollectibleItem]
    let onClose: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focused: Bool

    private var results: [CollectibleItem] {
        items.filter {
            (category == nil || $0.category == category)
                && (query.isEmpty || "\($0.name) \($0.category.title)".localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(spacing: EverSpacing.x4) {
            HStack(spacing: EverSpacing.x3) {
                Image(systemName: "magnifyingglass").foregroundStyle(EverColor.textSecondary)
                TextField("Find a collectible", text: $query)
                    .font(TimeMasterFont.body()).focused($focused)
                    .submitLabel(.search)
                    .onSubmit { focused = false; onClose() }
                    .accessibilityIdentifier("collectibles-search-field")
                Button { query = ""; category = nil } label: { Image(systemName: "arrow.counterclockwise") }
                    .accessibilityLabel("Clear filters")
                Button(action: onClose) { Image(systemName: "xmark") }
                    .accessibilityLabel("Close search")
                    .accessibilityIdentifier("collectibles-search-close")
            }
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            CollectibleCategoryRail(selection: $category)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: EverSpacing.x3), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: EverSpacing.x3) {
                    ForEach(results) { item in
                        Button {
                            query = item.name
                            category = item.category
                            focused = false
                            onClose()
                        } label: {
                            VStack(spacing: EverSpacing.x3) {
                                CollectibleArtwork(item: item, profile: profile, active: false)
                                    .aspectRatio(1.4, contentMode: .fit)
                                Text(item.name).font(TimeMasterFont.rowTitle()).multilineTextAlignment(.center)
                            }
                            .padding(EverSpacing.x3)
                            .background { EverSurfaceMaterial() }
                        }
                        .buttonStyle(EverPressButtonStyle())
                        .accessibilityIdentifier("collectible-suggestion-\(item.id)")
                    }
                }
                if results.isEmpty {
                    StoreCommerceEmptyRow(title: "No matching collectibles", detail: "Try another name or choose a style above.", symbol: "magnifyingglass")
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(EverLayout.phoneInset)
        .foregroundStyle(EverColor.textPrimary)
        .everScreenBackground()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("collectibles-visual-search")
        .everSheetBackground()
        .presentationDragIndicator(.visible)
    }
}

struct CollectibleOfferCard: View {
    let item: CollectibleItem
    let profile: LocalUserProfile
    var namespace: Namespace.ID?
    var expanded = false
    var active = true
    var compact = false

    var body: some View {
        Group {
            if compact {
                HStack(spacing: EverSpacing.x4) {
                    artwork.frame(width: EverLayout.minimumTouchTarget * 2, height: EverLayout.minimumTouchTarget * 2)
                    information
                }
            } else {
                VStack(spacing: EverSpacing.x3) {
                    Color.clear.aspectRatio(1, contentMode: .fit).overlay { artwork }
                    information
                }
            }
        }
        .padding(EverSpacing.x3)
        .background { EverSurfaceMaterial() }
        .foregroundStyle(EverColor.textPrimary)
    }

    private var artwork: some View {
        CollectibleCard(
            item: item, profile: profile, status: "", detail: "", namespace: namespace,
            expanded: expanded, showsName: false, showsMetadata: false,
            active: active
        )
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: EverSpacing.x3) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name).font(TimeMasterFont.sectionTitle())
                    .lineLimit(1).minimumScaleFactor(0.65)
                Spacer(minLength: EverSpacing.x1)
                Image(systemName: item.category.symbol).font(TimeMasterFont.caption())
                    .foregroundStyle(EverColor.textSecondary).accessibilityHidden(true)
            }
            Text("Local preview").font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

