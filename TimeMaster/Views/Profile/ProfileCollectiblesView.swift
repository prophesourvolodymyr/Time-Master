import SwiftUI

struct ProfileStyledAvatar: View {
    let profile: LocalUserProfile
    var size: CGFloat = 44
    @EnvironmentObject private var profileStore: LocalProfileStore

    var body: some View {
        ProfileCosmeticAvatar(profile: profile, size: size, item: ProfileCosmetic.selected(.avatar, in: profileStore.snapshot))
    }
}

struct ProfileStyledName: View {
    let text: String
    @EnvironmentObject private var profileStore: LocalProfileStore

    var body: some View {
        ProfileCosmeticName(text: text, item: ProfileCosmetic.selected(.name, in: profileStore.snapshot))
    }
}

struct ProfileBannerDecoration: View {
    @EnvironmentObject private var profileStore: LocalProfileStore

    var body: some View {
        ProfileCosmeticBanner(item: ProfileCosmetic.selected(.entrance, in: profileStore.snapshot))
    }
}

struct ProfileBadgePreview: View {
    @EnvironmentObject private var profileStore: LocalProfileStore

    var body: some View {
        if let tier = profileStore.snapshot.badgePreview {
            ProfileCosmeticBadge(tier: tier, item: ProfileCosmetic.selected(.badge, in: profileStore.snapshot))
        }
    }
}

private enum ProfileCosmeticPalette {
    static func colors(_ item: ProfileCosmetic?) -> [Color] {
        switch item?.variant {
        case 0: return [.white, Color(white: 0.45), .white]
        case 1: return [.white, Color(white: 0.7), .white, Color(white: 0.45)]
        case 2: return [.orange, .white, .orange]
        default: return [.white, .white]
        }
    }
}

private struct ProfileCosmeticAvatar: View {
    let profile: LocalUserProfile
    let size: CGFloat
    let item: ProfileCosmetic?

    var body: some View {
        ProfileAvatar(profile: profile, size: item == nil ? size : max(1, size - 10))
            .frame(width: size, height: size)
            .overlay {
                if let item {
                    Circle()
                        .strokeBorder(AngularGradient(colors: ProfileCosmeticPalette.colors(item), center: .center), style: StrokeStyle(lineWidth: max(2, size * 0.025), dash: item.variant == 1 ? [6, 4] : []))
                    if item.variant == 2 {
                        Circle().trim(from: 0.04, to: 0.28)
                            .stroke(.orange, style: StrokeStyle(lineWidth: max(3, size * 0.05), lineCap: .round))
                    }
                }
            }
    }
}

private struct ProfileCosmeticName: View {
    let text: String
    let item: ProfileCosmetic?

    var body: some View {
        Text(text)
            .font(TimeMasterFont.heading())
            .foregroundStyle(LinearGradient(colors: ProfileCosmeticPalette.colors(item), startPoint: .leading, endPoint: .trailing))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ProfileCosmeticBadge: View {
    let tier: LocalBadgeTier
    let item: ProfileCosmetic?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.lefthalf.filled").accessibilityHidden(true)
            Text("\(tier.title) · Preview")
        }
        .font(TimeMasterFont.caption())
        .foregroundStyle(LinearGradient(colors: ProfileCosmeticPalette.colors(item), startPoint: .topLeading, endPoint: .bottomTrailing))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.surface2, in: Capsule())
        .overlay {
            Capsule().strokeBorder(item?.variant == 2 ? Color.orange : Color.white.opacity(item == nil ? 0.15 : 0.55), lineWidth: item?.variant == 1 ? 2 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tier.title) badge preview. Not identity verification.")
    }
}

private struct ProfileCosmeticBanner: View {
    let item: ProfileCosmetic?

