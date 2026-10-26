import SwiftUI

struct MenuBarCoachPage: View {
    @ObservedObject private var ai = AIStore.shared
    @Environment(\.menuBarActions) private var actions
    @State private var prompt = ""
    @FocusState private var focused: Bool

    private static let starters = [
        "Plan my training week",
        "I have 20 minutes today. What should I do?",
        "What should I train today?",
        "How do I keep my streak going?",
        "Build me a short stretch routine"
    ]

    private var isConfigured: Bool {
        ai.hasKey(for: ai.activeProviderID)
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerCard
                composer
                VStack(spacing: 8) {
                    MenuBarSectionTitle(title: "Try asking")
                    ForEach(Self.starters, id: \.self) { starter in
                        Button {
                            actions.openPage(.coach, starter)
                        } label: {
                            HStack {
                                Text(starter)
                                    .font(TimeMasterFont.rowTitle())
                                    .foregroundStyle(Theme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.toolbarOrange)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .modifier(TimeMasterCardSurface(cornerRadius: 14, flat: true))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(MenuBarRowButtonStyle())
                    }
                }
                MenuBarCompactButton(title: "Open Coach", symbol: "brain.head.profile", fillsWidth: true) {
                    actions.openPage(.coach, nil)
                }
            }
            .padding(14)
        }
        .scrollIndicators(.hidden)
    }

    private var headerCard: some View {
        MenuBarCard(emphasized: isConfigured, padding: 16) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.toolbarOrange)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Theme.toolbarOrange.opacity(0.16)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI Coach")
                        .font(TimeMasterFont.heading())
                        .foregroundStyle(Theme.textPrimary)
                    if isConfigured {
                        Text("\(ai.activeProvider.name) · \(ai.model)")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Add an API key in Coach settings to start chatting.")
                            .font(TimeMasterFont.caption())
                            .foregroundStyle(Theme.toolbarOrange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask your coach…", text: $prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .font(TimeMasterFont.body(15))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1...4)
                .focused($focused)
                .onChange(of: focused) { isFocused in
                    if isFocused { actions.requestKeyboard() }
                }
                .onSubmit(send)
                .padding(.vertical, 10)
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .buttonStyle(TimeMasterActionButtonStyle(prominent: true, circular: true, minimumSize: 36))
            .disabled(trimmedPrompt.isEmpty)
            .accessibilityLabel("Ask in Tmax")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(minHeight: 48)
        .modifier(TimeMasterCardSurface(cornerRadius: 18, flat: true))
    }

    private func send() {
        let text = trimmedPrompt
        guard !text.isEmpty else { return }
        prompt = ""
        actions.openPage(.coach, text)
    }
}
