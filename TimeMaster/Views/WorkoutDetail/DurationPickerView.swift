import SwiftUI

struct DurationPickerView: View {
    @Binding var seconds: Int
    let range: ClosedRange<Int>
    let step: Int
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    #if os(iOS)
    @State private var directEntry: DurationComponent?
    @State private var directEntryText = ""
    @FocusState private var isDirectEntryFocused: Bool
    #endif

    #if os(macOS)
    @State private var minuteText = ""
    @State private var secondText = ""
    @FocusState private var focusedMacComponent: DurationComponent?
    #endif

    private enum DurationComponent: Hashable {
        case minutes
        case seconds
    }

    private var minutes: Int { seconds / 60 }
    private var remainder: Int { seconds % 60 }
    private var maximumMinutes: Int { max(1, range.upperBound / 60) }
    private var selectableSeconds: [Int] {
        Array(stride(from: 0, through: 59, by: max(1, step)))
    }

    var body: some View {
        Group {
            #if os(iOS)
            if compact {
                compactDurationControl
            } else {
                wheelDurationControl
            }
            #else
            macOSDurationControl
            #endif
        }
        #if os(macOS)
        .onChange(of: seconds) { _, _ in
            synchronizeDurationState()
        }
        #else
        .onChange(of: seconds) { _ in
            synchronizeDurationState()
        }
        .onChange(of: isDirectEntryFocused) { isFocused in
            if !isFocused {
                finishDirectEntry()
            }
        }
        .toolbar {
            if directEntry != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        finishDirectEntry()
                    }
                }
            }
        }
        #endif
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Duration")
        .accessibilityValue(durationLabel)
    }

    #if os(iOS)
    private var compactDurationControl: some View {
        HStack(spacing: 2) {
            Button {
                adjust(by: -step)
            } label: {
                Image(systemName: "minus")
                    .font(.caption2.weight(.bold))
                    .padding(5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decrease duration")

            Text(clockString)
                .font(.caption.weight(.semibold).monospacedDigit())
                .frame(minWidth: 38)

            Button {
                adjust(by: step)
            } label: {
                Image(systemName: "plus")
                    .font(.caption2.weight(.bold))
                    .padding(5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Increase duration")
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(2)
        .background(Color.white.opacity(0.08), in: Capsule())
    }

    private var wheelDurationControl: some View {
        HStack(spacing: 12) {
            minuteWheel

            Text(":")
                .font(.system(size: 36, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)

            secondWheel
        }
        .frame(height: 174)
    }

    private var minuteWheel: some View {
        ZStack {
            Picker("Minutes", selection: Binding(
                get: { minutes },
                set: { update(minutes: $0, seconds: remainder) }
            )) {
                ForEach(0...maximumMinutes, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Minutes")
            .accessibilityHint("Tap to type a value.")

            directEntryOverlay(for: .minutes)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                beginDirectEntry(.minutes)
            }
        )
    }

    private var secondWheel: some View {
        ZStack {
            Picker("Seconds", selection: Binding(
                get: { remainder },
                set: { update(minutes: minutes, seconds: $0) }
            )) {
                ForEach(selectableSeconds, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Seconds")
            .accessibilityHint("Tap to type a value.")

            directEntryOverlay(for: .seconds)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                beginDirectEntry(.seconds)
            }
        )
    }

    @ViewBuilder
    private func directEntryOverlay(for component: DurationComponent) -> some View {
        if directEntry == component {
            ZStack {
                if directEntryText.isEmpty {
                    Text(displayValue(for: component))
                        .foregroundStyle(Theme.textPrimary)
                }

                TextField("", text: $directEntryText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .focused($isDirectEntryFocused)
                    .onChange(of: directEntryText) { value in
                        applyDirectEntry(value, for: component)
                    }
                    .accessibilityLabel(component == .minutes ? "Type minutes" : "Type seconds")
            }
            .frame(height: 50)
            .background(Theme.surface2.opacity(0.95), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.textSecondary.opacity(0.4), lineWidth: 1)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .task(id: directEntry) {
                guard directEntry == component else { return }
                isDirectEntryFocused = true
            }
        }
    }

    private func beginDirectEntry(_ component: DurationComponent) {
        directEntryText = ""
        withAnimation(reduceMotion ? nil : .snappy) {
            directEntry = component
        }
    }

    private func finishDirectEntry() {
        guard directEntry != nil else { return }
        directEntry = nil
        directEntryText = ""
        isDirectEntryFocused = false
    }

    private func applyDirectEntry(_ value: String, for component: DurationComponent) {
        guard let number = Int(value), number >= 0 else { return }

        switch component {
        case .minutes:
            update(
                minutes: min(maximumMinutes, number),
                seconds: remainder,
                animated: true
            )
        case .seconds:
            update(
                minutes: minutes,
                seconds: nearestSelectableSecond(to: min(59, number)),
                animated: true
            )
        }
    }
    #else
    @ViewBuilder
    private var macOSDurationControl: some View {
        if compact {
            macOSCompactDurationControl
        } else {
            macOSDirectDurationControl
        }
    }

    private var macOSCompactDurationControl: some View {
        HStack(spacing: 6) {
            Text(clockString)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .frame(minWidth: 80, alignment: .trailing)
                .accessibilityLabel("Duration")

            Stepper("", value: $seconds, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    private var macOSDirectDurationControl: some View {
        HStack(alignment: .center, spacing: 14) {
            macOSDigitEditor(for: .minutes, label: "MINUTES")

            Text(":")
                .font(.system(size: 58, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 18)

            macOSDigitEditor(for: .seconds, label: "SECONDS")
        }
        .onAppear {
            synchronizeDurationState()
        }
    }

    private func macOSDigitEditor(
        for component: DurationComponent,
        label: String
    ) -> some View {
        let text = macOSTextBinding(for: component)

        return VStack(spacing: 8) {
            ZStack {
                if text.wrappedValue.isEmpty {
                    Text(displayValue(for: component))
                        .foregroundStyle(Theme.textPrimary)
                }

                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 58, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .focused($focusedMacComponent, equals: component)
                    .onChange(of: text.wrappedValue) { _, value in
                        applyMacEntry(value, for: component)
                    }
                    .onChange(of: focusedMacComponent) { oldComponent, newComponent in
                        if newComponent == component {
                            beginMacEntry(component)
                        } else if oldComponent == component {
                            commitMacEntry(component)
                        }
                    }
                    .onSubmit {
                        commitMacEntry(component)
                        focusedMacComponent = nil
                    }
                    .accessibilityLabel(label.capitalized)
            }
            .frame(width: 130, height: 86)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(
                        focusedMacComponent == component
                            ? Theme.textPrimary
                            : Theme.textSecondary.opacity(0.35)
                    )
                    .frame(height: focusedMacComponent == component ? 2 : 1)
            }

            Text(label)
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func macOSTextBinding(for component: DurationComponent) -> Binding<String> {
        switch component {
        case .minutes:
            $minuteText
        case .seconds:
            $secondText
        }
    }

    private func beginMacEntry(_ component: DurationComponent) {
        switch component {
        case .minutes:
            minuteText = ""
        case .seconds:
            secondText = ""
        }
    }

    private func commitMacEntry(_ component: DurationComponent) {
        switch component {
        case .minutes:
            applyMacEntry(minuteText, for: component)
        case .seconds:
            applyMacEntry(secondText, for: component)
        }
        synchronizeDurationState()
    }

    private func applyMacEntry(_ value: String, for component: DurationComponent) {
        guard let number = Int(value), number >= 0 else { return }

        switch component {
        case .minutes:
            update(minutes: min(maximumMinutes, number), seconds: remainder)
        case .seconds:
            update(minutes: minutes, seconds: nearestSelectableSecond(to: min(59, number)))
        }
    }
    #endif

    private var clockString: String {
        String(format: "%d:%02d", minutes, remainder)
    }

    private var durationLabel: String {
        if minutes == 0 { return "\(remainder) seconds" }
        return "\(minutes) minutes \(remainder) seconds"
    }

    private func displayValue(for component: DurationComponent) -> String {
        switch component {
        case .minutes:
            String(minutes)
        case .seconds:
            String(format: "%02d", remainder)
        }
    }

    private func nearestSelectableSecond(to candidate: Int) -> Int {
        selectableSeconds.min { lhs, rhs in
            abs(lhs - candidate) < abs(rhs - candidate)
        } ?? 0
    }

    private func update(minutes: Int, seconds: Int, animated: Bool = false) {
        apply(minutes * 60 + seconds, animated: animated)
    }

    private func adjust(by delta: Int) {
        apply(seconds + delta)
    }

    private func apply(_ candidate: Int, animated: Bool = false) {
        let clamped = min(range.upperBound, max(range.lowerBound, candidate))
        let normalized = range.lowerBound
            + ((clamped - range.lowerBound) / max(1, step)) * max(1, step)
        let nextValue = min(range.upperBound, normalized)

        guard nextValue != seconds else { return }

        if animated && !reduceMotion {
            withAnimation(.snappy) {
                seconds = nextValue
            }
        } else {
            seconds = nextValue
        }
    }

    private func clamp() {
        guard seconds < range.lowerBound || seconds > range.upperBound else { return }
        seconds = min(range.upperBound, max(range.lowerBound, seconds))
    }

    private func synchronizeDurationState() {
        clamp()
        #if os(macOS)
        if focusedMacComponent != .minutes {
            minuteText = String(minutes)
        }
        if focusedMacComponent != .seconds {
            secondText = String(format: "%02d", remainder)
        }
        #endif
    }
}
