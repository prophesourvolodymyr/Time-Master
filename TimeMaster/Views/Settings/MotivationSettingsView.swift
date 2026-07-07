import SwiftUI

struct MotivationSettingsView: View {

    // MARK: - State

    @State private var isEnabled: Bool = MotivationManager.shared.isEnabled
    @State private var interval: Int    = MotivationManager.shared.interval
    @State private var quotes: [String] = MotivationManager.shared.quotes
    @State private var newQuoteText     = ""
    @State private var showingAddQuote  = false
    @FocusState private var addFieldFocused: Bool

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            List {
                enableSection
                intervalSection
                quotesSection
            }
            #if os(iOS)
            #if os(iOS)
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            #endif
            #endif
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Motivational Quotes")
        #if os(iOS)
        #if os(iOS)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #endif
        #endif
    }

    // MARK: - Sections

    private var enableSection: some View {
        SwiftUI.Section {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Speak quotes during workout")
                        .foregroundColor(.white)
                    Text("Random quotes are spoken while a section timer runs")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .tint(.white)
            .onChange(of: isEnabled) { val in
                MotivationManager.shared.isEnabled = val
            }
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.separator)
    }

    private var intervalSection: some View {
        SwiftUI.Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Minimum interval")
                        .foregroundColor(.white)
                    Text("Quotes won't repeat more often than this")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Text("\(interval)s")
                    .foregroundColor(Theme.textSecondary)
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(interval) },
                    set: { interval = Int($0) }
                ),
                in: 30...120,
                step: 5
            )
            .tint(.white)
            .onChange(of: interval) { val in
                MotivationManager.shared.interval = val
            }
        } header: {
            Text("Frequency")
                .foregroundColor(Theme.textSecondary)
                .font(.caption)
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.separator)
    }

    private var quotesSection: some View {
        SwiftUI.Section {
            // Add new quote row
            if showingAddQuote {
                HStack(spacing: 10) {
                    TextField("New quote…", text: $newQuoteText)
                        .foregroundColor(.white)
                        .focused($addFieldFocused)
                    Button("Add") {
                        commitNewQuote()
                    }
                    .foregroundColor(.white)
                    .disabled(newQuoteText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            ForEach(quotes, id: \.self) { quote in
                Text(quote)
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            .onDelete { indexSet in
                quotes.remove(atOffsets: indexSet)
                MotivationManager.shared.quotes = quotes
            }
        } header: {
            HStack {
                Text("Quotes pool (\(quotes.count))")
                    .foregroundColor(Theme.textSecondary)
                    .font(.caption)
                Spacer()
                // Add / Reset buttons
                Button {
                    if showingAddQuote {
                        commitNewQuote()
                    } else {
                        showingAddQuote = true
                        addFieldFocused = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                Button {
                    resetToDefaults()
                } label: {
                    Text("Reset")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.leading, 8)
            }
        }
        .listRowBackground(Theme.surface)
        .listRowSeparatorTint(Theme.separator)
    }

    // MARK: - Helpers

    private func commitNewQuote() {
        let trimmed = newQuoteText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showingAddQuote = false
            return
        }
        quotes.append(trimmed)
        MotivationManager.shared.quotes = quotes
        newQuoteText = ""
        showingAddQuote = false
    }

    private func resetToDefaults() {
        quotes = MotivationManager.defaultQuotes
        MotivationManager.shared.quotes = quotes
    }
}

#Preview {
    NavigationStack {
        MotivationSettingsView()
    }
    .preferredColorScheme(.dark)
}
