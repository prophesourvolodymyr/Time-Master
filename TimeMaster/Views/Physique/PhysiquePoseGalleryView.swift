import SwiftUI
import ImageIO
import Network

@MainActor
struct PhysiquePoseGalleryView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void
    let matchID: String

    @ObservedObject private var cloud = CloudAccountStore.shared
    @StateObject private var connection = GalleryConnection()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.physiquePresentationActive) private var presentationActive
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var selectedPose: PhysiquePose = .front
    @State private var phase: GalleryPhase = .protected
    @State private var currentMatch: PhysiqueMatch?
    @State private var media: [GalleryMedia] = []
    @State private var images: [String: CGImage] = [:]
    @State private var decodeFailures: Set<String> = []
    @State private var hiddenSlots: Set<GallerySlot> = []
    @State private var lifetime: GalleryLifetime?
    @State private var request: GalleryRequest?
    @State private var dataAccountID: String?
    @State private var visible = false
    @State private var attemptedEntry = false
    @State private var information: GalleryInformation?
    @State private var showingInformation = false
    @AccessibilityFocusState private var accessibilityFocus: GalleryFocus?

    private var active: Bool { visible && presentationActive && scenePhase == .active }
    private var sameAccount: Bool { dataAccountID != nil && dataAccountID == cloud.accountID }
    private var pairBlocked: Bool {
        guard let currentMatch else { return false }
        return store.locallyBlockedIDs.contains(currentMatch.opponent.identity.id)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                expiryHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: ProfileStyle.inset * 1.5) {
                        accessStatus
                        if let currentMatch, sameAccount, active, !pairBlocked {
                            identityRails(currentMatch)
                        }
                        VStack(spacing: ProfileStyle.inset * 1.5) {
                            evidencePanel(.you)
                            evidencePanel(.opponent)
                        }
                        .id("pose-evidence")
                    }
                    .frame(maxWidth: ProfileStyle.readableWidth, alignment: .leading)
                    .padding(ProfileStyle.inset)
                    .frame(maxWidth: .infinity)
                }
            }
            #if os(iOS)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Group {
                    if dynamicType.isAccessibilitySize {
                        ScrollView { poseSelector }
                            .frame(maxHeight: 220)
                    } else {
                        poseSelector
                    }
                }
                .padding(ProfileStyle.inset)
                .frame(maxWidth: .infinity)
                .background(Theme.surface)
            }
            #endif
            .onChange(of: selectedPose) { _ in
                images.removeAll()
                decodeFailures.removeAll()
                if phase == .ready || phase == .checking { beginAccessCheck() }
                proxy.scrollTo("pose-evidence", anchor: .top)
            }
        }
        .font(TimeMasterFont.body())
        .foregroundStyle(Theme.textPrimary)
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.toolbarOrange)
        .navigationTitle("Poses")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: close)
            }
            #else
            ToolbarItem(placement: .navigation) {
                Button(action: close) { Label("Back to result", systemImage: "chevron.left") }
                    .physiqueToolbarTarget()
            }
            ToolbarItem(placement: .principal) {
                poseSelector.frame(maxWidth: 360)
                    .physiqueToolbarTarget(shape: .roundedRectangle(cornerRadius: 6), action: {
                        let poses = PhysiquePose.allCases
                        if let index = poses.firstIndex(of: selectedPose) { selectedPose = poses[(index + 1) % poses.count] }
                    })
            }
            #endif
            ToolbarItemGroup(placement: .automatic) {
                Button { navigate(.safety) } label: { Label("Safety", systemImage: "shield") }
                    .physiqueToolbarTarget()
                Button(action: showPrivacyInformation) { Label("Pose privacy", systemImage: "info.circle") }
                    .physiqueToolbarTarget()
            }
        }
        .alert(information?.title ?? "Poses", isPresented: $showingInformation, presenting: information) { item in
            if item.opensPrivacy {
                Button("Privacy and sharing") { navigate(.privacy) }
            }
            Button("Close", role: .cancel) { }
        } message: { item in
            Text(item.message)
        }
        .task(id: request?.id) {
            if let request { await load(request) }
        }
        .task(id: lifetime?.id) {
            if let lifetime { await monitor(lifetime) }
        }
        .onAppear {
            visible = true
            connection.start()
            attemptInitialEntry()
            accessibilityFocus = .status
        }
        .onDisappear {
            visible = false
            connection.stop()
            protect(.protected, clearContext: true)
        }
        .onChange(of: connection.available) { connected in
            if connected == false {
                protect(.failed("Connect to check current pose access. Images are not available offline."), clearContext: true)
            } else if connected == true {
                attemptInitialEntry()
            }
        }
        .onChange(of: scenePhase) { value in
            if value != .active { protect(.protected, clearContext: true) }
        }
        .onChange(of: presentationActive) { value in
            if !value { protect(.protected, clearContext: true) }
        }
        .onChange(of: cloud.accountID) { _ in
            protect(.protected, clearContext: true)
            hiddenSlots.removeAll()
            selectedPose = .front
            attemptedEntry = true
        }
        .onChange(of: matchID) { _ in
            protect(.protected, clearContext: true)
            hiddenSlots.removeAll()
            selectedPose = .front
            attemptedEntry = true
        }
        .onChange(of: store.isStale) { stale in
            if stale { protect(.failed("Unable to check current access. Connect and choose View poses to try again."), clearContext: true) }
        }
        .onChange(of: store.privacyRevision) { _ in applyLocalProtection() }
        .onChange(of: store.locallyBlockedIDs) { _ in applyLocalProtection() }
        .onReceive(store.$snapshot) { reconcile($0) }
        #if os(macOS)
        .onExitCommand {
            if showingInformation { showingInformation = false } else { close() }
        }
        #endif
    }

    @ViewBuilder
    private var expiryHeader: some View {
        if let lifetime, sameAccount, active, phase == .ready || phase == .checking {
            GalleryExpiryReadout(lifetime: lifetime)
                .padding(ProfileStyle.spacing)
                .frame(maxWidth: .infinity)
                .background(Theme.background)
        } else {
            VStack(spacing: 4) {
                Text("EXPIRES IN").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                Text(phase == .expired ? "Expired" : "—").font(TimeMasterFont.display()).monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(ProfileStyle.spacing)
            .background(Theme.background)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var accessStatus: some View {
        Group {
            if !store.signedIn {
                PhysiqueStatusView(title: "Sign in to view poses", detail: "Private match images require your current Tmax account.", systemImage: "lock")
                PhysiqueAction(title: "Account", systemImage: "person.crop.circle") { navigate(.account) }
            } else {
                switch phase {
                case .checking:
                    HStack(spacing: ProfileStyle.spacing) {
                        ProgressView().controlSize(.small)
                        Text("Checking current access").font(TimeMasterFont.secondary())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                case .protected:
                    PhysiqueStatusView(title: "Poses are hidden", detail: "Choose View poses to check this account, result and each image’s current access.", systemImage: "lock")
                    PhysiqueAction(title: "View poses", systemImage: "eye", disabled: !active || connection.available != true) { beginAccessCheck() }
                case .failed(let detail):
                    PhysiqueStatusView(title: "Unable to check access", detail: detail, systemImage: "wifi.exclamationmark")
                    PhysiqueAction(title: "View poses", systemImage: "arrow.clockwise", disabled: !active || connection.available != true) { beginAccessCheck() }
                case .unavailable(let detail):
                    PhysiqueStatusView(title: "Poses unavailable", detail: detail, systemImage: "lock")
                case .expired:
                    PhysiqueStatusView(title: "Media expired", detail: "The ordinary viewing window has ended. The result remains available; a report does not extend image access.", systemImage: "clock")
                case .ready:
                    EmptyView()
                }
            }
        }
        .accessibilityFocused($accessibilityFocus, equals: .status)
    }

    private func identityRails(_ match: PhysiqueMatch) -> some View {
        VStack(alignment: .leading, spacing: ProfileStyle.inset) {
            Text("Identity and awards at match start")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
            PhysiqueCard {
                PhysiqueIdentityRail(identity: match.you.identity, ownerLabel: "You", onBadge: showBadge)
            }
            PhysiqueCard {
                PhysiqueIdentityRail(identity: match.opponent.identity, ownerLabel: "Opponent", onBadge: showBadge)
            }
        }
    }

    private var reflowsPoseChoices: Bool {
        #if os(iOS)
        return dynamicType.isAccessibilitySize
        #else
        return false
        #endif
    }

    private var poseSelector: some View {
        Group {
            if reflowsPoseChoices {
                VStack(spacing: 8) {
                    ForEach(PhysiquePose.allCases) { pose in
                        Button { selectedPose = pose } label: {
                            Label(pose.title, systemImage: pose == selectedPose ? "checkmark.circle.fill" : "circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(ProfileStyle.spacing)
                        }
                        .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: pose == selectedPose))
                        .accessibilityLabel("\(pose.title), \(position(of: pose)) of 3")
                        .accessibilityAddTraits(pose == selectedPose ? .isSelected : [])
                    }
                }
            } else {
                Picker("Pose", selection: $selectedPose) {
                    ForEach(PhysiquePose.allCases) { pose in
                        Text(pose.shortTitle)
                            .tag(pose)
                            .accessibilityLabel("\(pose.title), \(position(of: pose)) of 3")
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Pose")
            }
        }
    }

    private func position(of pose: PhysiquePose) -> Int {
        switch pose {
        case .front: return 1
        case .side: return 2
        case .rear: return 3
        }
    }

    private func evidencePanel(_ owner: GalleryOwner) -> some View {
        let item = item(for: owner)
        let state = presentation(for: owner, item: item)
        let pose = selectedPose
        return PhysiqueCard {
            Text("\(owner.title) · \(pose.title)")
                .font(TimeMasterFont.heading())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: ProfileStyle.spacing) { evidenceActions(owner, pose: pose, item: item, state: state) }
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) { evidenceActions(owner, pose: pose, item: item, state: state) }
            }
            GalleryEvidenceWell(owner: owner.title, pose: pose, state: state)
                .accessibilityFocused($accessibilityFocus, equals: .well(owner))
            if !state.detail.isEmpty {
                Text(state.detail)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if state.canRetry {
                Button { beginAccessCheck() } label: { Label("Retry image", systemImage: "arrow.clockwise") }
                    .buttonStyle(TimeMasterInsetControlStyle())
                    .accessibilityLabel("Retry \(owner.title.lowercased()) \(pose.shortTitle.lowercased()) image")
            }
        }
    }

    @ViewBuilder
    private func evidenceActions(_ owner: GalleryOwner, pose: PhysiquePose, item: GalleryMedia?, state: GalleryPresentation) -> some View {
        if state.canReveal {
            Button { beginAccessCheck(revealing: item?.id, slot: GallerySlot(owner: owner, pose: pose)) } label: {
                Label("View again", systemImage: "eye")
            }
            .buttonStyle(TimeMasterInsetControlStyle())
            .accessibilityLabel("View \(owner.title.lowercased()) \(pose.shortTitle.lowercased()) image again")
        } else {
            Button { hide(owner, pose: pose, item: item) } label: { Label("Hide image", systemImage: "eye.slash") }
                .buttonStyle(TimeMasterInsetControlStyle())
                .accessibilityLabel("Hide \(owner.title.lowercased()) \(pose.shortTitle.lowercased()) image")
                .disabled(!state.canHide)
        }
        Button { report(owner, pose: pose, item: item) } label: {
            Label(item == nil ? "Report match" : "Report image", systemImage: "flag")
        }
        .buttonStyle(TimeMasterInsetControlStyle())
        .accessibilityLabel(item == nil ? "Report match" : "Report \(owner.title.lowercased()) \(pose.shortTitle.lowercased()) image")
        .disabled(!store.signedIn)
    }

    private func item(for owner: GalleryOwner) -> GalleryMedia? {
        guard let currentMatch, sameAccount else { return nil }
        let ownerID = owner == .you ? currentMatch.you.identity.id : currentMatch.opponent.identity.id
        return media.first { $0.ownerID == ownerID && $0.pose == selectedPose }
    }

    private func presentation(for owner: GalleryOwner, item: GalleryMedia?) -> GalleryPresentation {
        guard active, store.signedIn else { return .status("Poses hidden", symbol: "lock") }
        if phase == .expired { return .status("Media expired", symbol: "clock") }
        guard sameAccount else { return .status("Poses hidden", symbol: "lock") }
        if pairBlocked { return .status("Gallery unavailable", symbol: "shield") }
        if lifetime?.remaining == 0 { return .status("Media expired", symbol: "clock") }
        guard phase == .ready, let lifetime else {
            return .status(phase == .checking ? "Checking access" : "Image unavailable", symbol: phase == .checking ? "hourglass" : "photo", loading: phase == .checking)
        }
        if owner == .you && store.localOwnMediaHidden {
            return .status("Your images are hidden", symbol: "hand.raised", detail: "Local privacy protection is active. Check Privacy and sharing for the actual service status.")
        }
        guard let item else {
            let hidden = hiddenSlots.contains(GallerySlot(owner: owner, pose: selectedPose))
            return .status("Image unavailable", symbol: hidden ? "eye.slash" : "photo", detail: hidden ? "You chose to keep this pose hidden. No selected image is currently available." : "No authorized selected image is available for this pose.", hidden: hidden)
        }
        if let expiresAt = item.expiresAt {
            guard expiresAt.isFinite else { return .status("Image unavailable", symbol: "clock", detail: "The image’s viewing deadline cannot be confirmed.") }
            if expiresAt <= lifetime.serverNow { return .status("Media expired", symbol: "clock") }
        }
        switch item.status {
        case "expired": return .status("Media expired", symbol: "clock")
        case "sharingWithdrawn": return .status("Sharing withdrawn", symbol: "hand.raised")
        case "removed": return .status("Image removed", symbol: "photo")
        case "blocked": return .status("Gallery unavailable", symbol: "shield")
        case "reported": return .status("Image unavailable", symbol: "shield", detail: "Access to this image is restricted by the service.")
        case "hidden": return .status("Hidden by you", symbol: "eye.slash", hidden: true)
        case "available":
            if store.isMediaHidden(item.id) || hiddenSlots.contains(GallerySlot(owner: owner, pose: selectedPose)) {
                return .status("Hidden by you", symbol: "eye.slash", detail: "Hidden for this account’s current session on this device. No change on another device is confirmed.", hidden: true, reveal: true)
            }
            if let image = images[item.id] { return GalleryPresentation(title: "Selected still", image: image, canHide: true) }
            if decodeFailures.contains(item.id) {
                return .status("Image unavailable", symbol: "photo", detail: "This selected still could not be decoded. Retry checks its current access again.", retry: true, hide: true)
            }
            return .status("Loading image", symbol: "photo", loading: true, hide: true)
        default:
            return .status("Image unavailable", symbol: "photo", detail: "Current permission or completed checks are not available for this image.")
        }
    }

    private func attemptInitialEntry() {
        guard !attemptedEntry, active, connection.available == true else { return }
        attemptedEntry = true
        beginAccessCheck()
    }

    private func beginAccessCheck(revealing id: String? = nil, slot: GallerySlot? = nil) {
        guard active, connection.available == true, let accountID = cloud.accountID else { return }
        images.removeAll()
        decodeFailures.removeAll()
        dataAccountID = accountID
        phase = .checking
        request = GalleryRequest(accountID: accountID, pose: selectedPose, revealID: id, revealSlot: slot)
    }

    private func load(_ pending: GalleryRequest) async {
        let started = ContinuousClock().now
        let previousRefresh = store.lastRefreshedAt
        await store.refresh()
        guard accepts(pending) else { return }
        guard !store.isStale, let snapshot = store.snapshot, let refreshedAt = store.lastRefreshedAt, refreshedAt != previousRefresh else {
            protect(.failed("Current access could not be confirmed. Choose View poses to try again."), clearContext: true)
            return
        }
        guard snapshot.account.consent.adult, snapshot.account.restrictedReason == nil else {
            protect(.unavailable("This account does not currently have adult pose-viewing access. Open Account or Safety for help."), clearContext: true)
            return
        }
        do {
            let match = try await store.getMatch(matchID)
            guard accepts(pending) else { return }
            guard eligible(match), match.you.identity.id == snapshot.account.identity.id else {
                protect(.unavailable("This result does not currently permit a pose gallery."), clearContext: true)
                return
            }
            guard !store.locallyBlockedIDs.contains(match.opponent.identity.id) else {
                protect(.unavailable("Gallery access is unavailable. Local safety protection remains active."), clearContext: true)
                return
            }
            guard let finalization = match.finalizedAt, let serviceExpiry = match.mediaExpiresAt else {
                protect(.unavailable("The service has not supplied a confirmed viewing deadline."), clearContext: true)
                return
            }
            let expiry = min(serviceExpiry, finalization + 86_400)
            let serverNow = snapshot.serverTime + GalleryElapsed.seconds(since: started)
            guard expiry.isFinite, serverNow.isFinite, finalization.isFinite, finalization <= serverNow else {
                protect(.unavailable("The service’s viewing deadline cannot be confirmed."), clearContext: true)
                return
            }
            guard expiry > serverNow else {
                protect(.expired, clearContext: true)
                return
            }
            let response = try await store.gallery(matchID, revealing: pending.revealID)
            guard accepts(pending) else { return }
            let receivedNow = snapshot.serverTime + GalleryElapsed.seconds(since: started)
            guard expiry > receivedNow else {
                protect(.expired, clearContext: true)
                return
            }
            let owners = Set([match.you.identity.id, match.opponent.identity.id])
            let permitted = response.filter { owners.contains($0.ownerID) }
            let uniqueIDs = Set(permitted.map(\.id))
            let uniqueSlots = Set(permitted.map { "\($0.ownerID):\($0.pose.rawValue)" })
            guard uniqueIDs.count == permitted.count, uniqueSlots.count == permitted.count else {
                protect(.unavailable("The service’s selected-image references could not be confirmed."), clearContext: true)
                return
            }
            let currentLifetime = GalleryLifetime(expiresAt: expiry, serverNow: receivedNow)
            guard stillPermitted(match) else {
                protect(.protected, clearContext: true)
                return
            }
            currentMatch = match
            media = permitted.map { GalleryMedia(id: $0.id, ownerID: $0.ownerID, pose: $0.pose, status: $0.status, expiresAt: $0.expiresAt) }
            lifetime = currentLifetime
            applyLocalProtection()
            if let slot = pending.revealSlot {
                let ownerID = slot.owner == .you ? match.you.identity.id : match.opponent.identity.id
                if let target = permitted.first(where: { $0.ownerID == ownerID && $0.pose == slot.pose }),
                   target.status == "available", target.id == pending.revealID || pending.revealID == nil,
                   target.expiresAt.map({ $0.isFinite && $0 > currentLifetime.serverNow }) != false,
                   !(slot.owner == .you && store.localOwnMediaHidden) {
                    store.revealMedia(target.id)
                    hiddenSlots.remove(slot)
                }
            }
            phase = .ready
            let selected = permitted.filter {
                $0.pose == pending.pose && $0.status == "available" && $0.expiresAt.map({ $0.isFinite && $0 > currentLifetime.serverNow }) != false &&
                !store.isMediaHidden($0.id) && !hiddenSlots.contains(GallerySlot(owner: $0.ownerID == match.you.identity.id ? .you : .opponent, pose: $0.pose)) &&
                !($0.ownerID == match.you.identity.id && store.localOwnMediaHidden)
            }
            await withTaskGroup(of: GalleryDecodedImage.self) { group in
                for item in selected {
                    let id = item.id
                    let encoded = item.imageBase64
                    group.addTask { GalleryDecodedImage(id: id, image: Self.decode(encoded)) }
                }
                for await decoded in group {
                    guard stillPermitted(match) else {
                        if accepts(pending) { protect(.protected, clearContext: true) }
                        group.cancelAll()
                        break
                    }
                    guard accepts(pending), phase == .ready, lifetime?.id == currentLifetime.id, currentLifetime.remaining > 0,
                          !store.isMediaHidden(decoded.id), let item = media.first(where: { $0.id == decoded.id }),
                          item.expiresAt.map({ $0.isFinite && $0 > currentLifetime.serverNow }) != false,
                          !(item.ownerID == match.you.identity.id && store.localOwnMediaHidden) else { continue }
                    if let image = decoded.image { images[decoded.id] = image } else { decodeFailures.insert(decoded.id) }
                }
            }
        } catch is CancellationError {
        } catch {
            guard accepts(pending) else { return }
            if let policy = store.policy, !policy.ready {
                protect(.unavailable(policy.unavailableReason ?? "The service has not enabled protected pose access."), clearContext: true)
            } else {
                protect(.failed("The service could not confirm current pose access. No offline images are retained. Choose View poses to try again."), clearContext: true)
            }
        }
    }

    private func accepts(_ pending: GalleryRequest) -> Bool {
        !Task.isCancelled && request?.id == pending.id && cloud.accountID == pending.accountID && active && connection.available == true && !store.isStale && selectedPose == pending.pose
    }

    private func eligible(_ match: PhysiqueMatch) -> Bool {
        match.id == matchID && match.stage == .completed && match.result?.isJudged == true && match.galleryAvailable && match.finalizedAt != nil
    }

    private func stillPermitted(_ match: PhysiqueMatch) -> Bool {
        guard let account = store.account, account.identity.id == match.you.identity.id,
              account.consent.adult, account.restrictedReason == nil,
              !store.locallyBlockedIDs.contains(match.opponent.identity.id) else { return false }
        guard let updated = store.match, updated.id == matchID else { return true }
        return eligible(updated) && updated.you.identity == match.you.identity && updated.opponent.identity == match.opponent.identity &&
            updated.result?.outcome == match.result?.outcome && updated.result?.corrected == match.result?.corrected &&
            updated.finalizedAt == match.finalizedAt && updated.mediaExpiresAt == match.mediaExpiresAt
    }

    private func monitor(_ lease: GalleryLifetime) async {
        while !Task.isCancelled && lifetime?.id == lease.id && active {
            let now = lease.serverNow
            let itemDelay = media.lazy.compactMap(\.expiresAt).filter { $0.isFinite && $0 > now }.map { $0 - now }.min() ?? lease.remaining
            let renewal = max(0, 30 - lease.elapsed)
            let delay = max(0, min(lease.remaining, itemDelay, renewal))
            do { try await ContinuousClock().sleep(for: .seconds(min(delay, 30))) } catch { return }
            guard lifetime?.id == lease.id, active else { return }
            if lease.remaining <= 0 {
                protect(.expired, clearContext: false)
                accessibilityFocus = .status
                return
            }
            for item in media where item.expiresAt.map({ $0 <= lease.serverNow }) == true { images.removeValue(forKey: item.id) }
            if lease.elapsed >= 30 {
                beginAccessCheck()
                return
            }
        }
    }

    private func reconcile(_ snapshot: PhysiqueSnapshot?) {
        guard sameAccount, let currentMatch else { return }
        guard let snapshot, snapshot.account.identity.id == currentMatch.you.identity.id,
              snapshot.account.consent.adult, snapshot.account.restrictedReason == nil else {
            protect(.unavailable("Current account access is unavailable."), clearContext: true)
            return
        }
        if let lifetime, snapshot.serverTime >= lifetime.expiresAt {
            protect(.expired, clearContext: false)
            accessibilityFocus = .status
            return
        }
        if let updated = snapshot.match, updated.id == matchID {
            guard eligible(updated) else {
                protect(.unavailable("This result no longer permits a pose gallery. Return to the updated result."), clearContext: true)
                return
            }
            if updated.result?.corrected != currentMatch.result?.corrected || updated.result?.outcome != currentMatch.result?.outcome ||
                updated.finalizedAt != currentMatch.finalizedAt || updated.mediaExpiresAt != currentMatch.mediaExpiresAt ||
                updated.you.identity != currentMatch.you.identity || updated.opponent.identity != currentMatch.opponent.identity {
                protect(.protected, clearContext: true)
            }
        }
    }

    private func applyLocalProtection() {
        guard sameAccount else { return }
        if pairBlocked {
            protect(.unavailable("Gallery access is unavailable. Local safety protection remains active."), clearContext: true)
            return
        }
        if store.localOwnMediaHidden {
            for pose in PhysiquePose.allCases { hiddenSlots.insert(GallerySlot(owner: .you, pose: pose)) }
            for item in media where item.ownerID == currentMatch?.you.identity.id && !store.isMediaHidden(item.id) { store.hideMedia(item.id) }
        }
        for item in media where store.isMediaHidden(item.id) || (item.ownerID == currentMatch?.you.identity.id && store.localOwnMediaHidden) {
            images.removeValue(forKey: item.id)
        }
    }

    private func hide(_ owner: GalleryOwner, pose: PhysiquePose, item: GalleryMedia?) {
        hiddenSlots.insert(GallerySlot(owner: owner, pose: pose))
        if let item {
            images.removeValue(forKey: item.id)
            store.hideMedia(item.id)
        }
        accessibilityFocus = .well(owner)
    }

    private func report(_ owner: GalleryOwner, pose: PhysiquePose, item: GalleryMedia?) {
        hide(owner, pose: pose, item: item)
        let target = PhysiqueReportTarget(kind: item == nil ? "match" : "image", id: item?.id ?? matchID, matchID: matchID)
        navigate(.report(target))
    }

    private func protect(_ nextPhase: GalleryPhase, clearContext: Bool) {
        attemptedEntry = true
        request = nil
        images.removeAll()
        decodeFailures.removeAll()
        lifetime = nil
        phase = nextPhase
        if clearContext {
            showingInformation = false
            information = nil
            currentMatch = nil
            media.removeAll()
            dataAccountID = nil
        }
    }

    private func close() {
        protect(.protected, clearContext: true)
        dismiss()
    }

    private func navigate(_ route: PhysiqueRoute) {
        protect(.protected, clearContext: true)
        onOpen(route)
    }

    private func showBadge(_ badge: PhysiqueBadge) {
        information = GalleryInformation(title: badge.title, message: badge.detail + "\n\nShown as authorized at match start; this is not a new award.", opensPrivacy: false)
        showingInformation = true
    }

    private func showPrivacyInformation() {
        let expiry = lifetime.map { Date(timeIntervalSince1970: $0.expiresAt).formatted(date: .complete, time: .complete) } ?? "The service has not confirmed a current viewing deadline."
        information = GalleryInformation(title: "Pose privacy", message: "Expiry: \(expiry)\n\nOnly authenticated matched participants with current permission can view these selected, face-obscured stills. The ordinary window ends 24 hours after service finalization. A report hold never extends this viewer.\n\nFace obscuring is not anonymity. Operating-system screenshots or external recordings cannot be prevented or recalled by this app.", opensPrivacy: true)
        showingInformation = true
    }

    nonisolated private static func decode(_ encoded: String?) -> CGImage? {
        guard !Task.isCancelled, let encoded, encoded.utf8.count <= 2_000_000,
              let data = Data(base64Encoded: encoded),
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0,
              width.doubleValue * height.doubleValue <= 24_000_000 else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 2_048
        ] as CFDictionary)
    }
}

