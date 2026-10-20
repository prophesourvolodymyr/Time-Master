import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ProfileVerificationView: View {
    @EnvironmentObject private var profileStore: LocalProfileStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var outdoorStore: OutdoorActivityStore
    @Environment(\.dismiss) private var dismiss
    @State private var tier: LocalBadgeTier = .blue
    @State private var popup: ProfileMembershipReceipt?
    @State private var error: String?
    @State private var initialized = false
    @State private var showingPreview = false
    @State private var metricExplanation: ProfileMetricExplanation?

    private func progress(at date: Date = Date()) -> LocalVerificationProgress {
        LocalVerificationProgress(profile: profileStore.profile, history: workoutStore.historyEntries, activities: outdoorStore.activities, now: date)
    }

    private func headline(_ progress: LocalVerificationProgress) -> String {
        if progress.isEligible { return "YOUR LOCAL MILESTONE IS READY" }
        let overallProgress = min(
            Double(progress.accountDays) / Double(LocalVerificationProgress.requiredAccountDays),
            Double(progress.completedSessions) / Double(LocalVerificationProgress.requiredSessions),
            Double(progress.activeDays) / Double(LocalVerificationProgress.requiredActiveDays)
        )
        if overallProgress >= 0.75 { return "YOU ARE VERY CLOSE!" }
        if progress.completedSessions == 0 { return "GET TO WORK" }
        return "KEEP GOING!"
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                screen(progress: progress(at: context.date))
            }
            .onAppear {
                guard !initialized else { return }
                initialized = true
                tier = profileStore.snapshot.badgePreview ?? .blue
            }
            .everPopup(item: $popup) { receipt in
                ProfileMembershipWelcome(receipt: receipt) {
                    popup = nil
                }
            }
            .everPopup(item: $metricExplanation) { explanation in
                ProfileMetricInfoPopup(explanation: explanation) {
                    metricExplanation = nil
                }
            }
            .everFullScreenCover(isPresented: $showingPreview) {
                NavigationStack {
                    ProfileView(previewOnly: true, onPreviewClose: { showingPreview = false })
                        .environment(\.verificationPreviewTier, tier)
                }
            }
        }
        .foregroundStyle(EverColor.textPrimary)
        .tint(EverColor.accent)
        .preferredColorScheme(.dark)
        .everSheetBackground()
    }

    private func screen(progress: LocalVerificationProgress) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: EverSpacing.x6) {
                    ProfileVerificationTitle(title: displayTitle(for: headline(progress)))
                    qualification(progress)
                    ProfileMembershipBenefits(tier: .blue)
                    Text("OR")
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(EverColor.textSecondary)
                        .frame(maxWidth: .infinity)
                    paidPlans
                        .id("pro-plans")
                    if profileStore.isReadOnly {
                        Text(profileStore.errorMessage ?? LocalProfileError.storageUnreadable.localizedDescription)
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(EverColor.error)
                        Button("Retry loading local profile") { profileStore.reload() }
                            .buttonStyle(EverSecondaryButtonStyle())
                    }
                    if let error {
                        Text(error)
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(EverColor.error)
                    }
                }
                .padding(EverLayout.phoneInset)
                .everReadableWidth()
            }
            .modifier(EverScrollMotion())
            .everScreenBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                purchaseAction {
                    withAnimation(EverMotion.state) {
                        proxy.scrollTo("pro-plans", anchor: .center)
                    }
                }
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: EverLayout.minimumTouchTarget, height: EverLayout.minimumTouchTarget)
                }
                .buttonStyle(TimeMasterToolbarIconButtonStyle())
                .accessibilityLabel("Back")
                .accessibilityIdentifier("pro-back")
            }
            ToolbarItem(placement: .primaryAction) { accountSelector }
        }
    }

    private struct ProfileVerificationTitle: View {
        let title: String

        var body: some View {
            Text(title)
                .font(TimeMasterFont.title())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func displayTitle(for title: String) -> String {
        title == "YOU ARE VERY CLOSE!" ? "YOU ARE\nVERY CLOSE!" : title
    }

    private var accountSelector: some View {
        Image(systemName: "person.crop.circle")
            .font(.title2.weight(.semibold))
            .frame(width: EverLayout.minimumTouchTarget, height: EverLayout.minimumTouchTarget)
            .background(EverColor.background, in: Circle())
            .overlay {
                EverSpecularRim(shape: Circle())
            }
            .accessibilityLabel("Local profile")
            .accessibilityValue(profileStore.profile.displayName)
    }

    private func qualification(_ progress: LocalVerificationProgress) -> some View {
        VStack(spacing: EverSpacing.x5) {
            VStack(spacing: EverSpacing.x2) {
                ProfileMembershipIdentity(tier: .blue)
                Button {
                    tier = .blue
                    showingPreview = true
                } label: {
                    Label("Preview only", systemImage: "eye")
                }
                .font(TimeMasterFont.caption())
                .frame(minHeight: EverLayout.minimumTouchTarget)
                .buttonStyle(EverPressButtonStyle())
                .accessibilityIdentifier("pro-profile-preview")
            }
            VStack(spacing: EverSpacing.x2) {
                ProfileVerificationProgressRow(
                    title: "Local profile age", symbol: "hourglass",
                    current: progress.accountDays.formatted(), goal: "180 days",
                    progress: Double(progress.accountDays) / Double(LocalVerificationProgress.requiredAccountDays),
                    explanation: ProfileMetricExplanation(
                        id: "account-age",
                        title: "Local profile age",
                        message: "At least 180 calendar days since this local profile was created. This is an on-device consistency milestone, not proof of identity."
                    ),
                    showInfo: { metricExplanation = $0 }
                )
                ProfileVerificationProgressRow(
                    title: "Completed sessions", symbol: "figure.strengthtraining.traditional",
                    current: progress.completedSessions.formatted(), goal: "100",
                    progress: Double(progress.completedSessions) / Double(LocalVerificationProgress.requiredSessions),
                    explanation: ProfileMetricExplanation(
                        id: "sessions",
                        title: "Completed sessions",
                        message: "100 distinct completed indoor or saved, finished outdoor sessions during the trailing 180 days. Partial, future, expired, unfinished, and duplicate session IDs are excluded."
                    ),
                    showInfo: { metricExplanation = $0 }
                )
                ProfileVerificationProgressRow(
                    title: "Distinct active days", symbol: "calendar",
                    current: progress.activeDays.formatted(),
                    goal: "75 days", progress: Double(progress.activeDays) / Double(LocalVerificationProgress.requiredActiveDays),
                    explanation: ProfileMetricExplanation(
                        id: "active-days",
                        title: "Distinct active days",
                        message: "Train on 75 distinct calendar days in the same trailing 180-day window. Multiple completed sessions on one day count as one active day. Private history stays on this device."
                    ),
                    showInfo: { metricExplanation = $0 }
                )
            }
            if profileStore.snapshot.earnedMilestoneClaimed {
                ProfileVerificationStatusRow {
                    metricExplanation = ProfileMetricExplanation(
                        id: "local-milestone",
                        title: "Local consistency milestone",
                        message: "Claimed and saved on this device. It does not grant identity verification or a badge tier. Current qualification can change as the 180-day window moves."
                    )
                }
            } else {
                Button("Claim local consistency milestone") {
                    do {
                        try profileStore.claimMilestone(progress: self.progress())
                        popup = ProfileMembershipReceipt(tier: .blue, isMilestone: true)
                        error = nil
                        EverHaptic.success()
                    } catch { self.error = error.localizedDescription }
                }
                .buttonStyle(EverPrimaryButtonStyle())
                .accessibilityIdentifier("pro-claim")
                .disabled(!progress.isEligible || profileStore.isReadOnly)
            }
        }
    }


    private var paidPlans: some View {
        VStack(spacing: EverSpacing.x4) {
            Text("Paid-tier designs · Preview only")
                .font(TimeMasterFont.sectionTitle())
            ProfileTierSelector(selection: $tier)
                .onChange(of: tier) { _ in error = nil }
            ProfilePlanBenefitsMotion(tier: tier)
            Button {
                showingPreview = true
            } label: {
                Label("Preview on your local profile", systemImage: "eye")
            }
            .buttonStyle(EverSecondaryButtonStyle())
            applyPreviewButton
            if let applied = profileStore.snapshot.badgePreview {
                Button("Clear \(applied.title) local Preview") {
                    do {
                        try profileStore.setBadgePreview(nil)
                        error = nil
                    } catch { self.error = error.localizedDescription }
                }
                .buttonStyle(EverSecondaryButtonStyle())
                .disabled(profileStore.isReadOnly)
            }
        }
    }

    private func purchaseAction(scrollToPlans: @escaping () -> Void) -> some View {
        HStack(spacing: EverSpacing.x2) {
            Button(action: scrollToPlans) {
                Text("Explore Previews")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EverPrimaryButtonStyle())
            .accessibilityHint("See local badge designs; no purchase or subscription")
            .accessibilityIdentifier("pro-subscribe")
            Button("Later") { dismiss() }
            .font(TimeMasterFont.label())
            .padding(.horizontal, EverSpacing.x5)
            .frame(minHeight: EverLayout.primaryButtonMinimum)
            .foregroundStyle(EverColor.textPrimary)
            .background(EverColor.error.opacity(0.20), in: RoundedRectangle(cornerRadius: EverRadius.button))
            .buttonStyle(EverPressButtonStyle())
            .accessibilityIdentifier("pro-wait")
        }
        .padding(.horizontal, EverLayout.phoneInset)
        .padding(.vertical, EverSpacing.x3)
        .everReadableWidth()
        .background(EverColor.background)
    }


    private var applyPreviewButton: some View {
        Button(profileStore.snapshot.badgePreview == tier ? "\(tier.title) Preview saved locally" : "Apply \(tier.title) local Preview") {
            do {
                try profileStore.setBadgePreview(tier)
                error = nil
                showingPreview = false
                popup = ProfileMembershipReceipt(tier: tier)
                EverHaptic.success()
            } catch { self.error = error.localizedDescription }
        }
        .buttonStyle(EverPrimaryButtonStyle())
        .disabled(profileStore.isReadOnly || profileStore.snapshot.badgePreview == tier)
    }
}


struct ProfileMembershipIdentity: View {
    let tier: LocalBadgeTier
    var color: Color? = nil
    @EnvironmentObject private var profileStore: LocalProfileStore
    @ScaledMetric(relativeTo: .title) private var avatarSize = EverLayout.minimumTouchTarget * 1.8

    var body: some View {
        let profile = profileStore.profile
            VStack(spacing: EverSpacing.x2) {
                ProfileStyledAvatar(profile: profile, size: avatarSize)
                    .overlay(alignment: .bottomTrailing) {
                        ProfileVerificationBadge(tier: tier, color: color, size: avatarSize * 0.36)
                    }
                Text(profile.displayName).font(TimeMasterFont.sectionTitle()).multilineTextAlignment(.center)
                Text("\(tier.title) Preview · Not verified")
                    .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
    }
}

private struct ProfileVerificationProgressRow: View {
    let title: String
    let symbol: String
    let current: String
    let goal: String
    let progress: Double
    let explanation: ProfileMetricExplanation
    let showInfo: (ProfileMetricExplanation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EverSpacing.x2) {
            HStack(alignment: .firstTextBaseline, spacing: EverSpacing.x2) {
                Label(title, systemImage: symbol)
                    .font(TimeMasterFont.rowTitle())
                Button {
                    showInfo(explanation)
                } label: {
                    Image(systemName: "info.circle")
                        .font(TimeMasterFont.caption())
                        .frame(width: EverLayout.minimumTouchTarget, height: EverLayout.minimumTouchTarget)
                }
                .buttonStyle(EverPressButtonStyle())
                .accessibilityLabel("About \(title)")
                Spacer(minLength: EverSpacing.x1)
                HStack(alignment: .firstTextBaseline, spacing: EverSpacing.x1) {
                    Text(current).font(TimeMasterFont.rowTitle())
                    Text("/ \(goal)")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(EverColor.textSecondary)
                }
                .monospacedDigit()
            }
            EverProgressBar(value: progress)
                .accessibilityHidden(true)
        }
        .padding(EverSpacing.x3)
        .background { EverSurfaceMaterial(radius: EverRadius.field, showsRim: false) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(current), target \(goal)")
    }
}

private struct ProfileVerificationStatusRow: View {
    let showInfo: () -> Void

    var body: some View {
        HStack(spacing: EverSpacing.x3) {
            Image(systemName: "medal")
            Text("Local consistency milestone")
            Button(action: showInfo) {
                Image(systemName: "info.circle")
                    .font(TimeMasterFont.caption())
                    .frame(width: EverLayout.minimumTouchTarget, height: EverLayout.minimumTouchTarget)
            }
            .buttonStyle(EverPressButtonStyle())
            .accessibilityLabel("About your local milestone")
            Spacer(minLength: EverSpacing.x2)
            Text("Claimed")
        }
        .font(TimeMasterFont.secondary())
        .padding(.horizontal, EverSpacing.x3)
        .frame(minHeight: EverLayout.minimumTouchTarget)
        .foregroundStyle(EverColor.success)
        .background { EverSurfaceMaterial() }
        .accessibilityElement(children: .combine)
        .accessibilityValue("Claimed locally, not identity verification")
    }
}

private struct ProfileMetricExplanation: Identifiable {
    let id: String
    let title: String
    let message: String
}

private struct ProfileMetricInfoPopup: View {
    let explanation: ProfileMetricExplanation
    let onClose: () -> Void

    var body: some View {
        EverPopup(title: explanation.title, onEscape: onClose) {
            Text(explanation.message)
                .font(TimeMasterFont.secondary())
                .foregroundStyle(EverColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            Button("Done", action: onClose)
                .buttonStyle(EverPrimaryButtonStyle())
        }
    }
}

struct ProfileTierSelector: View {
    @Binding var selection: LocalBadgeTier
    var color: Color = .blue
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: EverSpacing.x2)) : AnyLayout(HStackLayout(spacing: EverSpacing.x2))
        layout {
            ForEach(LocalBadgeTier.allCases) { tier in
                Button {
                    selection = tier
                    EverHaptic.selection()
                } label: {
                    VStack(spacing: EverSpacing.x2) {
                        ProfileVerificationBadge(tier: tier, color: color, size: EverLayout.minimumTouchTarget)
                        Text(tier.title).font(TimeMasterFont.sectionTitle())
                        Text(tier == .blue ? "Blue preview" : tier == .silver ? "Polished silver" : "Signature gold")
                            .font(TimeMasterFont.micro()).foregroundStyle(EverColor.textSecondary)
                        Image(systemName: selection == tier ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection == tier ? EverColor.textPrimary : EverColor.borderStrong)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EverSpacing.x3)
                    .background { EverSurfaceMaterial() }
                    .overlay {
                        RoundedRectangle(cornerRadius: EverRadius.card)
                            .strokeBorder(selection == tier ? EverColor.textPrimary : .clear, lineWidth: 1)
                    }
                }
                .buttonStyle(EverPressButtonStyle())
                .accessibilityLabel("\(tier.title) Preview only")
                .accessibilityAddTraits(selection == tier ? .isSelected : [])
                .accessibilityIdentifier("pro-tier-\(tier.rawValue)")
            }
        }
    }
}

