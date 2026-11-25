import SwiftUI
import TimeMasterCore

/// The big title of a Skills page section, drawn like the Workouts page's (`WorkoutGroupHeader`): the category's
/// picture (or its brand icon) on a rounded square, its name, how many skills it shows and a round fold chevron over a
/// hairline. Clicking the name folds the section; clicking the square, or "Change picture" in the menu, opens the icon
/// chooser of the folder that stands for the category (`page`). Without `onToggle` (search results, where nothing folds)
/// it is a plain heading with no chevron and a square that does nothing.
struct SkillCategoryHeader: View {
    let category: SkillCategory
    let count: Int
    var page: ExercisePage?
    var isFolded = false
    var onToggle: (() -> Void)?
    var onChangePicture: (() -> Void)?

    #if os(macOS)
    private let iconSide: CGFloat = 48
    #else
    private let iconSide: CGFloat = 44
    #endif

    var body: some View {
        heading
            .tmaxBrandGlow(.white)
    }

    @ViewBuilder
    private var heading: some View {
        if let onToggle {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    iconButton
                    Button(action: onToggle) {
                        HStack(spacing: 10) {
                            titleAndCount
                            Spacer(minLength: 8)
                            chevron
                        }
                        .frame(minHeight: iconSide)
                        .contentShape(Rectangle())
                    }
                    .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
                    .accessibilityLabel(category.title)
                    .accessibilityValue("\(SkillCopy.count(count, "skill", "skills")), \(isFolded ? "folded" : "open")")
                    .accessibilityHint("Shows or hides its skills")
                    .accessibilityAddTraits(.isHeader)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 10)
                hairline
            }
            .contextMenu {
                if let onChangePicture {
                    Button(action: onChangePicture) {
                        Label("Change picture", systemImage: "photo")
                    }
                }
                Button(action: onToggle) {
                    Label(isFolded ? "Show skills" : "Hide skills", systemImage: isFolded ? "chevron.down" : "chevron.up")
                }
            }
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    icon
                    titleAndCount
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 10)
                hairline
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(category.title)
            .accessibilityValue(SkillCopy.count(count, "skill", "skills"))
            .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private var iconButton: some View {
        if let onChangePicture {
            Button(action: onChangePicture) {
                icon
                    .overlay(alignment: .bottomTrailing) {
                        if page?.iconImageURL == nil { pictureBadge }
                    }
            }
            .buttonStyle(SkillsPressStyle(cornerRadius: iconSide * 0.28))
            .accessibilityLabel("Change picture of \(category.title)")
            .accessibilityHint("Opens the icon picker")
            .help("Change picture")
        } else {
            icon
        }
    }

    private var icon: some View {
        SkillCardIcon(page: page, category: category, size: iconSide, brandTile: true)
    }

    private var pictureBadge: some View {
        Image(systemName: "camera.fill")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(Theme.background)
            .frame(width: 18, height: 18)
            .background(Circle().fill(Theme.toolbarOrange))
            .overlay(Circle().strokeBorder(Theme.background, lineWidth: 1.5))
            .offset(x: 4, y: 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var titleAndCount: some View {
        HStack(spacing: 10) {
            Text(category.title)
                .font(TimeMasterFont.black(24, relativeTo: .title2))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text("\(count)")
                .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.numericText())
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.textSecondary)
            .rotationEffect(.degrees(isFolded ? -90 : 0))
            .frame(width: 30, height: 30)
            .background(Color.white.opacity(0.06), in: Circle())
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 8)
    }
}
