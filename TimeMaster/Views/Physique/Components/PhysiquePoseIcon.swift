import SwiftUI

struct PhysiquePoseIcon: View {
    let pose: PhysiquePose
    var accepted = false
    var selected = false

    @ScaledMetric(relativeTo: .body) private var illustrationHeight: CGFloat = 68
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ViewThatFits {
            VStack(spacing: 5) {
                PhysiqueAthleteIllustration(pose: pose)
                    .frame(width: illustrationHeight * 0.72, height: illustrationHeight)
                    .accessibilityHidden(true)

                Text(pose == .rear ? "Back" : pose.shortTitle)
                    .font(TimeMasterFont.label())
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if selected {
                    Label("Current", systemImage: "smallcircle.filled.circle")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(contrast == .increased ? Theme.textPrimary : Theme.toolbarOrange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if accepted {
                    Label("Accepted", systemImage: "checkmark.circle.fill")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(8)

            PhysiqueAthleteIllustration(pose: pose)
                .aspectRatio(0.72, contentMode: .fit)
                .accessibilityHidden(true)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pose.title) pose")
        .accessibilityValue(accessibilityState)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var accessibilityState: String {
        if selected && accepted { return "Current, Accepted" }
        if selected { return "Current" }
        return accepted ? "Accepted" : ""
    }
}