    var body: some View {
        Canvas { context, size in
            guard let item else { return }
            let colors = ProfileCosmeticPalette.colors(item)
            switch item.variant {
            case 0:
                for index in 0..<4 {
                    let radius = size.width * (0.18 + CGFloat(index) * 0.12)
                    let rect = CGRect(x: size.width - radius, y: size.height * 0.5 - radius, width: radius * 2, height: radius * 2)
                    context.stroke(Path(ellipseIn: rect), with: .color(colors[index % colors.count].opacity(0.45)), lineWidth: 2)
                }
            case 1:
                for index in 0..<8 {
                    var path = Path()
                    let x = size.width * CGFloat(index) / 7
                    path.move(to: CGPoint(x: x - size.height * 0.4, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height * 0.4, y: 0))
                    context.stroke(path, with: .color(Color.white.opacity(index.isMultiple(of: 2) ? 0.36 : 0.14)), lineWidth: index.isMultiple(of: 2) ? 2 : 1)
                }
            default:
                let rect = CGRect(x: size.width * 0.6, y: size.height * 0.3, width: size.height, height: size.height)
                context.fill(Path(ellipseIn: rect), with: .linearGradient(Gradient(colors: [.orange.opacity(0.65), .orange.opacity(0.05)]), startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height * 0.8))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.8))
                context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 1)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ProfileCollectiblesView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category: ProfileCosmeticCategory?
    @State private var savedOnly = false
    @State private var selectedItem: ProfileCosmetic?
    @State private var errorMessage: String?

    private var results: [ProfileCosmetic] {
        ProfileCosmetic.catalog.filter {
            (category == nil || $0.category == category)
                && (!savedOnly || profileStore.snapshot.savedCollectibleIDs.contains($0.id))
                && (query.isEmpty || "\($0.title) \($0.category.title)".localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            ProfileSettingsPage(title: "Collectibles") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("MAKE TIME YOURS").font(TimeMasterFont.title())
                    Text("Local cosmetic previews")
                        .font(TimeMasterFont.heading()).foregroundStyle(.orange)
                    Text("Style your TimeMaster profile on this device. No purchases, tokens, trading, ownership claims, or network account. Apply deliberately to save a look; browsing never changes your profile.")
                        .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                }
                collectionFilters
                if !profileStore.snapshot.cosmeticSelections.isEmpty {
                    activeStyles
                }
                if results.isEmpty {
                    ProfileEmptyState(symbol: savedOnly ? "bookmark" : "magnifyingglass", title: savedOnly ? "No saved previews" : "No matching styles", detail: "Try another search or category, or save a style from its detail screen.")
                    Button("Clear filters") { query = ""; category = nil; savedOnly = false }
                        .buttonStyle(ProfilePrimaryButtonStyle())
                }
                ForEach(ProfileCosmeticCategory.allCases) { group in
                    let items = results.filter { $0.category == group }
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group.title).font(TimeMasterFont.heading())
                                .accessibilityAddTraits(.isHeader)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                                ForEach(items) { item in
                                    Button { selectedItem = item } label: {
                                        catalogCard(item)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(item.title). \(item.category.title). Local cosmetic preview.")
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search local styles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.frame(minWidth: 44, minHeight: 44)
                }
            }
            .sheet(item: $selectedItem) { item in
                ProfileCosmeticDetail(item: item)
            }
            .profileErrorAlert($errorMessage)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private var collectionFilters: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                filter("Catalog", symbol: "square.grid.2x2", selected: !savedOnly) { savedOnly = false }
                filter("Saved", symbol: "bookmark", selected: savedOnly) { savedOnly = true }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filter("All", symbol: "circle.grid.2x2", selected: category == nil) { category = nil }
                    ForEach(ProfileCosmeticCategory.allCases) { value in
                        filter(value.title, symbol: value.symbol, selected: category == value) { category = value }
                    }
                }
            }
        }
    }

    private func filter(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { ProfilePillLabel(title: title, symbol: symbol, isSelected: selected) }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var activeStyles: some View {
        ProfileSettingsSection(title: "Applied on this device", footer: "Reset removes a category's applied style, not its saved bookmarks.") {
            ForEach(ProfileCosmeticCategory.allCases) { group in
                if let item = ProfileCosmetic.selected(group, in: profileStore.snapshot) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.title).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                            Text(item.title).font(TimeMasterFont.rowTitle())
                        }
                        Spacer(minLength: 0)
                        Button("Reset") {
                            do { try profileStore.setCosmetic(category: group.rawValue, itemID: nil) }
                            catch { errorMessage = error.localizedDescription }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(profileStore.isReadOnly)
                        .accessibilityLabel("Reset \(group.title)")
                    }
                    .padding(12)
                }
            }
        }
    }

    private func catalogCard(_ item: ProfileCosmetic) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileCosmeticArtwork(item: item)
                .frame(height: 92)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            Text(item.title).font(TimeMasterFont.rowTitle()).foregroundStyle(.white)
            Text("Local cosmetic preview").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            if profileStore.snapshot.cosmeticSelections[item.category.rawValue] == item.id {
                Label("Applied locally", systemImage: "paintbrush.pointed.fill")
                    .font(TimeMasterFont.caption()).foregroundStyle(.orange)
            }
            if profileStore.snapshot.savedCollectibleIDs.contains(item.id) {
                Label("Saved", systemImage: "bookmark.fill")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ProfileStyle.inset)
        .modifier(TimeMasterCardSurface(flat: true))
    }
}

