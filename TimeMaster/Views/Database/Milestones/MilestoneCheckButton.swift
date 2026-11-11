import SwiftUI
import TimeMasterCore

/// The check of a milestone: a ring to tick, a filled accent disc once it is reached.
struct MilestoneCheckButton: View {
    let milestone: Milestone
    var size: CGFloat = 38
    /// On a cover the ring gets a dark base so it reads on any picture.
    var overPicture = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(milestone.isDone ? Theme.toolbarOrange : Color.black.opacity(overPicture ? 0.45 : 0))
                Circle().strokeBorder(milestone.isDone ? Color.clear : Color.white.opacity(overPicture ? 0.75 : 0.45), lineWidth: 1.5)
                if milestone.isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(.black)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .keyNavPlainButtonStyle(shape: .circle)
        .help(milestone.isDone ? "Reopen" : "Mark as reached")
        .accessibilityLabel(milestone.title)
        .accessibilityValue(milestone.isDone ? "Reached" : "Not reached")
        .accessibilityHint(milestone.isDone ? "Opens it again" : "Marks it reached")
        .accessibilityAddTraits(milestone.isDone ? .isSelected : [])
    }
}
