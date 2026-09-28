#if os(iOS)
import SwiftUI
import TimeMasterCore

struct OutdoorChoiceOption<Value: Hashable>: Identifiable {
    let id: Value
    let title: String
    let systemImage: String
}

struct OutdoorChoicePicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [OutdoorChoiceOption<Value>]
    var compact = false

    private var selected: OutdoorChoiceOption<Value>? {
        options.first { $0.id == selection }
    }

    var body: some View {
        Group {
            if compact {
                menu.buttonStyle(SpotlightCircleButtonStyle())
            } else {
                menu.buttonStyle(OutdoorAccessoryButtonStyle())
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(selected?.title ?? "")
        .accessibilityHint("Open choices")
    }

    private var menu: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Label(option.title, systemImage: option.systemImage)
                        .tag(option.id)
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let selected {
                    Image(systemName: selected.systemImage)
                    if !compact {
                        Text(selected.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if !compact {
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
    }
}

struct OutdoorAccessoryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .frame(minWidth: 44, minHeight: 44)
            .background(reduceTransparency ? Theme.surface2 : Color.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(reduceMotion ? .none : .spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct OutdoorActivityTypePicker: View {
    @Binding var kind: OutdoorActivityKind

    var body: some View {
        OutdoorChoicePicker(
            title: "Workout type",
            selection: $kind,
            options: (kind == .runWalk ? OutdoorActivityKind.allCases : OutdoorActivityKind.newRecordingChoices).map {
                OutdoorChoiceOption(id: $0, title: $0.displayName, systemImage: $0.iconName)
            }
        )
    }
}

struct OutdoorVisibilityPicker: View {
    @Binding var visibility: OutdoorActivityVisibility
    var prominent = false

    var body: some View {
        OutdoorChoicePicker(
            title: "Workout visibility",
            selection: $visibility,
            options: [
                OutdoorChoiceOption(id: .privateVisibility, title: "Private", systemImage: "lock.fill"),
                OutdoorChoiceOption(id: .publicVisibility, title: "Public", systemImage: "globe")
            ]
        )
        .background(prominent ? Theme.restAccent.opacity(0.85) : .clear, in: Capsule())
    }
}
#endif
