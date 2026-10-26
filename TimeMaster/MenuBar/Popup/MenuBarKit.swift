import SwiftUI

struct MenuBarCard<Content: View>: View {
    var emphasized = false
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(TimeMasterCardSurface(cornerRadius: 18, accent: .white, emphasized: emphasized))
    }
}

struct MenuBarSectionTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

struct MenuBarRing<Center: View>: View {
    var progress: Double
    var lineWidth: CGFloat = 8
    var tint: Color = Theme.toolbarOrange
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.separator, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center
        }
    }
}

struct MenuBarStat: View {
    let value: String
    let caption: String
    var tint: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(TimeMasterFont.black(22, relativeTo: .title3))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
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
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(TimeMasterFont.secondary())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }
}

struct MenuBarTypeTile: View {
    let colorHex: String
    let symbol: String
    var size: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(Color(hex: colorHex).opacity(0.22))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color(hex: colorHex))
            }
            .accessibilityHidden(true)
    }
}

struct MenuBarChip: View {
    let text: String
    var tint: Color = Theme.textSecondary
    var filled = false

    var body: some View {
        Text(text)
            .font(TimeMasterFont.black(11, relativeTo: .caption2))
            .foregroundStyle(filled ? Color.black : tint)
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
            Label(title, systemImage: symbol)
                .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                .lineLimit(1)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
        .buttonStyle(TimeMasterActionButtonStyle(
            prominent: prominent,
            minimumSize: 40,
            fillsWidth: fillsWidth,
            tint: prominent ? Theme.toolbarOrange : Theme.surface2
        ))
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
            MenuBarTypeTile(colorHex: item.workout.type.colorHex, symbol: item.workout.type.iconName, size: 34)
            Button {
                actions.openWorkoutDetail(item.workout.id)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.workout.name)
                        .font(TimeMasterFont.rowTitle())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(item.timeRangeText)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuBarRowButtonStyle())
            MenuBarChip(text: item.status.title, tint: statusTint)
            if showsStart && canStart {
                Button {
                    actions.startWorkout(item.workout.id)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 36, tint: Theme.surface2))
                .accessibilityLabel("Start \(item.workout.name)")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusTint: Color {
        switch item.status {
        case .pending: Theme.toolbarOrange
        case .completed: Color(hex: "34C759")
        case .missed: Color(hex: "FF3B30")
        }
    }
}
