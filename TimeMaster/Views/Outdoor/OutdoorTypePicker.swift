#if os(iOS)
import SwiftUI

struct OutdoorTypePicker: View {
    @Binding var previewKind: OutdoorActivityKind
    let committedKind: OutdoorActivityKind
    let onCommit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OutdoorAdaptivePane { compact in
            VStack(spacing: 8) {
                if compact {
                    OutdoorActivityTypePicker(kind: $previewKind)
                } else {
                    Picker("Workout type", selection: $previewKind) {
                        ForEach(OutdoorActivityKind.newRecordingChoices) { kind in
                            Label(kind.displayName, systemImage: kind.iconName)
                                .tag(kind)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .accessibilityLabel("Workout type preview")
                }
                Text("Preview \(previewKind.displayName)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } actions: { compact in
            Button(action: onCommit) {
                OutdoorPaneActionLabel(title: "Use \(previewKind.displayName)", systemImage: "checkmark", compact: compact)
            }
            .buttonStyle(OutdoorPineButtonStyle(prominent: true, circular: compact))
            .accessibilityLabel("Commit \(previewKind.displayName)")
            .accessibilityValue("Current Start type: \(committedKind.displayName)")
            .accessibilityHint("Accept the selected preview")
            .symbolEffectIfAvailable(reduceMotion: reduceMotion, value: previewKind)
        }
    }
}

extension View {
    @ViewBuilder
    func symbolEffectIfAvailable<Value: Equatable>(reduceMotion: Bool, value: Value) -> some View {
        if #available(iOS 17.0, *), !reduceMotion {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }
}
#endif
