import SwiftUI
import TimeMasterCore

@MainActor
struct PhysiqueCaseCenterView: View {
    @ObservedObject var store: PhysiqueStore
    let onOpen: (PhysiqueRoute) -> Void

    @ObservedObject private var accountStore = CloudAccountStore.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.physiquePresentationActive) private var presentationActive
    @State private var needsYou: [CaseSummary] = []
    @State private var otherCases: [CaseSummary] = []
    @State private var selectedCaseID: String?
    @State private var returningCaseID: String?
    @State private var loadedAccountID: String?
    @State private var lastChecked: Date?
    @State private var hasLoaded = false
    @State private var isLoading = false
    @State private var requiresRevalidation = true
    @State private var requestID = UUID()
    @State private var failure: ListFailure?
    @State private var selectionUnavailable = false
    @State private var supportError: String?
    @AccessibilityFocusState private var focusedCaseID: String?

    private struct LoadContext: Hashable {
        let accountID: String?
        let active: Bool
    }

    private struct CaseSummary: Identifiable {
        let id: String
        let kind: String
        let status: String
        let createdAt: Double
        let updatedAt: Double
        let needsReply: Bool

        init(_ item: PhysiqueCase) {
            id = item.id
            kind = item.kind
            status = item.status
            createdAt = item.createdAt
            updatedAt = item.updatedAt
            needsReply = item.needsReply
        }

        var title: String {
            switch kind {
            case "report": return "Safety report"
            case "appeal": return "Safety appeal"
            case "dispute": return "Scoring review"
            case "restriction": return "Participation restriction"
            default: return "Case"
            }
        }

        var symbol: String {
            switch kind {
            case "report": return "doc.text"
            case "appeal": return "doc.text.magnifyingglass"
            case "dispute": return "checkmark.bubble"
            case "restriction": return "shield"
            default: return "doc"
            }
        }

        var statusTitle: String {
            switch status {
            case "received": return kind == "appeal" ? "Appeal received" : "Received"
            case "queued": return "Queued"
            case "inReview": return kind == "appeal" ? "Appeal in review" : "In review"
            case "needsReply": return "Reply requested"
            case "actionTaken": return "Action taken"
            case "noViolation": return "No violation found"
            case "inconclusive": return "Inconclusive"
            case "withdrawn": return "Withdrawn"
            case "closed": return "Closed"
            case "upheld": return "Decision upheld"
            case "revised": return "Decision revised"
            default: return "Status unavailable"
            }
        }
    }

    private enum ListFailure: Equatable {
        case offline, connection, access, unavailable

        var title: String {
            switch self {
            case .offline: return "Offline"
            case .connection: return "Couldn’t refresh cases"
            case .access: return "Case access unavailable"
            case .unavailable: return "Cases unavailable"
            }
        }

        var detail: String {
            switch self {
            case .offline: return "Reconnect to check the current status of your cases."
            case .connection: return "The service could not be reached. Try again to check the current status."
            case .access: return "Your account access could not be confirmed. Open your account or use the published support destination."
            case .unavailable: return "The private case list could not be confirmed. Try again or use the published support destination."
            }
        }
    }

    private var activeAccountID: String? {
        accountStore.restored && !accountStore.busy ? accountStore.accountID : nil
    }

    private var isActive: Bool { presentationActive && scenePhase == .active }
    private var loadContext: LoadContext { LoadContext(accountID: activeAccountID, active: isActive) }
    private var hasCases: Bool { !needsYou.isEmpty || !otherCases.isEmpty }
    private var showsConfirmedList: Bool {
        isActive && !requiresRevalidation && activeAccountID != nil && loadedAccountID == activeAccountID && hasLoaded
    }

    private var publishedPolicy: PhysiquePolicy? { store.policy ?? store.snapshot?.policy }

    private var supportURL: URL? {
        guard let value = publishedPolicy?.supportURL,
              var parts = URLComponents(string: value),
              let scheme = parts.scheme?.lowercased(),
              parts.user == nil, parts.password == nil else { return nil }
        if scheme == "https" {
            guard let host = parts.host, !host.isEmpty else { return nil }
        } else if scheme == "mailto" {
            guard !parts.path.isEmpty else { return nil }
            parts.query = nil
            parts.fragment = nil
        } else {
            return nil
        }
        return parts.url
    }

    var body: some View {
        platformContent
            .font(TimeMasterFont.body())
            .foregroundStyle(Theme.textPrimary)
            .background(Theme.background.ignoresSafeArea())
            .tint(Theme.toolbarOrange)
            .privacySensitive()
            .task(id: loadContext) { [context = loadContext] in await loadCases(context: context) }
            .task {
                if store.policy == nil { await store.loadPolicy() }
            }
            .onChange(of: accountStore.accountID) { _ in clearPrivateState() }
            .onChange(of: accountStore.busy) { busy in
                if busy { clearPrivateState() }
            }
            .onChange(of: isActive) { active in
                if !active {
                    requestID = UUID()
                    isLoading = false
                    requiresRevalidation = true
                }
            }
            .onAppear {
                if loadedAccountID == activeAccountID, let returningCaseID {
                    focusedCaseID = returningCaseID
                }
            }
            .onChange(of: store.lastReceiptID) { receipt in
                if receipt != nil { refreshCases() }
            }
    }

    @ViewBuilder
    private var platformContent: some View {
        #if os(macOS)
        NavigationSplitView {
            caseList
                .listStyle(.sidebar)
                .navigationTitle("Cases")
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 420)
                .toolbar { listToolbar }
        } detail: {
            if activeAccountID != nil, loadedAccountID == activeAccountID, let caseID = selectedCaseID {
                PhysiqueCaseDetailView(store: store, onOpen: onOpen, caseID: caseID)
            } else {
                PhysiqueScreen(title: selectionUnavailable ? "Case unavailable" : "Select a case") {
                    Text(selectionUnavailable
                         ? "This case is no longer available in your authorized list. Select another case or contact support."
                         : "Only this account’s private reports, appeals, and decisions appear here.")
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toolbar { listToolbar }
            }
        }
        .navigationSplitViewStyle(.balanced)
        #else
        caseList
            .listStyle(.insetGrouped)
            .navigationTitle("Cases")
            .toolbar { listToolbar }
        #endif
    }

    private var caseList: some View {
        List(selection: $selectedCaseID) {
            SwiftUI.Section {
                Text("Private reports, appeals, and decisions.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .listRowBackground(Theme.surface)

            accessSection

            if showsConfirmedList {
                if !needsYou.isEmpty {
                    SwiftUI.Section("Needs you") {
                        ForEach(needsYou) { item in caseRow(item) }
                    }
                }
                if !otherCases.isEmpty {
                    SwiftUI.Section("Cases") {
                        ForEach(otherCases) { item in caseRow(item) }
                    }
                }
                SwiftUI.Section {
                    if let lastChecked {
                        Text("Last checked \(lastChecked.formatted(date: .abbreviated, time: .shortened))")
                            .accessibilityLabel("Last checked \(fullDate(lastChecked))")
                    }
                    Text("Only service-confirmed cases appear here. Unsent or unconfirmed submissions remain in their original form.")
                        .fixedSize(horizontal: false, vertical: true)
                    Button { refreshCases() } label: {
                        Label("Refresh cases", systemImage: "arrow.clockwise")
                            .frame(minHeight: ProfileStyle.touchTarget)
                    }
                    .disabled(isLoading)
                }
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .listRowBackground(Theme.surface)
            }

            supportSection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .environment(\.defaultMinListRowHeight, ProfileStyle.touchTarget)
        .refreshable { await loadCases(context: loadContext) }
    }

    @ViewBuilder
    private var accessSection: some View {
        if !isActive {
            SwiftUI.Section {
                Label("Private cases hidden", systemImage: "lock")
                Text("Return to check your current case access.")
                    .foregroundStyle(ProfileStyle.secondary)
            }
            .listRowBackground(Theme.surface)
        } else if !accountStore.restored || accountStore.busy {
            SwiftUI.Section {
                ProgressView("Resolving account access…")
            }
            .listRowBackground(Theme.surface)
        } else if activeAccountID == nil {
            SwiftUI.Section {
                Label("Sign in to view your cases", systemImage: "lock")
                    .font(TimeMasterFont.rowTitle())
                Text("Private case records are available only to the authorized account.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                Button { onOpen(.account) } label: {
                    Label("Sign in", systemImage: "person.crop.circle")
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
            }
            .listRowBackground(Theme.surface)
        } else {
            if let failure {
                SwiftUI.Section {
                    Label(failure.title, systemImage: "exclamationmark.circle")
                        .font(TimeMasterFont.rowTitle())
                    Text(failure.detail)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if showsConfirmedList, hasCases {
                        Text("Showing last confirmed statuses, not current decisions.")
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(ProfileStyle.secondary)
                    }
                    Button { refreshCases() } label: {
                        Label("Try again", systemImage: "arrow.clockwise")
                            .frame(minHeight: ProfileStyle.touchTarget)
                    }
                    .disabled(isLoading)
                    if failure == .access || failure == .unavailable {
                        Button { onOpen(.account) } label: {
                            Label("Open account", systemImage: "person.crop.circle")
                                .frame(minHeight: ProfileStyle.touchTarget)
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
            if isLoading {
                SwiftUI.Section {
                    ProgressView(showsConfirmedList ? "Refreshing cases…" : "Loading cases…")
                }
                .listRowBackground(Theme.surface)
            } else if showsConfirmedList, !hasCases, failure == nil {
                SwiftUI.Section {
                    Label("No cases", systemImage: "doc.text")
                        .font(TimeMasterFont.rowTitle())
                    Text("Reports you send and decisions affecting you appear here.")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(Theme.surface)
            }
        }
    }

    @ViewBuilder
    private func caseRow(_ item: CaseSummary) -> some View {
        #if os(macOS)
        rowLabel(item)
            .tag(item.id)
            .accessibilityHint("Select to read this private case")
        #else
        Button {
            returningCaseID = item.id
            onOpen(.caseDetail(item.id))
        } label: {
            HStack(alignment: .center, spacing: ProfileStyle.spacing) {
                rowLabel(item)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ProfileStyle.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.surface)
        .accessibilityHint("Open private case details")
        .accessibilityFocused($focusedCaseID, equals: item.id)
        #endif
    }

    private func rowLabel(_ item: CaseSummary) -> some View {
        HStack(alignment: .top, spacing: ProfileStyle.spacing) {
            Image(systemName: item.symbol)
                .font(.body)
                .foregroundStyle(ProfileStyle.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title).font(TimeMasterFont.rowTitle())
                Text(failure == nil ? item.statusTitle : "Last confirmed: \(item.statusTitle)")
                    .font(TimeMasterFont.secondary())
                if item.needsReply, item.status != "needsReply" {
                    Label("Reply requested", systemImage: "arrowshape.turn.up.left")
                        .font(TimeMasterFont.secondary())
                }
                Text(dateLabel("Updated", timestamp: item.updatedAt))
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                Text("Reference \(String(item.id.prefix(8)))")
                    .font(TimeMasterFont.technical())
                    .foregroundStyle(ProfileStyle.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .frame(minHeight: ProfileStyle.touchTarget, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title). \(failure == nil ? "" : "Last confirmed: ")\(item.statusTitle). \(item.needsReply ? "Needs your reply. " : "")\(accessibleDateLabel("Updated", timestamp: item.updatedAt)). \(accessibleDateLabel("Received", timestamp: item.createdAt)).")
        .accessibilityValue("Case reference \(item.id)")
    }

    private var supportSection: some View {
        SwiftUI.Section("Support") {
            if let url = supportURL {
                if let operatorName = publishedPolicy?.operatorName, !operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(operatorName).font(TimeMasterFont.rowTitle())
                }
                Text(url.absoluteString)
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Button { contactSupport(url) } label: {
                    Label("Contact support", systemImage: "arrow.up.right.square")
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
                Text("Opens the published destination in another app. No case text or attachments are included, and opening it does not confirm delivery.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No support destination is currently published by the service.")
                    .font(TimeMasterFont.secondary())
                    .foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await store.loadPolicy() }
                } label: {
                    Label("Check support availability", systemImage: "arrow.clockwise")
                        .frame(minHeight: ProfileStyle.touchTarget)
                }
            }
            if let supportError {
                Text(supportError)
                    .font(TimeMasterFont.secondary())
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .listRowBackground(Theme.surface)
    }

    @ToolbarContentBuilder
    private var listToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button { refreshCases() } label: {
                Label("Refresh cases", systemImage: "arrow.clockwise")
            }
            .disabled(isLoading || activeAccountID == nil || !isActive)
            if let url = supportURL {
                Button { contactSupport(url) } label: {
                    Label("Contact support", systemImage: "arrow.up.right.square")
                }
            }
        }
    }

    private func refreshCases() {
        Task { await loadCases(context: loadContext) }
    }

    private func loadCases(context: LoadContext) async {
        guard !Task.isCancelled, context == loadContext else { return }
        guard context.active else {
            requestID = UUID()
            isLoading = false
            requiresRevalidation = true
            return
        }
        guard let owner = context.accountID else {
            clearPrivateState()
            return
        }
        if loadedAccountID != owner {
            clearPrivateState()
            loadedAccountID = owner
        }
        guard !isLoading else { return }
        let request = UUID()
        requestID = request
        isLoading = true
        let revalidating = requiresRevalidation
        defer {
            if requestID == request { isLoading = false }
        }
        do {
            let received = try await store.cases()
            try Task.checkCancellation()
            guard requestID == request, context == loadContext else { return }
            var unique: [String: CaseSummary] = [:]
            for item in received {
                let summary = CaseSummary(item)
                if let existing = unique[summary.id], activityTime(existing.updatedAt) >= activityTime(summary.updatedAt) { continue }
                unique[summary.id] = summary
            }
            let ordered = unique.values.sorted {
                let first = activityTime($0.updatedAt)
                let second = activityTime($1.updatedAt)
                return first == second ? $0.id < $1.id : first > second
            }
            needsYou = ordered.filter(\.needsReply)
            otherCases = ordered.filter { !$0.needsReply }
            failure = nil
            hasLoaded = true
            requiresRevalidation = false
            lastChecked = Date()
            if let selectedCaseID, unique[selectedCaseID] == nil {
                self.selectedCaseID = nil
                selectionUnavailable = true
            } else if selectedCaseID != nil {
                selectionUnavailable = false
            }
            if let returningCaseID, unique[returningCaseID] != nil {
                focusedCaseID = returningCaseID
                self.returningCaseID = nil
            }
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled, requestID == request, context == loadContext else { return }
            if let network = error as? URLError {
                failure = network.code == .notConnectedToInternet ? .offline : .connection
                requiresRevalidation = revalidating
            } else {
                let accessFailure: Bool
                if let authError = error as? CloudAuthError {
                    switch authError {
                    case .signedOut, .sessionExpired, .superseded: accessFailure = true
                    case .service(let status, _): accessFailure = status == 401 || status == 403
                    default: accessFailure = false
                    }
                } else if let serviceError = error as? RankedServiceError, case .signedOut = serviceError {
                    accessFailure = true
                } else {
                    accessFailure = false
                }
                clearPrivateState()
                loadedAccountID = owner
                failure = accessFailure ? .access : .unavailable
            }
        }
    }

    private func clearPrivateState() {
        requestID = UUID()
        needsYou.removeAll()
        otherCases.removeAll()
        selectedCaseID = nil
        returningCaseID = nil
        focusedCaseID = nil
        loadedAccountID = nil
        lastChecked = nil
        hasLoaded = false
        isLoading = false
        requiresRevalidation = true
        failure = nil
        selectionUnavailable = false
    }

    private func contactSupport(_ url: URL) {
        supportError = nil
        openURL(url) { accepted in
            if !accepted {
                supportError = "Couldn’t open the published support destination. Try Contact support again or select and copy the destination above to open it yourself. Nothing was sent by this app."
            }
        }
    }

    private func activityTime(_ value: Double) -> Double { value.isFinite && value > 0 ? value : -.infinity }

    private func eventDate(_ value: Double) -> Date? {
        guard value.isFinite, value > 0 else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    private func dateLabel(_ label: String, timestamp: Double) -> String {
        guard let date = eventDate(timestamp) else { return "\(label): Time unavailable" }
        return "\(label) \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private func accessibleDateLabel(_ label: String, timestamp: Double) -> String {
        guard let date = eventDate(timestamp) else { return "\(label): Time unavailable" }
        return "\(label) \(fullDate(date))"
    }

    private func fullDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.wide).day().hour().minute().timeZone())
    }
}
