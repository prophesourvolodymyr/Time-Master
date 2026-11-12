import SwiftUI

#if os(iOS)
struct WorkoutHapticsSettingsCard: View {
    @AppStorage(WorkoutHaptics.enabledKey) private var enabled = true

    var body: some View {
        SettingsMenuCard {
            SettingsActionRow(title: "Haptics", symbol: "iphone.radiowaves.left.and.right") {
                Toggle("Haptics", isOn: $enabled)
                    .labelsHidden()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Taps on countdowns and when the exercise or rest changes")
    }
}

struct WorkoutLockScreenSettingsCard: View {
    @AppStorage(WorkoutLockScreenSettings.buttonsKey) private var buttons = "exercises"
    @AppStorage(WorkoutLockScreenSettings.skipSecondsKey) private var skipSeconds = 15
    @AppStorage(WorkoutLockScreenSettings.scrubKey) private var scrubbing = true

    var body: some View {
        SettingsMenuCard {
            VStack(alignment: .leading, spacing: EverSpacing.x3) {
                SettingsActionRow(title: "Lock Screen Player", symbol: "lock.iphone")
                Picker("Lock Screen buttons", selection: $buttons) {
                    Image(systemName: "forward.end.fill").tag("exercises")
                        .accessibilityLabel("Next and previous exercise")
                    Image(systemName: "goforward").tag("seconds")
                        .accessibilityLabel("Skip seconds")
                }
                .pickerStyle(.segmented)
                if buttons == "seconds" {
                    Picker("Seconds per skip", selection: $skipSeconds) {
                        ForEach(WorkoutLockScreenSettings.skipChoices, id: \.self) { seconds in
                            Text("\(seconds)s").tag(seconds)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Toggle(isOn: $scrubbing) {
                    Image(systemName: "slider.horizontal.below.rectangle")
                        .accessibilityLabel("Scrubbing moves the workout")
                }
                .frame(minHeight: EverLayout.minimumTouchTarget)
            }
        }
    }
}
#endif