#if canImport(UIKit)
private struct ProfilePlanBenefitsMotion: UIViewControllerRepresentable {
    let tier: LocalBadgeTier
    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller(rootView: AnyView(EmptyView()))
        controller.sizingOptions = [.intrinsicContentSize]
        controller.view.backgroundColor = .clear
        controller.motion.host = controller.view
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        if let previous = controller.tier, previous != tier {
            let tiers = LocalBadgeTier.allCases
            let forward = (tiers.firstIndex(of: tier) ?? 0) > (tiers.firstIndex(of: previous) ?? 0)
            controller.direction = (forward ? 1 : -1) * (context.environment.layoutDirection == .leftToRight ? 1 : -1)
        }
        controller.tier = tier
        controller.rootView = AnyView(
            ProfilePlanBenefits(tier: tier)
                .background(EverPopupStepAnchor(id: tier.rawValue))
                .environment(\.everPopupStepMotion, controller.motion)
                .environment(\.everPopupStepDirection, controller.direction)
                .environment(\.self, context.environment)
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: Controller, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return uiViewController.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.motion.stop()
    }

    final class Controller: UIHostingController<AnyView> {
        let motion = EverPopupStepMotion()
        var tier: LocalBadgeTier?
        var direction = 1.0
    }
}
#else
private struct ProfilePlanBenefitsMotion: NSViewControllerRepresentable {
    let tier: LocalBadgeTier

