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
                                    .font(TimeMasterFont.black(14, relativeTo: .subheadline))
                                    .foregroundStyle(Theme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.toolbarOrange)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .background(WidgetTint.graphite.base, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(WidgetTint.orange.ink)
                    .frame(width: 44, height: 44)
                    .background(Theme.toolbarOrange, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    WidgetTitle(text: "AI Coach", size: 20, lines: 1)
                    if isConfigured {
                        WidgetLabel(text: "\(ai.activeProvider.name) · \(ai.model)")
                    } else {
                        Text("Add an API key in Coach settings")
                            .font(WidgetFont.label())
                            .foregroundStyle(WidgetTint.peach.base)
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
                    .foregroundStyle(trimmedPrompt.isEmpty ? WidgetTint.graphite.secondaryInk : WidgetTint.orange.ink)
                    .frame(width: 36, height: 36)
                    .background(trimmedPrompt.isEmpty ? WidgetTint.graphite.softFill : Theme.toolbarOrange, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(SkillsPressStyle(cornerRadius: 18))
            .disabled(trimmedPrompt.isEmpty)
            .accessibilityLabel("Ask in Tmax")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(minHeight: 48)
        .background(WidgetTint.graphite.base, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(focused ? 0.24 : 0.08), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private func send() {
        let text = trimmedPrompt
        guard !text.isEmpty else { return }
        prompt = ""
        actions.openPage(.coach, text)
    }
}
