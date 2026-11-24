import SwiftUI
#if os(iOS)
import UIKit
#endif

extension HomeWidgetPlatform {
    static var canRecordOutdoor: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
}

struct HomeWidgetActions {
    var startWorkout: (UUID) -> Void
    var planWorkout: (Date, UUID?) -> Void
    var createWorkout: () -> Void
    var browseWorkouts: () -> Void
    var browseDatabase: () -> Void
    var addSkill: () -> Void
    var removeWidget: () -> Void
}

enum HomeNavigation {
    static func open(_ destination: SlotNavigationDestination) {
        NotificationCenter.default.post(
            name: .openAppPage,
            object: nil,
            userInfo: ["destination": destination.rawValue]
        )
    }

    static func openPage(id: String) {
        NotificationCenter.default.post(name: .openDatabasePage, object: nil, userInfo: ["pageID": id])
    }

    static func openWorkoutDetail(id: UUID) {
        NotificationCenter.default.post(name: .openWorkoutDetail, object: nil, userInfo: ["workoutID": id])
    }
}

struct HomeCardHeader: View {
    let title: String
    let systemImage: String
    var trailing: String?
    var tint: Color = Theme.toolbarOrange

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
            Text(title)
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trailing.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(.isHeader)
    }
}

struct HomeRingBadge: View {
    let fraction: Double
    let label: String
    var diameter: CGFloat = 56
    var lineWidth: CGFloat = 6
    var tint: Color = Theme.toolbarOrange

    var body: some View {
        ZStack {
            SkillProgressRing(fraction: fraction, tint: tint, lineWidth: lineWidth)
            if fraction < 1 {
                Text(label)
                    .font(TimeMasterFont.black(max(11, diameter * 0.26), relativeTo: .headline))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, lineWidth + 2)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

struct HomeWorkoutTile: View {
    let systemImage: String
    let colorHex: String
    var side: CGFloat = 56

    var body: some View {
        let tint = Color(hex: HomeColor.accentHex(colorHex))
        RoundedRectangle(cornerRadius: side * 0.3, style: .continuous)
            .fill(LinearGradient(
                colors: [tint.opacity(0.95), tint.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: side, height: side)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: side * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

struct HomePillButton: View {
    let title: String
    let systemImage: String
    var prominent = true
    var fillsWidth = false
    var hint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(prominent ? Color.black : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .frame(maxWidth: fillsWidth ? CGFloat.infinity : nil, minHeight: 44)
                .background(
                    prominent ? Color.white : Color.white.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(SkillsPressStyle(cornerRadius: 12))
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
    }
}

struct HomeIconButton: View {
    let systemImage: String
    let label: String
    var hint: String?
    var prominent = false
    var diameter: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.38, weight: .bold))
                .foregroundStyle(prominent ? Color.black : Theme.textPrimary)
                .frame(width: diameter, height: diameter)
                .background(prominent ? Color.white : Color.white.opacity(0.12), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(SkillsPressStyle(cornerRadius: diameter / 2))
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
    }
}

struct HomeInviteAction {
    var title: String
    var systemImage = "plus"
    var hint: String?
    var run: () -> Void
}

struct HomeInvite: View {
    let footprint: HomeWidgetFootprint
    let systemImage: String
    let headline: String
    var detail: String?
    var tint: Color = Theme.toolbarOrange
    var action: HomeInviteAction?

    var body: some View {
        switch footprint {
        case .compact: compact
        case .wide: wide
        case .square: square
        }
    }

    private var compact: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
            Text(headline)
                .font(TimeMasterFont.rowTitle())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if let action {
                HomePillButton(title: action.title, systemImage: action.systemImage, fillsWidth: true, hint: action.hint, action: action.run)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var wide: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .font(TimeMasterFont.heading())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let detail {
                    Text(detail)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                HomePillButton(title: action.title, systemImage: action.systemImage, hint: action.hint, action: action.run)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var square: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(tint)
            Text(headline)
                .font(TimeMasterFont.black(26, relativeTo: .title))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.75)
            if let detail {
                Text(detail)
                    .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)
            }
            if let action {
                HomePillButton(title: action.title, systemImage: action.systemImage, fillsWidth: true, hint: action.hint, action: action.run)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

struct HomeProgressBar: View {
    let fraction: Double
    var tint: Color = Theme.toolbarOrange
    var height: CGFloat = 5

    var body: some View {
        let clamped = min(1, max(0, fraction.isFinite ? fraction : 0))
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(tint)
                    .frame(width: clamped > 0 ? max(height, proxy.size.width * clamped) : 0)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct HomeKicker: View {
    let text: String
    let systemImage: String
    var tint: Color = Theme.toolbarOrange

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            Text(text.uppercased())
                .font(TimeMasterFont.black(11, relativeTo: .caption2))
                .kerning(0.5)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityHidden(true)
    }
}
