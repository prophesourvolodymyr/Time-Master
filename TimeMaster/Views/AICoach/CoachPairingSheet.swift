#if os(iOS)
import SwiftUI
import TimeMasterCore

struct CoachPairingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var engine = EverAgentCoachEngine.shared

    @State private var pasted = ""
    @State private var working = false
    @State private var message: String?
    @State private var scannerToken = UUID()
    @State private var scannerOff = false

    private let steps = [
        "On your Mac, open EverAhent and choose the container that Tmax's AI Settings names under “Connected to EverAgent”.",
        "Choose “Connect your iPhone”, then point this camera at the code, or use “Copy invitation link” and paste it below.",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Mac runs the coach with the models you signed in to in EverAhent. This iPhone only sends your questions, and no key or sign-in is copied to Tmax.")
                            .font(TimeMasterFont.body(14, relativeTo: .subheadline))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(TimeMasterFont.black(13, relativeTo: .footnote))
                                        .foregroundStyle(Theme.toolbarOrange)
                                        .frame(width: 18)
                                    Text(step)
                                        .font(TimeMasterFont.body(14, relativeTo: .subheadline))
                                        .foregroundStyle(Theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        scanner
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Or paste the invitation link")
                                .font(TimeMasterFont.black(13, relativeTo: .footnote))
                                .foregroundStyle(Theme.textSecondary)
                            TextField("ompp://pair?payload=…", text: $pasted, axis: .vertical)
                                .font(TimeMasterFont.body(13, relativeTo: .footnote))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .lineLimit(1...3)
                                .padding(10)
                                .modifier(TimeMasterCardSurface(cornerRadius: 12, flat: true))
                            Button("Pair with pasted link") { pair(pasted) }
                                .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                                .disabled(working || pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if let message {
                            Label(message, systemImage: "exclamationmark.triangle")
                                .font(TimeMasterFont.body(13, relativeTo: .footnote))
                                .foregroundStyle(Theme.toolbarOrange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("Both devices need to be on the same Wi-Fi. A code works once and expires after five minutes.")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Pair with EverAhent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var scanner: some View {
        if scannerOff {
            Button("Try the camera again") {
                scannerOff = false
                scannerToken = UUID()
            }
            .buttonStyle(TimeMasterActionButtonStyle())
        } else {
            ZStack {
                CoachQRScanner(
                    onCode: { code in pair(code) },
                    onFailure: { reason in
                        message = reason
                        scannerOff = true
                    }
                )
                .id(scannerToken)
                if working {
                    Color.black.opacity(0.55)
                    ProgressView("Pairing…")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityLabel("Camera for scanning the EverAhent pairing code")
        }
    }

    private func pair(_ text: String) {
        guard !working else { return }
        working = true
        message = nil
        Task {
            do {
                try await engine.pair(invitation: text)
                dismiss()
            } catch {
                message = EverAgentCoachEngine.explain(error)
                scannerToken = UUID()
            }
            working = false
        }
    }
}
#endif