private enum GalleryOwner: String, Hashable {
    case you, opponent
    var title: String { self == .you ? "You" : "Opponent" }
}

private enum GalleryFocus: Hashable {
    case status, well(GalleryOwner)
}

private enum GalleryPhase: Equatable {
    case protected, checking, ready, expired, failed(String), unavailable(String)
}

private struct GallerySlot: Hashable {
    let owner: GalleryOwner
    let pose: PhysiquePose
}

private struct GalleryMedia {
    let id: String
    let ownerID: String
    let pose: PhysiquePose
    let status: String
    let expiresAt: Double?
}

private struct GalleryRequest {
    let id = UUID()
    let accountID: String
    let pose: PhysiquePose
    let revealID: String?
    let revealSlot: GallerySlot?
}

private struct GalleryLifetime {
    let id = UUID()
    let expiresAt: Double
    let checkedInstant = ContinuousClock().now
    let checkedServerTime: Double
    init(expiresAt: Double, serverNow: Double) {
        self.expiresAt = expiresAt
        checkedServerTime = serverNow
    }
    var elapsed: Double { GalleryElapsed.seconds(since: checkedInstant) }
    var serverNow: Double { checkedServerTime + elapsed }
    var remaining: Double { max(0, expiresAt - serverNow) }
}

private enum GalleryElapsed {
    static func seconds(since instant: ContinuousClock.Instant) -> Double {
        let elapsed = instant.duration(to: ContinuousClock().now).components
        return max(0, Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1_000_000_000_000_000_000)
    }
}

