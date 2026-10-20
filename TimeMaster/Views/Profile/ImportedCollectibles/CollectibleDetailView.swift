import SwiftUI

struct CollectibleDetailView: View {
    let item: CollectibleItem
    let namespace: Namespace.ID
    let sourceID: String
    let onClose: () -> Void
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.collectibleRevealProgress) private var revealProgress
    @Namespace private var drawerSpace
    @State private var drawerScrollOffset: CGFloat = 0
    @State private var tab = 0
    @State private var playback = 0
    @State private var showsPreview = false
    @State private var error: String?
    @State private var visible = false
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.3, dampingFraction: 0.9)))
    private var drawerDrag: CGFloat = 0

    private var equipped: Bool { CollectibleItem.selected(item.category, in: profileStore.snapshot)?.id == item.id }
    private var saved: Bool { profileStore.snapshot.savedCollectibleIDs.contains(item.id) }
    private var drawerExpansion: CGFloat { min(1, max(0, drawerScrollOffset) / (EverLayout.standardRowMinimum * 2)) }

    var body: some View {
        GeometryReader { geometry in
            let expandedHeight = min(geometry.size.width * 0.8, geometry.size.height * 0.34)
            let compactHeight = min(expandedHeight, EverLayout.minimumTouchTarget * 2)
            VStack(spacing: 0) {
                previewControls
                    .padding(.horizontal, EverSpacing.x3)
                    .padding(.top, EverSpacing.x2)
                Group {
                    let profile = profileStore.profile
                    Group {
                        if reduceMotion {
                            artwork(profile)
                        } else {
                            artwork(profile).matchedGeometryEffect(id: sourceID, in: namespace)
                        }
                    }
                    .frame(height: expandedHeight - (expandedHeight - compactHeight) * drawerExpansion)
                    .padding(.horizontal, EverSpacing.x3)
                    .padding(.vertical, EverSpacing.x2)
                    .zIndex(1)
                }
                detailDrawer
                    .offset(y: (reduceMotion ? 0 : (1 - revealProgress) * geometry.size.height + max(0, drawerDrag)))
            }
        }
        .foregroundStyle(EverColor.textPrimary)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onClose() }
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .everSheet(isPresented: $showsPreview) {
            NavigationStack {
                VStack(spacing: 0) {
                    HStack {
                        Text("Local preview · \(item.name)").font(TimeMasterFont.caption())
                        Spacer()
                        Button("Done") { showsPreview = false }
                            .buttonStyle(TimeMasterActionButtonStyle(prominent: true, minimumSize: 52))
                            .accessibilityIdentifier("collectible-preview-done")
                    }.padding(EverSpacing.x3)
                    ProfileView(previewOnly: true, onPreviewClose: { showsPreview = false })
                        .environment(\.collectiblePreviewItem, item)
                        .allowsHitTesting(false)
                }
                .everScreenBackground()
            }.everSheetBackground()
        }
    }

    private func artwork(_ profile: LocalUserProfile) -> some View {
        CollectibleTouchPreview(item: item, profile: profile, playback: playback, active: visible && !showsPreview, revealProgress: revealProgress)
    }

    private var detailDrawer: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(EverColor.borderStrong)
                .frame(width: EverLayout.minimumTouchTarget, height: EverSpacing.x1)
                .frame(maxWidth: .infinity, minHeight: EverLayout.minimumTouchTarget)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: EverSpacing.x2)
                        .onEnded { value in
                            if value.translation.height > EverSpacing.x8 && abs(value.translation.width) < value.translation.height {
                                onClose()
                            }
                        }
                        .updating($drawerDrag) { value, state, _ in
                            state = value.translation.height
                        }
                )
                .accessibilityHidden(true)
            CollectibleTabs(titles: ["Info", "Profile"], selection: $tab, identifier: "collectible-detail-tabs")
                .padding(.horizontal, EverSpacing.x3)
                .padding(.bottom, EverSpacing.x3)
            drawerScroll
                .id(tab)
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("collectible-detail-scroll")
                .onChange(of: tab) { _ in drawerScrollOffset = 0 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: EverRadius.popup, style: .continuous)
                .fill(EverColor.surfaceSecondary)
                .padding(.bottom, -EverRadius.popup)
                .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("collectible-detail-drawer")
    }

    @ViewBuilder private var drawerScroll: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            ScrollView { drawerContent }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, offset in
                    drawerScrollOffset = offset
                }
        } else {
            ScrollView {
                drawerContent.background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: CollectibleDrawerOffsetKey.self, value: -geometry.frame(in: .named(drawerSpace)).minY)
                    }
                }
            }
            .coordinateSpace(name: drawerSpace)
            .onPreferenceChange(CollectibleDrawerOffsetKey.self) { drawerScrollOffset = $0 }
        }
    }

    private var drawerContent: some View {
        VStack(spacing: EverSpacing.x4) {
            if tab == 0 {
                Text(item.name.uppercased())
                    .font(TimeMasterFont.title()).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                info
            } else {
                profilePreview
            }
            if let error {
                Text(error).font(TimeMasterFont.caption()).foregroundStyle(EverColor.error)
                    .accessibilityIdentifier("collectible-error")
            }
        }
        .padding(.horizontal, EverSpacing.x3)
        .padding(.top, EverSpacing.x3)
        .padding(.bottom, EverSpacing.x8)
        .everReadableWidth()
    }

    private var previewControls: some View {
        HStack(alignment: .top, spacing: EverSpacing.x2) {
            Button {
                do { try profileStore.toggleSavedCollectible(id: item.id) }
                catch { self.error = error.localizedDescription }
            } label: {
                Image(systemName: saved ? "heart.fill" : "heart")
            }
            .disabled(profileStore.isReadOnly)
            .accessibilityLabel(saved ? "Unsave collectible" : "Save collectible")
            .accessibilityIdentifier("collectible-save")
            Spacer(minLength: 0)
            Button(action: onClose) { Image(systemName: "xmark") }
                .accessibilityLabel("Close collectible")
                .accessibilityIdentifier("collectible-close")
        }
        .font(.body.weight(.semibold))
        .buttonStyle(TimeMasterToolbarIconButtonStyle())
    }

    private var info: some View {
        VStack(spacing: EverSpacing.x4) {
            VStack(spacing: EverSpacing.x3) {
                Text("Preview")
                    .font(.custom("Inter-Black", size: 48, relativeTo: .largeTitle))
                VStack(spacing: 0) {
                    Text("Style").font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
                    Text(item.category.title).font(TimeMasterFont.display())
                }
                VStack(spacing: EverSpacing.x2) {
                    Text(equipped ? "Applied on this device" : "Available for local preview")
                        .font(TimeMasterFont.caption())
                    Text("No purchase or ownership required")
                        .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
                }
                VStack(spacing: EverSpacing.x2) {
                    Text("Appearance only")
                        .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
                    Text("Tmax").font(TimeMasterFont.display())
                    Text("Stored locally")
                        .font(TimeMasterFont.caption())
                    Text("Cosmetics never grant verification, change statistics, or create an online identity.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(EverColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, EverSpacing.x2)
            }
            .frame(maxWidth: .infinity)
            .padding(EverSpacing.x4)
            .padding(.bottom, EverSpacing.x4)
            .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: EverRadius.card))
            .overlay { EverSpecularRim(shape: RoundedRectangle(cornerRadius: EverRadius.card)) }
            actions
            HStack(spacing: EverSpacing.x2) {
                Button {
                    showsPreview = true
                } label: {
                    Label("Try on profile", systemImage: "person.crop.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("collectible-try-on")
                if item.category == .entrance {
                    Button { playback += 1 } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(TimeMasterToolbarIconButtonStyle())
                        .accessibilityLabel("Replay artwork")
                }
            }
            .font(TimeMasterFont.rowTitle())
            .buttonStyle(EverActionButtonStyle())
            Text(item.detail).font(TimeMasterFont.secondary()).foregroundStyle(EverColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actions: some View {
        VStack(spacing: EverSpacing.x3) {
            Button(equipped ? "Remove local style" : "Apply local style") {
                do {
                    try profileStore.setCosmetic(category: item.category.rawValue, itemID: equipped ? nil : item.id)
                    EverHaptic.selection()
                } catch { self.error = error.localizedDescription }
            }
            .buttonStyle(EverPrimaryButtonStyle())
            .accessibilityIdentifier("collectible-equip")
            .disabled(profileStore.isReadOnly)
            if !equipped, CollectibleItem.selected(item.category, in: profileStore.snapshot) != nil {
                Button("Reset \(item.category.title)") {
                    do { try profileStore.setCosmetic(category: item.category.rawValue, itemID: nil) }
                    catch { self.error = error.localizedDescription }
                }
                .buttonStyle(EverSecondaryButtonStyle())
                .disabled(profileStore.isReadOnly)
            }
            if profileStore.isReadOnly {
                Text(profileStore.errorMessage ?? "Profile storage is read-only. Existing data has not been replaced.")
                    .font(TimeMasterFont.caption()).foregroundStyle(EverColor.warning)
            }
        }
    }

    private var profilePreview: some View {
        VStack(alignment: .leading, spacing: EverSpacing.x4) {
            Text("Your local profile")
                .font(TimeMasterFont.title())
            Text("Try this look on your actual profile without changing your saved appearance.")
                .font(TimeMasterFont.secondary()).foregroundStyle(EverColor.textSecondary)
            CollectibleOfferCard(item: item, profile: profileStore.profile, active: false, compact: true)
            Button("Try on profile") { showsPreview = true }
                .buttonStyle(EverPrimaryButtonStyle())
            Text("Preview only. No verification or ownership is granted.")
                .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
        }
    }
}

private struct CollectibleTouchPreview: View {
    let item: CollectibleItem
    let profile: LocalUserProfile
    let playback: Int
    let active: Bool
    let revealProgress: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.4, dampingFraction: 0.8)))
    private var tilt = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            CollectibleArtwork(item: item, profile: profile, playbackID: playback, active: active)
                .scaleEffect(item.category == .avatar ? 0.72 : 1)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : (1 - revealProgress) * 12 - tilt.height * 14), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : (1 - revealProgress) * -32 + tilt.width * 18), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .overlay {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .updating($tilt) { value, state, transaction in
                                    guard !reduceMotion else { return }
                                    transaction.animation = .interactiveSpring(response: 0.16, dampingFraction: 0.9)
                                    state = CGSize(
                                        width: min(1, max(-1, value.location.x / max(1, geometry.size.width) * 2 - 1)),
                                        height: min(1, max(-1, value.location.y / max(1, geometry.size.height) * 2 - 1))
                                    )
                                }
                        )
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name), \(item.category.title), for \(profile.displayName)")
        .accessibilityHint(reduceMotion ? "" : "Touch and drag to tilt the preview. Release to reset.")
        .accessibilityIdentifier("collectible-touch-preview")
    }
}

