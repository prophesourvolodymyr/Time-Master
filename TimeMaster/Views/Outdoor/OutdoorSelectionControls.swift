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
    var prominent = false

    private var selected: OutdoorChoiceOption<Value>? {
        options.first { $0.id == selection }
    }

    var body: some View {
        menu.buttonStyle(TimeMasterActionButtonStyle(prominent: prominent, circular: compact))
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
            ],
            prominent: prominent
        )
    }
}
#endif
