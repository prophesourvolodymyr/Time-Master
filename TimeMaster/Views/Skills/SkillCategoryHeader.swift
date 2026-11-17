import SwiftUI

/// The big title of a Skills page section, drawn like the Workouts page's (`WorkoutGroupHeader`): the category's
/// symbol, its name, how many skills it shows and a round fold chevron over a hairline. Clicking it folds the section.
/// Without `onToggle` (search results, where nothing folds) it is a plain heading with no chevron.
struct SkillCategoryHeader: View {
    let category: SkillCategory
    let count: Int
    var isFolded = false
    var onToggle: (() -> Void)?

    var body: some View {
        if let onToggle {
            Button(action: onToggle) {
                label(showsChevron: true)
            }
            .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
            .accessibilityLabel(category.title)
            .accessibilityValue("\(SkillCopy.count(count, "skill", "skills")), \(isFolded ? "folded" : "open")")
            .accessibilityHint("Shows or hides its skills")
            .accessibilityAddTraits(.isHeader)
        } else {
            label(showsChevron: false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(category.title)
                .accessibilityValue(SkillCopy.count(count, "skill", "skills"))
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func label(showsChevron: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.toolbarOrange)
                    .frame(width: 30, height: 30)
                Text(category.title)
                    .font(TimeMasterFont.black(24, relativeTo: .title2))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(count)")
                    .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText())
                Spacer(minLength: 8)
                if showsChevron {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(isFolded ? -90 : 0))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 10)
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 8)
        }
        .contentShape(Rectangle())
    }
}