struct CollectibleExpansion: ViewModifier {
    @Binding var selectedItem: CollectibleItem?
    let namespace: Namespace.ID
    var sourceID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(selectedItem == nil)
            .accessibilityHidden(selectedItem != nil)
            .overlay {
                if let item = selectedItem {
                    ZStack {
                        CollectibleExpansionBackdrop(reduceTransparency: reduceTransparency)
                        .ignoresSafeArea()
                        .onTapGesture(perform: close)
                        .accessibilityHidden(true)
                        CollectibleDetailView(item: item, namespace: namespace, sourceID: sourceID ?? item.id, onClose: close)
                    }
                    .transition(reduceMotion ? .opacity : .modifier(active: CollectibleReveal(progress: 0), identity: CollectibleReveal(progress: 1)))
                    .zIndex(1)
                }
            }
#if os(iOS)
            .toolbar(selectedItem == nil ? .automatic : .hidden, for: .navigationBar)
#endif
    }

    private func close() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.56, dampingFraction: 0.82)) {
            selectedItem = nil
        }
    }
}

struct CollectibleTabs: View {
    let titles: [String]
    @Binding var selection: Int
    let identifier: String

    var body: some View {
        HStack(spacing: EverSpacing.x1) {
            ForEach(titles.indices, id: \.self) { index in
                Button {
                    selection = index
                    EverHaptic.selection()
                } label: {
                    Text(titles[index])
                        .font(TimeMasterFont.rowTitle())
                        .frame(maxWidth: .infinity, minHeight: EverLayout.minimumTouchTarget)
                }
                .buttonStyle(EverPillTabButtonStyle(isSelected: selection == index))
                .accessibilityAddTraits(selection == index ? .isSelected : [])
                .accessibilityIdentifier("\(identifier)-\(index)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

private struct CollectibleDrawerOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct CollectibleRevealProgressKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

private extension EnvironmentValues {
    var collectibleRevealProgress: CGFloat {
        get { self[CollectibleRevealProgressKey.self] }
        set { self[CollectibleRevealProgressKey.self] = newValue }
    }
}

private struct CollectibleReveal: ViewModifier, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        content.environment(\.collectibleRevealProgress, progress)
    }
}

private struct CollectibleExpansionBackdrop: View {
    let reduceTransparency: Bool
    @Environment(\.collectibleRevealProgress) private var progress
    var body: some View {
        Group {
            if reduceTransparency {
                EverColor.background
            } else {
                Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.2))
            }
        }
        .opacity(progress)
    }
}
