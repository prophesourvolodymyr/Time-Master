import SwiftUI
import CoreText

@MainActor
struct PhysiqueBadgesCountryView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var accountStore = CloudAccountStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var statusFocused: Bool
    @State private var account: PhysiqueAccount?
    @State private var accountID: String?
    @State private var serverTime: Double?
    @State private var generation = UUID()
    @State private var savedCountry = ""
    @State private var draftCountry = ""
    @State private var countryChoices: [CountryChoice] = []
    @State private var countriesByCode: [String: CountryChoice] = [:]
    @State private var countryExpanded = false
    @State private var expandedBadges: Set<String> = []
    @State private var isRefreshing = false
    @State private var readError: String?
    @State private var saveState: SaveState = .idle
    @State private var saveDetail: String?
    @State private var pendingCountry: String?
    @State private var countryChangedElsewhere = false
    @State private var confirmsClose = false
    @State private var isVisible = false
    @State private var badgeHelpExpanded = false

    private enum SaveState: Equatable {
        case idle, saving, unconfirmed, saved, checked
    }

    private struct CountryChoice: Identifiable {
        let code: String
        let name: String
        let flag: String?
        var id: String { code }
    }

    private var activeAccountID: String? {
        accountStore.restored && !accountStore.busy ? accountStore.accountID : nil
    }

    private var visibleAccount: PhysiqueAccount? {
        guard activeAccountID != nil, accountID == activeAccountID else { return nil }
        return account
    }

    private var isDirty: Bool { draftCountry != savedCountry }
    private var isSaving: Bool { saveState == .saving }
    private var needsStatusCheck: Bool { saveState == .unconfirmed }
    private var validDraft: Bool { draftCountry.isEmpty || countriesByCode[draftCountry] != nil }
    private var canEdit: Bool {
        visibleAccount != nil && visibleAccount?.restrictedReason == nil && !isSaving && !isRefreshing && !store.busy
    }
    private var canSave: Bool {
        canEdit && isDirty && validDraft && !needsStatusCheck && !store.loading && scenePhase == .active
    }

    var body: some View {
        PhysiqueScreen(title: "Battle identity", subtitle: "Badges and optional country or region") {
            if scenePhase != .active {
                PhysiqueStatusView(title: "Battle identity is private", detail: "Return to view your current identity.", systemImage: "lock")
            } else if !accountStore.restored || accountStore.busy {
                ProgressView("Restoring account…")
            } else if activeAccountID == nil {
                PhysiqueStatusView(title: "Sign in to change battle identity", detail: "Your country and Physique badges belong to your signed-in account.", systemImage: "person.crop.circle")
                PhysiqueAction(title: "Open account", systemImage: "person.crop.circle") { onOpen(.account) }
            } else if let account = visibleAccount {
                identityPreview(account.identity)
                freshness
                countryEditor
                if let reason = account.restrictedReason {
                    PhysiqueStatusView(title: "Identity changes unavailable", detail: reason, systemImage: "lock")
                    PhysiqueAction(title: "Open safety", systemImage: "hand.raised") { onOpen(.safety) }
                }
                currentStanding(account.identity)
                badgeCollection(account.identity)
            } else if isRefreshing || store.loading {
                ProgressView("Loading battle identity…")
            } else {
                PhysiqueStatusView(title: "Battle identity unavailable", detail: readError ?? "Your current identity has not been confirmed for this account.")
                refreshButton
            }
        }
        .navigationTitle("Battle identity")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: requestClose)
                    .physiqueToolbarTarget()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(countryChangedElsewhere ? "Save my selection" : "Save") {
                    Task { await saveCountry() }
                }
                .physiqueToolbarTarget()
                .disabled(!canSave)
                .tint(Theme.toolbarOrange)
                .accessibilityHint("Publishes only your selected country or region after the service confirms it.")
            }
        }
        .interactiveDismissDisabled(isDirty || isSaving || needsStatusCheck)
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        #endif
        .task(id: activeAccountID) {
            await loadAccount()
        }
        .task(id: locale.identifier) {
            loadCountryChoices()
        }
        .onAppear { isVisible = true }
        .onDisappear {
            isVisible = false
            generation = UUID()
        }
        .onChange(of: accountStore.accountID) { _ in clearAccount() }
        .onChange(of: accountStore.busy) { busy in
            if busy { clearAccount() }
        }
        .onChange(of: store.snapshot?.serverTime) { _ in
            receiveStoreSnapshot()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active, activeAccountID != nil, !isSaving {
                Task { await refreshIdentity(checkingSave: needsStatusCheck) }
            }
        }
        .onChange(of: draftCountry) { _ in
            if saveState == .saved || saveState == .checked {
                saveState = .idle
                saveDetail = nil
            }
        }
        .alert(isSaving || needsStatusCheck ? "Close without confirmation?" : "Discard country change?", isPresented: $confirmsClose) {
            Button(isSaving || needsStatusCheck ? "Keep open" : "Keep editing", role: .cancel) { }
            Button(isSaving || needsStatusCheck ? "Close" : "Discard", role: .destructive) { dismiss() }
        } message: {
            if isSaving || needsStatusCheck {
                Text("Closing does not cancel a save already sent. Reopen Battle identity to check the actual saved country.")
            } else {
                Text("Your unsaved country selection will be discarded. Your saved identity will not change.")
            }
        }
        #if os(macOS)
        .onExitCommand {
            if countryExpanded {
                countryExpanded = false
            } else {
                requestClose()
            }
        }
        #endif
    }

    private func identityPreview(_ identity: PhysiqueIdentity) -> some View {
        PhysiqueSection(title: "Preview") {
            PhysiqueCard {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    HStack(alignment: .top, spacing: ProfileStyle.spacing) {
                        Image(systemName: "person.crop.circle")
                            .font(.title)
                            .foregroundStyle(ProfileStyle.secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(identity.displayName)
                                .font(TimeMasterFont.heading())
                                .fixedSize(horizontal: false, vertical: true)
                            countryLabel(draftCountry, unavailablePrefix: "Saved region unavailable")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if isDirty {
                        Label(draftCountry.isEmpty ? "Removal not saved" : "Unsaved country", systemImage: "pencil")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(Theme.toolbarOrange)
                    }
                    if !identity.badges.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: ProfileStyle.spacing, alignment: .top)], alignment: .leading, spacing: ProfileStyle.spacing) {
                            ForEach(identity.badges) { badge in
                                Button {
                                    expandedBadges.insert(badge.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        PhysiqueBadgeMedallion(badge: badge)
                                            .accessibilityHidden(true)
                                        Text(badge.title.isEmpty ? "Badge" : badge.title)
                                            .font(TimeMasterFont.rowTitle())
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text("Earned")
                                            .font(TimeMasterFont.caption())
                                            .foregroundStyle(ProfileStyle.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    #if os(iOS)
                                    .frame(minHeight: ProfileStyle.touchTarget)
                                    #endif
                                    .accessibilityHidden(true)
                                }
                                .accessibilityLabel("Your \(badge.title.isEmpty ? "badge" : badge.title), earned")
                                .accessibilityHint("Expands its meaning in the Badges section below.")
                                .accessibilityAddTraits(.isButton)
                                .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    Text("Only country is a draft. Badges and standing come from the service.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var freshness: some View {
        if isRefreshing || store.loading {
            ProgressView("Updating identity…")
        }
        if let readError {
            PhysiqueStatusView(title: "Identity not refreshed", detail: readError)
            if let serverTime {
                Text("Last confirmed service snapshot: \(Date(timeIntervalSince1970: serverTime).formatted(date: .abbreviated, time: .shortened))")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
            }
        }
        if let stage = store.match?.stage, !stage.terminal, stage != .idle {
            Text("\(stage.title). Badges and standing stay unchanged until an authoritative update.")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var countryEditor: some View {
        PhysiqueSection(title: "Country or region · Optional") {
            PhysiqueCard {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    Text("Optional and self-declared, not verified. Shown to paired opponents and on permitted public battle identity. Never used for judging.")
                        .font(TimeMasterFont.body())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("No location access. Choosing a country does not enable public listing or change consent.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    #if os(iOS)
                    DisclosureGroup(isExpanded: $countryExpanded) {
                        countryPicker
                            .pickerStyle(.wheel)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Country or region")
                                .font(TimeMasterFont.rowTitle())
                            Text(countryName(draftCountry))
                                .font(TimeMasterFont.body())
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(minHeight: ProfileStyle.touchTarget, alignment: .leading)
                    }
                    .disabled(!canEdit)
                    #else
                    countryLabel(draftCountry, unavailablePrefix: "Saved region unavailable")
                    countryPicker
                        .pickerStyle(.menu)
                    #endif
                    if !draftCountry.isEmpty {
                        Button("Remove country", role: .destructive) { draftCountry = "" }
                            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                            .disabled(!canEdit)
                            .accessibilityHint("Clears the draft. Save is required to confirm removal from your public identity.")
                            #if os(iOS)
                            .frame(minHeight: ProfileStyle.touchTarget)
                            #endif
                    }
                    if isDirty {
                        Text("Saved country: \(countryName(savedCountry))")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Use saved choice", action: useSavedCountry)
                            .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                            .disabled(isSaving || isRefreshing)
                            #if os(iOS)
                            .frame(minHeight: ProfileStyle.touchTarget)
                            #endif
                    }
                    if countryChangedElsewhere {
                        Label("Saved country changed elsewhere. Your unsaved choice is retained; use the saved choice or deliberately save your selection.", systemImage: "arrow.triangle.2.circlepath")
                            .font(TimeMasterFont.secondary())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !validDraft {
                        Text("Saved region unavailable. Remove it or choose a listed country; it will not be silently replaced.")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    saveFeedback
                    refreshButton
                }
            }
        }
    }

    private var countryPicker: some View {
        Picker("Country or region", selection: $draftCountry) {
            Text("Not shown").tag("")
            if !draftCountry.isEmpty, countriesByCode[draftCountry] == nil {
                Text("Saved region unavailable").tag(draftCountry)
            }
            ForEach(countryChoices) { country in
                Text(country.name).tag(country.code)
            }
        }
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        .disabled(!canEdit || countryChoices.isEmpty)
        .accessibilityValue(countryName(draftCountry))
        .accessibilityHint("Optional, manually selected and self-declared. Selecting a value does not save it.")
    }

    @ViewBuilder
    private var saveFeedback: some View {
        if isSaving {
            ProgressView(pendingCountry?.isEmpty == true ? "Saving removal…" : "Saving country…")
        } else if saveState != .idle {
            VStack(alignment: .leading, spacing: 6) {
                Label(saveTitle, systemImage: saveState == .saved ? "checkmark.circle" : "info.circle")
                    .font(TimeMasterFont.rowTitle())
                    .contentTransition(.opacity)
                    .animation(feedbackAnimation(duration: 0.18), value: saveState)
                if let saveDetail {
                    Text(saveDetail)
                        .font(TimeMasterFont.secondary())
                        .fixedSize(horizontal: false, vertical: true)
                }
                if needsStatusCheck {
                    Button("Check saved country") {
                        Task { await refreshIdentity(checkingSave: true) }
                    }
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
                    .disabled(isRefreshing || store.busy || store.loading)
                    #if os(iOS)
                    .frame(minHeight: ProfileStyle.touchTarget)
                    #endif
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityFocused($statusFocused)
        }
    }

    private var saveTitle: String {
        switch saveState {
        case .idle: return ""
        case .saving: return "Saving"
        case .unconfirmed: return pendingCountry?.isEmpty == true ? "Removal not confirmed" : "Save not confirmed"
        case .saved: return "Saved"
        case .checked: return "Saved country checked"
        }
    }

    private var refreshButton: some View {
        Button(readError == nil ? "Refresh identity" : "Retry identity refresh") {
            Task { await refreshIdentity(checkingSave: needsStatusCheck) }
        }
        .keyNavTarget(shape: .roundedRectangle(cornerRadius: 6))
        .disabled(isRefreshing || isSaving || store.busy || store.loading || activeAccountID == nil)
        #if os(iOS)
        .frame(minHeight: ProfileStyle.touchTarget)
        #endif
    }

    private func countryLabel(_ code: String, unavailablePrefix: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let flag = countriesByCode[code]?.flag {
                Text(flag).accessibilityHidden(true)
            } else {
                Image(systemName: "globe")
                    .accessibilityHidden(true)
            }
            Text(code.isEmpty ? "Not shown" : countriesByCode[code]?.name ?? unavailablePrefix)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(feedbackAnimation(duration: 0.16), value: code)
        }
        .font(TimeMasterFont.body())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(code.isEmpty ? "Country not provided" : "\(countryName(code)). Self-declared country or region, not verified")
    }

    private func currentStanding(_ identity: PhysiqueIdentity) -> some View {
        PhysiqueSection(title: "Current Physique standing") {
            PhysiqueCard {
                VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                    PhysiqueMetric(label: "Physique Elo", value: identity.rating.map(String.init) ?? "Unavailable")
                    PhysiqueMetric(label: "Placement", value: identity.games == 0 ? "Unplaced" : identity.games < 5 ? "Provisional · \(identity.games) of 5 rated results" : "Placed")
                    if identity.games >= 5 {
                        PhysiqueMetric(label: "Current Physique tier", value: identity.tier ?? "Unavailable")
                    }
                    PhysiqueMetric(label: "Current win streak", value: identity.streak.map { "\($0) consecutive rated wins" } ?? "Unavailable")
                    Text("Placement counts eligible rated forfeits. Historical badge milestones can remain when your current streak ends or your tier changes.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func badgeCollection(_ identity: PhysiqueIdentity) -> some View {
        PhysiqueSection(title: "Badges") {
            if identity.badges.isEmpty {
                PhysiqueStatusView(title: "No badges yet", detail: "No earned badges were supplied in your confirmed identity. Badges are awarded by the service, never equipped or purchased.", systemImage: "medal")
            }
            ForEach(identity.badges) { badge in
                PhysiqueCard {
                    DisclosureGroup(isExpanded: badgeExpansion(badge.id)) {
                        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                            if badge.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Details unavailable. Refresh identity to request the current badge meaning.")
                            } else {
                                Text(badge.detail)
                            }
                            if let earnedAt = badge.earnedAt, earnedAt.isFinite {
                                Text("Earned \(Date(timeIntervalSince1970: earnedAt).formatted(date: .abbreviated, time: .omitted))")
                                    .font(TimeMasterFont.secondary())
                                    .foregroundStyle(ProfileStyle.secondary)
                            }
                            Text("Physique competition achievement, not identity or nationality verification, a medical conclusion, or a moderation endorsement. The service can update qualification after a record correction.")
                                .font(TimeMasterFont.secondary())
                                .foregroundStyle(ProfileStyle.secondary)
                        }
                        .font(TimeMasterFont.body())
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, ProfileStyle.spacing)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(badge.title.isEmpty ? "Badge" : badge.title)
                                .font(TimeMasterFont.rowTitle())
                            Text("Earned · Service confirmed")
                                .font(TimeMasterFont.secondary())
                                .foregroundStyle(ProfileStyle.secondary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        #if os(iOS)
                        .frame(minHeight: ProfileStyle.touchTarget, alignment: .leading)
                        #endif
                    }
                    .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0), action: { badgeExpansion(badge.id).wrappedValue.toggle() })
                }
            }
            PhysiqueCard {
                DisclosureGroup("How Physique badges work", isExpanded: $badgeHelpExpanded) {
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        Text("First Bell: first valid AI-judged Physique win, loss or draw. Forfeits and no-contests do not qualify.")
                        Text("Placed: currently five rated results, including eligible rated forfeits. A correction can return placement to provisional or unplaced.")
                        Text("Ten Rounds: ten valid AI-judged Physique matches, not ten starts or rated forfeits.")
                        Text("Three Straight: a historical run of at least three canonical rated wins. Eligible opponent-forfeit wins count. It does not describe your current streak.")
                        Text("Only badges supplied by the service are shown as earned. Judged-match progress, best streak and review status are not supplied here; no progress is inferred from rated games or partial history.")
                            .foregroundStyle(ProfileStyle.secondary)
                    }
                    .font(TimeMasterFont.secondary())
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, ProfileStyle.spacing)
                }
                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 0), action: { badgeHelpExpanded.toggle() })
                .font(TimeMasterFont.rowTitle())
            }
        }
    }

    private func badgeExpansion(_ badgeID: String) -> Binding<Bool> {
        Binding {
            expandedBadges.contains(badgeID)
        } set: { expanded in
            if expanded {
                expandedBadges.insert(badgeID)
            } else {
                expandedBadges.remove(badgeID)
            }
        }
    }

    private func loadAccount() async {
        clearAccount()
        guard let currentID = activeAccountID else { return }
        accountID = currentID
        await refreshIdentity(checkingSave: false)
    }

    private func refreshIdentity(checkingSave: Bool) async {
        guard let currentID = activeAccountID, accountID == currentID, !isRefreshing, !isSaving else { return }
        let requestGeneration = generation
        isRefreshing = true
        readError = nil
        if checkingSave { statusFocused = false }
        await store.refresh()
        guard generation == requestGeneration, activeAccountID == currentID, accountID == currentID else { return }
        isRefreshing = false
        if let error = store.error {
            readError = error
            if checkingSave {
                saveState = .unconfirmed
                saveDetail = "The saved country could not be checked. Your draft is retained. \(error)"
            }
            return
        }
        guard let snapshot = store.snapshot else {
            readError = "No account identity was returned. Try refreshing again."
            return
        }
        guard applySnapshot(snapshot) else {
            readError = readError ?? "A current account identity could not be confirmed from this response. Refresh again to check current state."
            return
        }
        if checkingSave {
            pendingCountry = nil
            saveState = .checked
            saveDetail = "Current saved country: \(countryName(savedCountry)). \(isDirty ? "Your unsaved choice is retained. Review it before deliberately saving again." : "Your selection matches the current saved value.") This status check does not create a new save receipt."
            statusFocused = isVisible && scenePhase == .active
        }
    }

    private func receiveStoreSnapshot() {
        guard accountID == activeAccountID, activeAccountID != nil, account != nil, !isRefreshing, !isSaving,
              let snapshot = store.snapshot else { return }
        _ = applySnapshot(snapshot)
    }

    @discardableResult
    private func applySnapshot(_ snapshot: PhysiqueSnapshot) -> Bool {
        guard snapshot.serverTime.isFinite else { return false }
        if let serverTime, snapshot.serverTime < serverTime { return false }
        if let identityID = account?.identity.id, identityID != snapshot.account.identity.id {
            clearAccount()
            accountID = activeAccountID
            readError = "Account identity changed. Refresh this destination from the current account."
            return false
        }
        let hadAccount = account != nil
        let wasDirty = isDirty
        let oldSavedCountry = savedCountry
        let newSavedCountry = snapshot.account.identity.countryCode ?? ""
        readError = nil
        account = snapshot.account
        serverTime = snapshot.serverTime
        savedCountry = newSavedCountry
        if !hadAccount || !wasDirty {
            draftCountry = newSavedCountry
            countryChangedElsewhere = false
        } else if oldSavedCountry != newSavedCountry {
            countryChangedElsewhere = draftCountry != newSavedCountry
        }
        if draftCountry == newSavedCountry { countryChangedElsewhere = false }
        expandedBadges.formIntersection(Set(snapshot.account.identity.badges.map(\.id)))
        return true
    }

    private func saveCountry() async {
        guard canSave, let currentID = activeAccountID, let identityID = visibleAccount?.identity.id else { return }
        let requestGeneration = generation
        let submittedCountry = draftCountry
        pendingCountry = submittedCountry
        saveState = .saving
        saveDetail = nil
        statusFocused = false
        let acknowledged = await store.perform("identity", countryCode: submittedCountry)
        guard generation == requestGeneration, activeAccountID == currentID, accountID == currentID else { return }
        if acknowledged, let snapshot = store.snapshot, snapshot.account.identity.id == identityID, applySnapshot(snapshot), savedCountry == submittedCountry {
            pendingCountry = nil
            countryChangedElsewhere = false
            saveState = .saved
            saveDetail = submittedCountry.isEmpty ? "Country removal was acknowledged by the service. It cannot recall previously viewed flags or external copies." : "The service acknowledged \(countryName(savedCountry))."
        } else {
            saveState = .unconfirmed
            saveDetail = store.error ?? "The requested saved value could not be confirmed. Your draft is retained. Check the saved country before another save."
        }
        statusFocused = isVisible && scenePhase == .active
    }

    private func useSavedCountry() {
        draftCountry = savedCountry
        countryChangedElsewhere = false
        if !needsStatusCheck {
            saveState = .idle
            saveDetail = nil
        }
    }

    private func requestClose() {
        if isDirty || isSaving || needsStatusCheck {
            confirmsClose = true
        } else {
            dismiss()
        }
    }

    private func clearAccount() {
        generation = UUID()
        account = nil
        accountID = nil
        serverTime = nil
        savedCountry = ""
        draftCountry = ""
        countryExpanded = false
        expandedBadges.removeAll()
        isRefreshing = false
        readError = nil
        saveState = .idle
        saveDetail = nil
        pendingCountry = nil
        countryChangedElsewhere = false
        confirmsClose = false
        statusFocused = false
    }

    private func countryName(_ code: String) -> String {
        if code.isEmpty { return "Not shown" }
        return countriesByCode[code]?.name ?? "Saved region unavailable"
    }

    private func loadCountryChoices() {
        let emojiFont = CTFontCreateWithName("AppleColorEmoji" as CFString, 20, nil)
        let fallbackLocale = Locale(identifier: "en")
        let choices = Locale.Region.isoRegions.compactMap { region -> CountryChoice? in
            let code = region.identifier
            guard code.utf8.count == 2, code.utf8.allSatisfy({ (65...90).contains($0) }) else { return nil }
            let name = locale.localizedString(forRegionCode: code) ?? fallbackLocale.localizedString(forRegionCode: code) ?? "Region \(code)"
            let flag = String(String.UnicodeScalarView(code.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }))
            let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): emojiFont]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: flag, attributes: attributes) as CFAttributedString)
            return CountryChoice(code: code, name: name, flag: CTLineGetGlyphCount(line) == 1 ? flag : nil)
        }.sorted {
            let order = $0.name.compare($1.name, options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            return order == .orderedSame ? $0.code < $1.code : order == .orderedAscending
        }
        countryChoices = choices
        countriesByCode = Dictionary(uniqueKeysWithValues: choices.map { ($0.code, $0) })
    }

    private func feedbackAnimation(duration: Double) -> Animation? {
        guard scenePhase == .active, !ProcessInfo.processInfo.isLowPowerModeEnabled,
              ProcessInfo.processInfo.thermalState != .serious, ProcessInfo.processInfo.thermalState != .critical else { return nil }
        return .easeOut(duration: reduceMotion ? min(duration, 0.1) : duration)
    }
}
