import SwiftUI

struct SpotlightSearchBar<Accessory: View>: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    let placeholder: String
    @ViewBuilder let accessory: () -> Accessory

    @Namespace private var namespace
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 8) {
            if isPresented {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityHidden(true)
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($focused)
                        .onSubmit { focused = false }
                        .accessibilityLabel(placeholder)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                    if !text.isEmpty {
                        Button { text = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.textSecondary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .font(.body)
                .padding(.leading, 16)
                .padding(.trailing, text.isEmpty ? 16 : 2)
                .frame(minHeight: 48)
                .background { searchMaterial }
                .matchedGeometryEffect(id: "search", in: namespace, anchor: .trailing)
                .layoutPriority(1)
                .transition(.opacity)

                accessory()
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.65, anchor: .trailing).combined(with: .opacity))
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(SpotlightCircleButtonStyle())
                .accessibilityLabel("Close search")
                .keyboardShortcut(.cancelAction)
            } else {
                Button {
                    withAnimation(motion) { isPresented = true }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3.weight(.medium))
                        .frame(width: 48, height: 48)
                        .background { searchMaterial }
                }
                .buttonStyle(.plain)
                .matchedGeometryEffect(id: "search", in: namespace, anchor: .trailing)
                .accessibilityLabel(placeholder)
                .accessibilityHint("Open search and filters")
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: isPresented ? .infinity : nil, alignment: .trailing)
        .animation(motion, value: isPresented)
        .task(id: isPresented) {
            guard isPresented else { focused = false; return }
            await Task.yield()
            guard !Task.isCancelled, isPresented else { return }
            focused = true
        }
        .onDisappear { focused = false }
    }

    private var motion: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.84)
    }

    private var searchMaterial: some View {
        Capsule()
            .fill(reduceTransparency ? AnyShapeStyle(Theme.surface2) : AnyShapeStyle(.regularMaterial))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
    }

    private func close() {
        focused = false
        withAnimation(motion) {
            text = ""
            isPresented = false
        }
    }
}

struct SpotlightCircleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 48, height: 48)
            .background(reduceTransparency ? AnyShapeStyle(Theme.surface2) : AnyShapeStyle(.regularMaterial), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(reduceMotion ? .none : .spring(response: 0.24, dampingFraction: 0.85), value: configuration.isPressed)
    }
}
