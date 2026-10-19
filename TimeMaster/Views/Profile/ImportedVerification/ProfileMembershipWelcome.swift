import SwiftUI

struct ProfileMembershipReceipt: Identifiable {
    let id = UUID()
    let tier: LocalBadgeTier
    var isMilestone = false
}

struct ProfileMembershipWelcome: View {
    let receipt: ProfileMembershipReceipt
    let onFinish: () -> Void
    @EnvironmentObject private var profileStore: LocalProfileStore
    @Environment(\.everPopupDismiss) private var popupDismiss
    @Environment(\.everPageIsOpening) private var isPageOpening
    @State private var page = 0
    @State private var stepTransitionDirection = StepTransitionDirection.forward
    @State private var didFinish = false

    private enum StepTransitionDirection: Equatable {
        case forward
        case backward
    }

    private var benefits: [ProfileMembershipBenefit] {
        receipt.isMilestone ? [
            .init(title: "180 calendar days", detail: "Your local profile has reached the required age.", symbol: "hourglass"),
            .init(title: "100 completed sessions", detail: "Distinct completed sessions in the trailing 180 days.", symbol: "figure.strengthtraining.traditional"),
            .init(title: "75 distinct active days", detail: "A local consistency record, not identity verification or a badge tier.", symbol: "calendar")
        ] : ProfileMembershipCopy.benefits(receipt.tier)
    }
    private var pageCount: Int { benefits.count + 1 }
    private var profileName: String {
        profileStore.profile.displayName
    }
    private var badgeColor: Color {
        switch receipt.tier {
        case .blue: return .blue
        case .silver: return Color(red: 0.72, green: 0.76, blue: 0.81)
        case .gold: return Color(red: 0.91, green: 0.68, blue: 0.18)
        }
    }
    private var title: String {
        if page == 0 { return receipt.isMilestone ? "Milestone saved locally" : "\(receipt.tier.title) Preview saved" }
        return benefits[page - 1].title
    }
    private var primaryActionTitle: String {
        if page == pageCount - 1 { return "Done" }
        return page == 0 ? "See details" : "Continue"
    }

    var body: some View {
        EverPopup(
            title: title,
            step: "\(page + 1) of \(pageCount)",
            onBack: page > 0 ? { setPage(page - 1, direction: .backward) } : nil,
            onEscape: finish
        ) {
            VStack(spacing: EverSpacing.x4) {
                ProfileMembershipCelebration(
                    tier: receipt.tier,
                    color: badgeColor,
                    celebrates: page == 0 && receipt.isMilestone,
                    isMilestone: receipt.isMilestone
                )
                if page == 0 {
                    Text(profileName)
                        .font(TimeMasterFont.sectionTitle()).multilineTextAlignment(.center)
                } else {
                    Label(benefits[page - 1].detail, systemImage: benefits[page - 1].symbol)
                        .font(TimeMasterFont.body())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
        } actions: {
            Button(primaryActionTitle) {
                if page == pageCount - 1 {
                    finish()
                } else {
                    setPage(page + 1, direction: .forward)
                }
            }
            .buttonStyle(EverPrimaryButtonStyle())
            .accessibilityIdentifier("pro-welcome-continue")
            if page < pageCount - 1 {
                Button("Skip tour", action: finish)
                    .buttonStyle(EverSecondaryButtonStyle())
            }
        }
        .environment(\.everPopupStepDirection, stepTransitionDirection == .forward ? 1 : -1)
        .overlay {
            if !isPageOpening {
                ProfileMembershipConfetti(
                    color: badgeColor,
                    isActive: page == 0 && receipt.isMilestone
                )
            }
        }
    }

    private func setPage(_ nextPage: Int, direction: StepTransitionDirection) {
        guard !didFinish, nextPage != page, nextPage >= 0, nextPage < pageCount else { return }
        stepTransitionDirection = direction
        page = nextPage
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        popupDismiss(or: {})
        onFinish()
    }
}

private struct ProfileMembershipCelebration: View {
    let tier: LocalBadgeTier
    let color: Color
    let celebrates: Bool
    let isMilestone: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @ScaledMetric(relativeTo: .title) private var badgeSize = EverLayout.minimumTouchTarget * 2

    var body: some View {
        Group {
            if isMilestone {
                Image(systemName: "medal")
                    .font(.system(size: badgeSize * 0.8, weight: .semibold))
                    .foregroundStyle(EverColor.accent)
            } else {
                ProfileVerificationBadge(tier: tier, color: color, size: badgeSize)
                    .accessibilityLabel("\(tier.title) Preview, not verified")
            }
        }
            .scaleEffect(arrived || reduceMotion || !celebrates ? 1 : 0.88)
            .frame(width: badgeSize * 1.6, height: badgeSize * 1.6)
            .onAppear {
                if reduceMotion || !celebrates {
                    arrived = true
                } else {
                    withAnimation(EverMotion.state) { arrived = true }
                }
            }
            .onChange(of: reduceMotion) { if $0 { arrived = true } }
    }
}
