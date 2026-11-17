import SwiftUI

/// The choice for a section's sets: a countdown, or "Until Done" (each set ends when the user taps Done and its
/// duration is only the estimate the workout's totals use). Binds to `Section.isTimerEnabled`.
struct SectionTimingPicker: View {
    @Binding var isTimerEnabled: Bool

    var body: some View {
        Picker("Timing", selection: $isTimerEnabled) {
            Text("Timer").tag(true)
            Text("Until Done").tag(false)
        }
        .pickerStyle(.segmented)
        .keyNavTarget(role: .primary, shape: .roundedRectangle(cornerRadius: 8), action: { isTimerEnabled.toggle() })
        .accessibilityHint("Until Done ends each set when you tap Done; its time is only an estimate.")
    }
}