    func makeNSViewController(context: Context) -> Controller {
        let controller = Controller(rootView: AnyView(EmptyView()))
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        controller.motion.host = controller.view
        return controller
    }

    func updateNSViewController(_ controller: Controller, context: Context) {
        if let previous = controller.tier, previous != tier {
            let tiers = LocalBadgeTier.allCases
            let forward = (tiers.firstIndex(of: tier) ?? 0) > (tiers.firstIndex(of: previous) ?? 0)
            controller.direction = (forward ? 1 : -1) * (context.environment.layoutDirection == .leftToRight ? 1 : -1)
        }
        controller.tier = tier
        controller.rootView = AnyView(
            ProfilePlanBenefits(tier: tier)
                .background(EverPopupStepAnchor(id: tier.rawValue))
                .environment(\.everPopupStepMotion, controller.motion)
                .environment(\.everPopupStepDirection, controller.direction)
                .environment(\.self, context.environment)
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsViewController: Controller, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return nsViewController.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    static func dismantleNSViewController(_ controller: Controller, coordinator: ()) {
        controller.motion.stop()
    }

    final class Controller: NSHostingController<AnyView> {
        let motion = EverPopupStepMotion()
        var tier: LocalBadgeTier?
        var direction = 1.0
    }
}
#endif
private struct ProfilePlanBenefits: View {
    let tier: LocalBadgeTier

    var body: some View {
            EverSurfaceCard {
                VStack(alignment: .leading, spacing: EverSpacing.x4) {
                    VStack(alignment: .leading, spacing: EverSpacing.x1) {
                        Text("\(tier.title) Preview").font(TimeMasterFont.heading())
                        Text("For your local profile · Design only")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(EverColor.textSecondary)
                    }
                    HStack(alignment: .center, spacing: EverSpacing.x2) {
                        ProfilePreviewPrice(
                            amount: "Preview",
                            period: " only",
                            periodAccessibilityLabel: "only, no charge",
                            amountFont: TimeMasterFont.display(),
                            periodFont: TimeMasterFont.caption()
                        )
                        Spacer(minLength: EverSpacing.x2)
                    }
                    Divider().overlay(EverColor.borderSubtle)
                    ProfileMembershipBenefits(tier: tier)
                    Text("No purchase, subscription, billing, network account, identity verification, trusted status, or additional privileges. Applying only saves a labeled local Preview.")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(EverColor.textSecondary)
                }
            }
    }
}

struct ProfileMembershipBenefits: View {
    let tier: LocalBadgeTier

    var body: some View {
        VStack(alignment: .leading, spacing: EverSpacing.x4) {
            ForEach(ProfileMembershipCopy.benefits(tier), id: \.title) { benefit in
                HStack(alignment: .top, spacing: EverSpacing.x3) {
                    Image(systemName: benefit.symbol)
                        .frame(width: EverSpacing.x5)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: EverSpacing.x1) {
                        Text(benefit.title).font(TimeMasterFont.rowTitle())
                        Text(benefit.detail).font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfileMembershipBenefit {
    let title: String
    let detail: String
    let symbol: String
}

enum ProfileMembershipCopy {
    static func benefits(_ tier: LocalBadgeTier) -> [ProfileMembershipBenefit] {
        switch tier {
        case .blue:
            [
                .init(title: "A Blue signature", detail: "Explore the original Blue badge design.", symbol: "paintpalette"),
                .init(title: "Your local profile", detail: "A labeled Preview on this device.", symbol: "person.crop.circle"),
                .init(title: "No subscription", detail: "No payment, identity check, or added privileges.", symbol: "checkmark.shield")
            ]
        case .silver:
            [
                .init(title: "A silver signature", detail: "Sculpted metal. A distinct finish.", symbol: "seal"),
                .init(title: "Your local profile", detail: "Silver styling, explicitly labeled Preview.", symbol: "person.crop.circle"),
                .init(title: "No organization or plan", detail: "No team accounts, entitlement, or trusted status.", symbol: "checkmark.shield")
            ]
        case .gold:
            [
                .init(title: "A gold signature", detail: "The original design's distinctive finish.", symbol: "seal"),
                .init(title: "Your local profile", detail: "Gold styling, explicitly labeled Preview.", symbol: "person.crop.circle"),
                .init(title: "No purchase", detail: "Saved only on this device. No billing or benefits.", symbol: "checkmark.shield")
            ]
        }
    }
}

extension LocalVerificationProgress {
    init(profile: LocalUserProfile, history: [WorkoutHistoryEntry], activities: [OutdoorActivity], now: Date = Date(), calendar: Calendar = .current) {
        let indoor = history.map {
            LocalTrainingSession(id: $0.id.uuidString, completedAt: $0.completedAt, isComplete: !$0.isPartial)
        }
        let outdoor = activities.map {
            LocalTrainingSession(
                id: $0.id.uuidString,
                completedAt: $0.endedAt ?? $0.startedAt.addingTimeInterval(TimeInterval(max(0, $0.elapsedSeconds))),
                isComplete: $0.finished && $0.establishedAt != nil
            )
        }
        self.init(createdAt: profile.createdAt, sessions: indoor + outdoor, now: now, calendar: calendar)
    }
}
