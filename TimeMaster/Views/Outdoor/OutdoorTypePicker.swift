#if os(iOS)
import SwiftUI

struct OutdoorTypePicker: View {
    @Binding var previewKind: OutdoorActivityKind
    let committedKind: OutdoorActivityKind
    let onCommit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Picker("Workout type", selection: $previewKind) {
                    ForEach(OutdoorActivityKind.newRecordingChoices) { kind in
                        HStack(spacing: 10) {
                            Image(systemName: kind.iconName)
                                .frame(width: 30)
                            Text(kind.displayName)
                        }
                        .tag(kind)
                        .accessibilityLabel(kind.displayName)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 190)
                .clipped()
                .accessibilityLabel("Workout type preview")
                .accessibilityValue("\(previewKind.displayName), not committed")
                Text("Preview \(previewKind.displayName)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textPrimary.opacity(0.60))
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)

            Button(action: onCommit) {
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
            }
            .buttonStyle(
                TimeMasterGlobalFrostedButtonStyle(
                    circular: true,
                    minimumSize: 48,
                    tintOpacity: 0.58
                )
            )
            .frame(width: 48, height: 48)
            .padding(.trailing, 12)
            .padding(.bottom, 82)
            .accessibilityLabel("Commit \(previewKind.displayName)")
            .accessibilityValue("Current Start type: \(committedKind.displayName)")
            .accessibilityHint("Accept the centered preview")
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
