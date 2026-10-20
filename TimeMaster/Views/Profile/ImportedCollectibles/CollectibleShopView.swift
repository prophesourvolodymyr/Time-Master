import SwiftUI

struct CollectibleShopView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @Namespace private var expansion
    @State private var selectedItem: CollectibleItem?
    @State private var query = ""
    @State private var showsSearch = false
    @State private var showsAbout = false
    @State private var category: CollectibleCategory?
    @ScaledMetric(relativeTo: .title2) private var seasonTitleHeight: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var seasonProgressHeight: CGFloat = 92
    @ScaledMetric(relativeTo: .caption) private var seasonLabelHeight: CGFloat = 16

    private var results: [CollectibleItem] {
        CollectibleCatalog.items.filter {
            $0.season == CollectibleCatalog.season && (category == nil || category == $0.category)
                && (query.isEmpty || "\($0.name) \($0.category.title)".localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            EverProfileScaffold(
                compactHeight: EverLayout.standardRowMinimum,
                expandedHeaderHeight: { expandedHeight(width: readableWidth($0)) },
                tabHeight: 0,
                rasterizesContent: false,
                chrome: { width, progress in
                    seasonCover(width: readableWidth(width), progress: progress)
                        .padding(.horizontal, EverSpacing.x3)
                        .everReadableWidth()
                }
            ) {
                VStack(spacing: EverSpacing.x4) {
                    let profile = profileStore.profile
                    Group {
                        VStack(spacing: 0) {
                            ForEach(CollectibleCategory.allCases) { category in
                                let items = results.filter { $0.category == category }
                                if !items.isEmpty {
                                    VStack(spacing: EverSpacing.x4) {
                                        Text(category.title)
                                            .font(TimeMasterFont.heading())
                                            .accessibilityAddTraits(.isHeader)
                                        CollectibleCarousel(items: items, profile: profile, width: readableWidth(geometry.size.width), namespace: expansion, selectedItem: $selectedItem)
                                        .id(items.map(\.id))
                                    }
                                    .padding(.vertical, EverSpacing.x4)
                                    .frame(maxWidth: .infinity)
                                    .background { EverSurfaceMaterial() }
                                    .accessibilityIdentifier("collectible-section-\(category.rawValue)")
                                }
                            }
                        }
                        if results.isEmpty {
                            StoreCommerceEmptyRow(title: "No collectibles found", detail: "Try another name or category.", symbol: "magnifyingglass")
                            Button("Clear search") { query = ""; category = nil }.buttonStyle(EverSecondaryButtonStyle())
                        }
                        HStack(spacing: EverSpacing.x2) {
                            NavigationLink { CollectibleCollectionView() } label: {
                                Label("Collection", systemImage: "square.stack.3d.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .accessibilityIdentifier("collectibles-collection")
                            Button { showsAbout = true } label: {
                                Image(systemName: "info.circle")
                            }
                            .buttonStyle(TimeMasterToolbarIconButtonStyle())
                            .accessibilityLabel("About collectibles")
                        }
                        .font(TimeMasterFont.rowTitle())
                        .buttonStyle(EverActionButtonStyle())
                    }
                    if let warning = profileStore.errorMessage {
                        Text(warning).font(TimeMasterFont.caption()).foregroundStyle(EverColor.warning)
                    }
                }
                .padding(.horizontal, EverSpacing.x3)
                .padding(.bottom, EverSpacing.x8)
                .everReadableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .everScreenBackground()
        .foregroundStyle(EverColor.textPrimary)
        .modifier(CollectibleExpansion(selectedItem: $selectedItem, namespace: expansion))
        .navigationBarBackButtonHidden()
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("collectibles-shop")
        .everSheet(isPresented: $showsSearch) {
            Group {
                let profile = profileStore.profile
                CollectibleVisualSearch(profile: profile, query: $query, category: $category, items: CollectibleCatalog.items.filter { $0.season == CollectibleCatalog.season }) {
                    showsSearch = false
                }
            }
        }
        .everPopup(isPresented: $showsAbout) {
            EverPopup(title: "Made for your Tmax profile", message: "Preview rings, name finishes, badge skins, and profile entrances. Apply or save any look locally on this device. There are no purchases or transactions.", onEscape: { showsAbout = false }) {
                Text("Cosmetics never change your statistics or grant verification. Badge artwork is always a preview.")
                    .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
            } actions: {
                Button("Got it") { showsAbout = false }.buttonStyle(EverPrimaryButtonStyle())
            }
        }
    }

    private func readableWidth(_ width: CGFloat) -> CGFloat {
        max(1, min(width, EverLayout.maximumReadableWidth) - EverSpacing.x3 * 2)
    }

    private func expandedHeight(width: CGFloat) -> CGFloat {
        width / 3 + max(EverLayout.minimumTouchTarget, width / 5) / 2
            + seasonTitleHeight + seasonProgressHeight + EverSpacing.x2 * 3
    }

    private func seasonCover(width: CGFloat, progress: CGFloat) -> some View {
        let compactHeight = EverLayout.standardRowMinimum
        let control = EverLayout.minimumTouchTarget
        let badgeSize = max(control, width / 5)
        let compactBadge = EverSpacing.x8
        let badge = badgeSize + (compactBadge - badgeSize) * progress
        let coverHeight = width / 3
        let titleY = coverHeight + badgeSize / 2 + EverSpacing.x2 + seasonTitleHeight / 2
        let compactTitleLeading = EverSpacing.x2 + control + EverSpacing.x2 + compactBadge + EverSpacing.x2
        let compactTitleWidth = max(1, width - compactTitleLeading - control * 2 - EverSpacing.x2 * 3)
        return ZStack(alignment: .topLeading) {
            CollectibleProfileCover(profile: profileStore.profile)
                .overlay(Color.black.opacity(0.28))
                .modifier(EverProfileCoverMotion(width: width, coverHeight: coverHeight, compactHeight: compactHeight, progress: progress))
                .clipShape(RoundedRectangle(cornerRadius: EverRadius.card))
                .overlay { EverSpecularRim(shape: RoundedRectangle(cornerRadius: EverRadius.card)) }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            VStack(spacing: EverSpacing.x1 * (1 - progress)) {
                Text("\(CollectibleCatalog.season)")
                    .font(TimeMasterFont.display())
                    .scaleEffect(1 - progress * 0.4)
                Text("Preview")
                    .font(TimeMasterFont.caption())
                    .frame(height: seasonLabelHeight * (1 - progress))
                    .opacity(1 - progress)
                    .clipped()
            }
            .frame(width: badge, height: badge)
            .background { EverSurfaceMaterial(radius: EverRadius.button) }
            .position(
                x: width / 2 + (EverSpacing.x2 + control + EverSpacing.x2 + compactBadge / 2 - width / 2) * progress,
                y: coverHeight + (compactHeight / 2 - coverHeight) * progress
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Season \(CollectibleCatalog.season), local preview")
            .accessibilityIdentifier("collectibles-season")
            Text(CollectibleCatalog.seasonName.uppercased())
                .font(TimeMasterFont.title())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: width + (compactTitleWidth - width) * progress, height: seasonTitleHeight)
                .position(
                    x: width / 2 + (compactTitleLeading + compactTitleWidth / 2 - width / 2) * progress,
                    y: titleY + (compactHeight / 2 - titleY) * progress
                )
                .accessibilityAddTraits(.isHeader)
            seasonProgress(width: width)
                .frame(width: width, height: seasonProgressHeight, alignment: .top)
                .opacity(1 - progress)
                .offset(y: titleY + seasonTitleHeight / 2 + EverSpacing.x2)
                .accessibilityHidden(progress > 0.5)
                .allowsHitTesting(false)
            HStack(spacing: EverSpacing.x2) {
                Button { dismiss() } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Back to Profile")
                    .accessibilityIdentifier("collectibles-back")
                Spacer(minLength: 0)
                NavigationLink { CollectibleMarketView() } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .accessibilityLabel("Browse all local previews")
                .accessibilityIdentifier("collectibles-market")
                Button {
                    showsSearch = true
                } label: { Image(systemName: "magnifyingglass") }
                .accessibilityLabel("Search collectibles")
                .accessibilityIdentifier("collectibles-search")
            }
            .font(.body.weight(.semibold))
            .buttonStyle(TimeMasterToolbarIconButtonStyle())
            .padding(.horizontal, EverSpacing.x2)
            .padding(.top, (compactHeight - control) / 2)
        }
        .frame(width: width, height: expandedHeight(width: width) + (compactHeight - expandedHeight(width: width)) * progress, alignment: .top)
        .clipped()
    }

    private func seasonProgress(width: CGFloat) -> some View {
                let selectedCount = profileStore.snapshot.cosmeticSelections.values.filter { CollectibleCatalog.item($0)?.season == CollectibleCatalog.season }.count
                let progress = Double(selectedCount) / Double(CollectibleCategory.allCases.count)
                return VStack(spacing: EverSpacing.x2) {
                    EverProgressBar(value: progress)
                        .scaleEffect(y: 2)
                        .overlay {
                            HStack {
                                ForEach(0..<5) { index in
                                    Rectangle().fill(EverColor.textSecondary).frame(width: 1, height: EverSpacing.x3)
                                    if index < 4 { Spacer(minLength: 0) }
                                }
                            }.accessibilityHidden(true)
                        }
                        .accessibilityLabel("Categories with an applied local preview")
                        .padding(.vertical, EverSpacing.x2)
                    Text("\(selectedCount) of \(CollectibleCategory.allCases.count) styles applied · Local preview")
                        .font(TimeMasterFont.secondary()).monospacedDigit()
                    EverProgressBar(value: progress)
                        .frame(width: width / 3)
                        .accessibilityHidden(true)
                }
    }
}

struct CollectibleCard: View {
    let item: CollectibleItem
    let profile: LocalUserProfile
    let status: String
    let detail: String
    var namespace: Namespace.ID?
    var sourceID: String?
    var expanded = false
    var showsName = true
    var showsMetadata = true
    var active = true
    var focus: CGFloat = 0.5
    var personalization: Double = 1
    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var aspect: CGFloat {
        switch item.category {
        case .avatar: return 1
        case .name: return 3
        case .badge: return 1.2
        case .entrance: return 0.52
        }
    }

    var body: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            card.onScrollVisibilityChange(threshold: 0.65) { visible = $0 }
        } else {
            card.onAppear { visible = true }.onDisappear { visible = false }
        }
    }

    private var card: some View {
        VStack(spacing: EverSpacing.x2) {
            Group {
                if expanded {
                    Color.clear
                } else if let namespace, !reduceMotion {
                    artwork.matchedGeometryEffect(id: sourceID ?? item.id, in: namespace)
                } else {
                    artwork
                }
            }
            .aspectRatio(aspect, contentMode: .fit)
            .padding(.vertical, item.category == .name ? EverSpacing.x4 : EverSpacing.x2)
            if showsName {
                Text(item.name).font(TimeMasterFont.caption()).lineLimit(2).multilineTextAlignment(.center)
            }
            if showsMetadata {
                Text(status).font(TimeMasterFont.rowTitle()).monospacedDigit()
                Text(detail).font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .foregroundStyle(EverColor.textPrimary)
        .accessibilityElement(children: .combine)
    }

    private var artwork: some View {
        CollectibleArtwork(item: item, profile: profile, active: visible && active, personalization: personalization)
            .background {
                if item.category == .name {
                    EverSurfaceMaterial(radius: 999)
                } else if item.category == .entrance {
                    EverSurfaceMaterial(radius: EverRadius.card)
                }
            }
            .scaleEffect(reduceMotion ? 1 : 0.94 + focus * 0.12)
    }
}

private struct CollectibleCarousel: View {
    let items: [CollectibleItem]
    let profile: LocalUserProfile
    let width: CGFloat
    let namespace: Namespace.ID
    @Binding var selectedItem: CollectibleItem?
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var coordinateSpace
    @State private var centers: [String: CGFloat] = [:]
    @ScaledMetric(relativeTo: .body) private var metadataHeight: CGFloat = 56

    private var cardWidth: CGFloat {
        typeSize.isAccessibilitySize ? width * 0.72 : max(1, (width - EverSpacing.x4 * 2 - EverSpacing.x3 * 2) / 3)
    }

    private var centeredID: String? {
        centers.min { abs($0.value - width / 2) < abs($1.value - width / 2) }?.key
            ?? items.dropFirst(items.count / 2).first?.id
    }

    private var rowHeight: CGFloat {
        let aspect: CGFloat
        switch items.first?.category {
        case .name: aspect = 3
        case .badge: aspect = 1.2
        case .entrance: aspect = 0.52
        default: aspect = 1
        }
        return cardWidth / aspect + metadataHeight + (items.first?.category == .name ? EverSpacing.x8 : EverSpacing.x4)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                if #available(iOS 17.0, macOS 14.0, *) {
                    row.scrollTargetLayout()
                } else {
                    row.padding(.horizontal, max(0, (width - cardWidth) / 2))
                }
            }
            .modifier(CollectibleCarouselSnapping(inset: max(0, (width - cardWidth) / 2)))
            .coordinateSpace(name: coordinateSpace)
            .scrollIndicators(.hidden)
            .onPreferenceChange(CollectibleCardCenterKey.self) { centers = $0 }
            .onAppear {
                if let item = items.dropFirst(items.count / 2).first {
                    proxy.scrollTo(item.id, anchor: .center)
                }
            }
        }
        .frame(height: rowHeight)
    }

    private var row: some View {
        HStack(alignment: .top, spacing: EverSpacing.x3) {
            ForEach(items) { item in
                let distance = abs((centers[item.id] ?? (item.id == centeredID ? width / 2 : -width)) - width / 2)
                let focus = max(0, 1 - distance / (cardWidth + EverSpacing.x3))
                let personalization = Double(max(0, (focus - 0.35) / 0.65))
                Button {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.56, dampingFraction: 0.82)) {
                        selectedItem = item
                    }
                } label: {
                    CollectibleCard(
                        item: item, profile: profile, status: item.name,
                        detail: CollectibleItem.selected(item.category, in: profileStore.snapshot)?.id == item.id ? "Applied locally" : "Local preview",
                        namespace: namespace, expanded: selectedItem?.id == item.id,
                        showsName: false, active: selectedItem == nil && centeredID == item.id,
                        focus: focus, personalization: personalization
                    )
                }
                .buttonStyle(EverPressButtonStyle())
                .frame(width: cardWidth)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: CollectibleCardCenterKey.self, value: [item.id: geometry.frame(in: .named(coordinateSpace)).midX])
                    }
                }
                .id(item.id)
                .accessibilityLabel("\(item.name), local cosmetic preview")
                .accessibilityValue(centeredID == item.id ? "Previewing \(profile.displayName)" : "Style preview")
                .accessibilityIdentifier("collectible-\(item.id)")
            }
        }
    }
}

private struct CollectibleCarouselSnapping: ViewModifier {
    let inset: CGFloat
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content
                .contentMargins(.horizontal, inset, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
        } else {
            content
        }
    }
}

private struct CollectibleCardCenterKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}
