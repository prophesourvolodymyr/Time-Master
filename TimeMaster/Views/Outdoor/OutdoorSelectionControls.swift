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
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(OutdoorAccessoryButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(selected?.title ?? "")
        .accessibilityHint("Open choices")
    }
}

struct OutdoorAccessoryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(reduceTransparency ? Theme.surface2 : Color.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(reduceMotion ? .none : .spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct OutdoorSearchBar<Accessory: View>: View {
    @Binding var text: String
    let placeholder: String
    @ViewBuilder var accessory: () -> Accessory
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel(placeholder)
                .layoutPriority(1)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            accessory()
        }
        .font(.body)
        .padding(.leading, 14)
        .padding(.trailing, 5)
        .padding(.vertical, 5)
        .background(reduceTransparency ? Theme.surface2 : Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
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

    var body: some View {
        OutdoorChoicePicker(
            title: "Workout visibility",
            selection: $visibility,
            options: [
                OutdoorChoiceOption(id: .privateVisibility, title: "Private", systemImage: "lock.fill"),
                OutdoorChoiceOption(id: .publicVisibility, title: "Public", systemImage: "globe")
            ]
        )
    }
}
#endif