private struct ProfileCosmeticArtwork: View {
    let item: ProfileCosmetic
    @EnvironmentObject private var profileStore: LocalProfileStore

    var body: some View {
        switch item.category {
        case .avatar:
            ProfileCosmeticAvatar(profile: profileStore.profile, size: 80, item: item)
        case .name:
            ProfileCosmeticName(text: profileStore.profile.displayName, item: item)
                .multilineTextAlignment(.center)
        case .badge:
            ProfileCosmeticBadge(tier: profileStore.snapshot.badgePreview ?? .blue, item: item)
        case .entrance:
            ProfileCosmeticBanner(item: item)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct ProfileCosmeticDetail: View {
    let item: ProfileCosmetic
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    private var isApplied: Bool { profileStore.snapshot.cosmeticSelections[item.category.rawValue] == item.id }
    private var isSaved: Bool { profileStore.snapshot.savedCollectibleIDs.contains(item.id) }

    var body: some View {
        NavigationStack {
            ProfileSettingsPage(title: item.title) {
                Text("Local cosmetic preview").font(TimeMasterFont.heading()).foregroundStyle(.orange)
                Text("Live preview for your local profile. Nothing changes until you apply.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                livePreview
                Text(item.category.detail).font(TimeMasterFont.body())
                Text("No payment, minting, trading, or ownership. Cosmetics never change training statistics or earn verification.")
                    .font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                Button(isApplied ? "Applied locally" : "Apply local preview") {
                    do { try profileStore.setCosmetic(category: item.category.rawValue, itemID: item.id) }
                    catch { errorMessage = error.localizedDescription }
                }
                .buttonStyle(ProfilePrimaryButtonStyle())
                .disabled(isApplied || profileStore.isReadOnly)
                if isApplied {
                    Label("This look is saved on your device.", systemImage: "paintbrush.pointed.fill")
                        .font(TimeMasterFont.secondary()).foregroundStyle(.orange)
                }
                Button {
                    do { try profileStore.toggleSavedCollectible(id: item.id) }
                    catch { errorMessage = error.localizedDescription }
                } label: {
                    ProfilePillLabel(title: isSaved ? "Remove from saved" : "Save to collection", symbol: isSaved ? "bookmark.fill" : "bookmark", isSelected: false)
                }
                .buttonStyle(.plain)
                .disabled(profileStore.isReadOnly)
                if profileStore.snapshot.cosmeticSelections[item.category.rawValue] != nil {
                    Button("Reset \(item.category.title)") {
                        do { try profileStore.setCosmetic(category: item.category.rawValue, itemID: nil) }
                        catch { errorMessage = error.localizedDescription }
                    }
                    .frame(minHeight: 44)
                    .disabled(profileStore.isReadOnly)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.frame(minWidth: 44, minHeight: 44)
                }
            }
            .profileErrorAlert($errorMessage)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private func selection(_ category: ProfileCosmeticCategory) -> ProfileCosmetic? {
        item.category == category ? item : ProfileCosmetic.selected(category, in: profileStore.snapshot)
    }

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Theme.surface2
                if let filename = profileStore.profile.bannerFilename,
                   let image = PhotoManager.shared.loadPhoto(filename: filename) {
                    platformImage(image).resizable().scaledToFill()
                }
                ProfileCosmeticBanner(item: selection(.entrance))
            }
            .frame(height: 120)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            ProfileCosmeticAvatar(profile: profileStore.profile, size: 88, item: selection(.avatar))
            ProfileCosmeticName(text: profileStore.profile.displayName, item: selection(.name))
            Text("@\(profileStore.profile.handle)").font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
            if let tier = profileStore.snapshot.badgePreview {
                ProfileCosmeticBadge(tier: tier, item: selection(.badge))
            } else if item.category == .badge {
                ProfileCosmeticBadge(tier: .blue, item: item)
                Text("Blue is shown temporarily here. Applying this skin does not enable a badge tier.")
                    .font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
            }
            Text("Preview only · Your local profile").font(TimeMasterFont.caption()).foregroundStyle(.orange)
        }
        .padding(ProfileStyle.inset)
        .modifier(TimeMasterCardSurface(flat: true))
    }
}