private struct GalleryDecodedImage: @unchecked Sendable {
    let id: String
    let image: CGImage?
}

private struct GalleryInformation {
    let title: String
    let message: String
    let opensPrivacy: Bool
}

private struct GalleryPresentation {
    let title: String
    var symbol = "photo"
    var detail = ""
    var image: CGImage? = nil
    var loading = false
    var isHidden = false
    var canReveal = false
    var canRetry = false
    var canHide = false

    static func status(_ title: String, symbol: String, detail: String = "", loading: Bool = false, hidden: Bool = false, reveal: Bool = false, retry: Bool = false, hide: Bool = false) -> Self {
        Self(title: title, symbol: symbol, detail: detail, loading: loading, isHidden: hidden, canReveal: reveal, canRetry: retry, canHide: hide)
    }
}

private struct GalleryEvidenceWell: View {
    let owner: String
    let pose: PhysiquePose
    let state: GalleryPresentation
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Rectangle()
            .fill(Theme.background)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    if let image = state.image {
                        Image(decorative: image, scale: 1, orientation: .up)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .allowsHitTesting(false)
                    } else {
                        VStack(spacing: ProfileStyle.spacing) {
                            if state.loading { ProgressView() } else { Image(systemName: state.symbol).font(.title2) }
                            Text(state.title).font(TimeMasterFont.label()).multilineTextAlignment(.center)
                        }
                        .padding(ProfileStyle.inset)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
            .overlay {
                Rectangle().strokeBorder(contrast == .increased ? Color.white.opacity(0.5) : Theme.separator, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .transaction { $0.animation = nil; $0.disablesAnimations = true }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(owner), \(pose.title), \(state.image == nil ? state.title : "selected still, face obscured")")
    }
}

private struct GalleryExpiryReadout: View {
    let lifetime: GalleryLifetime
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var finePrecision = false
    @State private var reducedUpdates = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: finePrecision && !reducedUpdates ? 1 : 60)) { _ in
            let value = label
            VStack(spacing: 4) {
                Text("EXPIRES IN").font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                Text(value)
                    .font(TimeMasterFont.display())
                    .monospacedDigit()
                    .contentTransition(.opacity)
                    .animation(reduceMotion || reducedUpdates ? nil : .easeOut(duration: 0.18), value: value)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Expires in")
            .accessibilityValue(value)
        }
        .task(id: lifetime.id) {
            updatePowerState()
            finePrecision = lifetime.remaining <= 3_600
            if !finePrecision {
                do { try await Task.sleep(nanoseconds: UInt64(max(0, lifetime.remaining - 3_600) * 1_000_000_000)) } catch { return }
                finePrecision = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in updatePowerState() }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in updatePowerState() }
    }

    private var label: String {
        let seconds = max(0, Int(ceil(lifetime.remaining)))
        if seconds == 0 { return "Expired" }
        if reducedUpdates && seconds < 60 { return "Less than one minute" }
        if seconds >= 3_600 { return "\(seconds / 3_600) hr \((seconds % 3_600) / 60) min" }
        return "\(seconds / 60) min \(seconds % 60) sec"
    }

    private func updatePowerState() {
        let process = ProcessInfo.processInfo
        reducedUpdates = process.isLowPowerModeEnabled || process.thermalState == .serious || process.thermalState == .critical
    }
}

@MainActor
private final class GalleryConnection: ObservableObject {
    @Published private(set) var available: Bool?
    private var monitor: NWPathMonitor?
    private var generation = UUID()
    private let queue = DispatchQueue(label: "com.tmax.physique.gallery.connection")

    func start() {
        guard monitor == nil else { return }
        generation = UUID()
        let version = generation
        let next = NWPathMonitor()
        next.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard self?.generation == version else { return }
                self?.available = connected
            }
        }
        monitor = next
        next.start(queue: queue)
    }

    func stop() {
        generation = UUID()
        monitor?.cancel()
        monitor = nil
        available = nil
    }

    deinit { monitor?.cancel() }
}
