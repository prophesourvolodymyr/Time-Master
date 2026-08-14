import SwiftUI

struct DurationPickerView: View {
    @Binding var seconds: Int
    let range: ClosedRange<Int>
    let step: Int
    var compact = false

    private var minutes: Int { seconds / 60 }
    private var remainder: Int { seconds % 60 }

    var body: some View {
        Group {
            #if os(iOS)
            HStack(spacing: compact ? 5 : 8) {
                Picker("Minutes", selection: Binding(
                    get: { minutes },
                    set: { update(minutes: $0, seconds: remainder) }
                )) {
                    ForEach(0...max(1, range.upperBound / 60), id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: compact ? 48 : 64, height: compact ? 44 : 72)
                .clipped()

                Text(":")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)

                Picker("Seconds", selection: Binding(
                    get: { remainder },
                    set: { update(minutes: minutes, seconds: $0) }
                )) {
                    ForEach(Array(stride(from: 0, through: 55, by: max(1, step))), id: \.self) { value in
                        Text(String(format: "%02d", value)).tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: compact ? 52 : 68, height: compact ? 44 : 72)
                .clipped()
            }
            #else
            HStack(spacing: 4) {
                Text(durationLabel)
                    .font(.system(size: compact ? 10 : 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Stepper("", value: $seconds, in: range, step: step)
                    .labelsHidden()
                    .controlSize(compact ? .small : .regular)
            }
            #endif
        }
        .onChange(of: seconds) { _ in clamp() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Duration")
        .accessibilityValue(durationLabel)
    }

    private var durationLabel: String {
        if minutes == 0 { return "\(remainder) seconds" }
        return "\(minutes) minutes \(remainder) seconds"
    }

    private func update(minutes: Int, seconds: Int) {
        let candidate = minutes * 60 + seconds
        self.seconds = min(range.upperBound, max(range.lowerBound, candidate))
    }

    private func clamp() {
        seconds = min(range.upperBound, max(range.lowerBound, seconds))
    }
}
