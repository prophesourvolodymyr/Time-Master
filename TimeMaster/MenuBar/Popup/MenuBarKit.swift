import SwiftUI

enum MenuBarMetrics {
    static let cornerRadius: CGFloat = 22
    static let heroHeight: CGFloat = 168
    static let buttonHeight: CGFloat = 40

    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }
}

struct MenuBarCard<Content: View>: View {
    var emphasized = false
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.widgetTint, .graphite)
            .background {
                ZStack {
                    WidgetTint.graphite.base
                    WidgetSheen(tint: .graphite)
                }
            }
            .clipShape(MenuBarMetrics.shape)
            .overlay {
                MenuBarMetrics.shape
                    .strokeBorder(Color.white.opacity(emphasized ? 0.12 : 0.06), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct MenuBarHeroCard<Controls: View>: View {
    let art: WidgetArt
    var label: String?
    let title: String
    var meta: String?
    private let controls: Controls

    init(art: WidgetArt, label: String? = nil, title: String, meta: String? = nil, @ViewBuilder controls: () -> Controls) {
        self.art = art
        self.label = label
        self.title = title
        self.meta = meta
        self.controls = controls()
    }

    var body: some View {
        WidgetCard(art: art, spot: .side) {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 4) {
                    if let label {
                        WidgetLabel(text: label)
                    }
                    WidgetTitle(text: title, size: 24, lines: 2)
                    if let meta {
                        WidgetLabel(text: meta)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 8) { controls }
                }
                .frame(width: max(0, proxy.size.width - WidgetArtSpot.sideRoom(forHeight: proxy.size.height)), alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(16)
        }
        .frame(height: MenuBarMetrics.heroHeight)
        .clipShape(MenuBarMetrics.shape)
    }
}

struct MenuBarSectionTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(TimeMasterFont.black(15, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(WidgetFont.label())
                    .foregroundStyle(WidgetTint.graphite.secondaryInk)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct MenuBarRing<Center: View>: View {
    var progress: Double
    var lineWidth: CGFloat = 8
    var tint: Color = Theme.toolbarOrange
    @ViewBuilder var center: Center

    var body: some View {
        let clamped = min(1, max(0, progress.isFinite ? progress : 0))
        ZStack {
            Circle()
                .stroke(WidgetTint.graphite.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.45), radius: lineWidth * 0.6)
                .opacity(clamped > 0 ? 1 : 0)
            center
        }
        .padding(lineWidth / 2)
    }
}

struct MenuBarStat: View {
    let value: String
    let caption: String
    var tint: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(WidgetFont.hero(26))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(WidgetFont.label())
                .foregroundStyle(WidgetTint.graphite.secondaryInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct MenuBarEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.toolbarOrange)
                .frame(width: 44, height: 44)
                .background(WidgetTint.graphite.softFill, in: Circle())
                .accessibilityHidden(true)
            WidgetTitle(text: title, size: 18, lines: 2)
                .multilineTextAlignment(.center)
            Text(message)
                .font(WidgetFont.label())
                .foregroundStyle(WidgetTint.graphite.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }
}

struct MenuBarArtTile: View {
    let art: WidgetArt
    var size: CGFloat = 36

    var body: some View {
        Image(art.assetName)
            .resizable()
            .interpolation(.high)
            .aspectRatio(1, contentMode: .fill)
            .scaleEffect(1.3)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

struct MenuBarChip: View {
    let text: String
    var tint: Color = WidgetTint.graphite.secondaryInk
    var filled = false

    var body: some View {
        Text(text)
            .font(TimeMasterFont.black(11, relativeTo: .caption2))
            .foregroundStyle(filled ? WidgetTint.orange.ink : tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(filled ? tint : tint.opacity(0.14)))
    }
}

struct MenuBarRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .keyNavButtonSurface(.standard)
    }
}

struct MenuBarCompactButton: View {
    let title: String
    let symbol: String
    var prominent = false
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WidgetPillLabel(
                title: title,
                systemImage: symbol,
                prominent: prominent,
                fillsWidth: fillsWidth,
                diameter: MenuBarMetrics.buttonHeight
            )
        }
        .buttonStyle(SkillsPressStyle(cornerRadius: MenuBarMetrics.buttonHeight / 2))
        .accessibilityLabel(title)
    }
}

struct MenuBarScheduledRow: View {
    let item: ScheduledWorkout
    var showsStart = true
    @Environment(\.menuBarActions) private var actions

    private var canStart: Bool {
        item.status == .pending && !item.workout.sections.isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            MenuBarArtTile(art: .forWorkout(item.workout), size: 36)
            Button {
                actions.openWorkoutDetail(item.workout.id)
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(WorkoutTitle.short(item.workout.name))
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(item.timeRangeText)
                        .font(WidgetFont.label())
                        .foregroundStyle(WidgetTint.graphite.secondaryInk)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuBarRowButtonStyle())
            .accessibilityLabel(item.workout.name)
            if showsStart && canStart {
                HomeIconButton(
                    systemImage: "play.fill",
                    label: "Start \(item.workout.name)",
                    diameter: 36
                ) {
                    actions.startWorkout(item.workout.id)
                }
            } else {
                MenuBarChip(text: item.status.title, tint: statusTint, filled: item.status == .completed)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusTint: Color {
        switch item.status {
        case .pending: WidgetTint.graphite.secondaryInk
        case .completed: WidgetTint.orange.base
        case .missed: WidgetTint.peach.base
        }
    }
}
