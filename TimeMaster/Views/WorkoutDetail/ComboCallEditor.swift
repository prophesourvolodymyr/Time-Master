import SwiftUI
import TimeMasterCore

struct ComboCallTarget: Identifiable {
    let id = UUID()
    let setID: UUID
    let exerciseID: UUID?
    let tokens: [String]
}

struct ComboCallEditorSheet: View {
    let title: String
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tokens: [String]

    private let longestCall = 8

    init(title: String, tokens: [String], onSave: @escaping ([String]) -> Void) {
        self.title = title
        self.onSave = onSave
        _tokens = State(initialValue: tokens.isEmpty ? ComboCall.defaultCall : tokens)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                preview
                wheels
                positionButtons
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(tokens)
                        dismiss()
                    }
                }
            }
        }
        .font(TimeMasterFont.body())
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 540)
        #endif
    }

    private var preview: some View {
        VStack(spacing: 12) {
            ComboCallChip(tokens: tokens)
                .scaleEffect(1.25)
                .padding(.vertical, 6)
            Text(ComboCall.spoken(tokens).capitalized)
                .font(TimeMasterFont.black(20, relativeTo: .title3))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button {
                AudioManager.shared.speak(ComboCall.spoken(tokens))
            } label: {
                Label("Hear it", systemImage: "speaker.wave.2.fill")
                    .font(TimeMasterFont.black(15, relativeTo: .subheadline))
            }
            .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 40, tint: .white))
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(ComboStyle.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private var wheels: some View {
        ViewThatFits(in: .horizontal) {
            wheelRow
                .frame(maxWidth: .infinity)
            ScrollView(.horizontal, showsIndicators: false) {
                wheelRow
                    .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 8)
        .modifier(TimeMasterGlassSurface(cornerRadius: 26, isInteractive: false, tint: ComboStyle.deep, tintOpacity: 0.42))
    }

    private var wheelWidth: CGFloat {
        switch tokens.count {
        case ...3: 92
        case 4: 78
        case 5: 60
        case 6: 50
        default: 44
        }
    }

    private var wheelRow: some View {
        HStack(spacing: tokens.count > 6 ? 6 : 8) {
            ForEach(tokens.indices, id: \.self) { index in
                ComboWheel(
                    token: Binding(
                        get: { tokens.indices.contains(index) ? tokens[index] : ComboMoves.all[0].token },
                        set: { if tokens.indices.contains(index) { tokens[index] = $0 } }
                    ),
                    width: wheelWidth
                )
            }
        }
    }

    private var positionButtons: some View {
        HStack(spacing: 14) {
            Button {
                if tokens.count > 1 { tokens.removeLast() }
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(TimeMasterActionButtonStyle(circular: true, minimumSize: 48, tint: ComboStyle.deep))
            .disabled(tokens.count <= 1)
            .accessibilityLabel("Remove the last move")

            Text("\(tokens.count) \(tokens.count == 1 ? "move" : "moves")")
                .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textSecondary)
                .frame(minWidth: 80)

            Button {
                if tokens.count < longestCall { tokens.append(tokens.last ?? ComboMoves.all[0].token) }
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(TimeMasterActionButtonStyle(prominent: true, circular: true, minimumSize: 48, tint: ComboStyle.bright))
            .disabled(tokens.count >= longestCall)
            .accessibilityLabel("Add a move")
        }
    }
}

struct ComboWheel: View {
    @Binding var token: String
    var width: CGFloat = 92

    static let rowHeight: CGFloat = 60
    static let visibleRows: CGFloat = 3

    var body: some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            SnappingWheel(token: $token, width: width)
        } else {
            Picker("Move", selection: $token) {
                ForEach(ComboMoves.all) { move in
                    Label("\(move.token.capitalized) · \(move.title)", systemImage: move.symbol).tag(move.token)
                }
            }
            .pickerStyle(.menu)
            .frame(width: max(width, 72), height: Self.rowHeight * Self.visibleRows)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SnappingWheel: View {
    @Binding var token: String
    let width: CGFloat
    @State private var scrolled: String?

    private let height = ComboWheel.rowHeight * ComboWheel.visibleRows

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(ComboMoves.all) { move in
                    row(move)
                        .frame(height: ComboWheel.rowHeight)
                        .id(move.token)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) { scrolled = move.token }
                        }
                        .tmaxPointer()
                        .scrollTransition(axis: .vertical) { content, phase in
                            content
                                .opacity(1 - abs(phase.value) * 0.6)
                                .scaleEffect(1 - abs(phase.value) * 0.18)
                                .rotation3DEffect(.degrees(Double(phase.value) * -42), axis: (x: 1, y: 0, z: 0))
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolled, anchor: .center)
        .contentMargins(.vertical, (height - ComboWheel.rowHeight) / 2, for: .scrollContent)
        .frame(width: width, height: height)
        .background(alignment: .center) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.16))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                .frame(height: ComboWheel.rowHeight - 6)
                .allowsHitTesting(false)
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.22),
                    .init(color: .black, location: 0.78),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .onAppear { scrolled = token }
        .onChange(of: scrolled) { value in
            if let value, value != token { token = value }
        }
        .onChange(of: token) { value in
            if scrolled != value { scrolled = value }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Move")
        .accessibilityValue(ComboMoves.move(for: token)?.title ?? token)
        .accessibilityAdjustableAction { direction in
            guard let index = ComboMoves.all.firstIndex(where: { $0.token == token }) else { return }
            let next = direction == .increment ? index + 1 : index - 1
            if ComboMoves.all.indices.contains(next) { token = ComboMoves.all[next].token }
        }
    }

    private func row(_ move: ComboMove) -> some View {
        let narrow = width < 70
        return VStack(spacing: 1) {
            HStack(spacing: narrow ? 2 : 5) {
                Image(systemName: move.symbol)
                    .font(.system(size: narrow ? 12 : 15, weight: .bold))
                Text(move.token.count <= 1 ? move.token : move.token.capitalized)
                    .font(TimeMasterFont.black(move.token.count <= 1 ? (narrow ? 20 : 26) : (narrow ? 12 : 17), relativeTo: .title3))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            if !narrow {
                Text(move.title)
                    .font(TimeMasterFont.caption())
                    .opacity(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }
}

struct ComboIconPickerSheet: View {
    let iconName: String?
    let iconType: SkillBoardIconType?
    let onPick: (String?, SkillBoardIconType?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typedEmoji = ""

    private let symbols = [
        "figure.boxing", "figure.kickboxing", "figure.martial.arts", "flame.fill", "bolt.fill", "shield.fill",
        "hand.raised.fill", "target", "scope", "star.fill", "trophy.fill", "crown.fill", "heart.fill", "timer",
        "speedometer", "waveform", "mic.fill", "speaker.wave.3.fill", "metronome.fill", "figure.strengthtraining.traditional",
    ]
    private let emojis = ["🥊", "🔥", "⚡️", "💥", "🎯", "🥋", "🏆", "🛡️", "💪", "🦾", "😤", "👊"]

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    grid(title: "Symbols") {
                        ForEach(symbols, id: \.self) { name in
                            cell(selected: iconType == .system && iconName == name) {
                                Image(systemName: name).font(.system(size: 24, weight: .bold))
                            } action: { pick(name, .system) }
                        }
                    }
                    grid(title: "Emoji") {
                        ForEach(emojis, id: \.self) { emoji in
                            cell(selected: iconType == .emoji && iconName == emoji) {
                                Text(emoji).font(.system(size: 28))
                            } action: { pick(emoji, .emoji) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your own emoji")
                            .font(TimeMasterFont.black(13, relativeTo: .caption))
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 10) {
                            TextField("🥊", text: $typedEmoji)
                                .textFieldStyle(.plain)
                                .font(.system(size: 24))
                                .padding(12)
                                .frame(maxWidth: 120)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Button("Use it") {
                                if let first = typedEmoji.first { pick(String(first), .emoji) }
                            }
                            .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 44))
                            .disabled(typedEmoji.isEmpty)
                        }
                    }
                    Button {
                        pick(nil, nil)
                    } label: {
                        Label("Back to the boxer", systemImage: "arrow.counterclockwise")
                            .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TimeMasterActionButtonStyle(minimumSize: 48))
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle("Combo icon")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .font(TimeMasterFont.body())
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 520)
        #endif
    }

    private func grid<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(TimeMasterFont.black(13, relativeTo: .caption))
                .foregroundStyle(Theme.textSecondary)
            LazyVGrid(columns: columns, spacing: 12) { content() }
        }
    }

    private func cell<Glyph: View>(selected: Bool, @ViewBuilder glyph: () -> Glyph, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            glyph()
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(ComboStyle.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(selected ? 0.9 : 0.18), lineWidth: selected ? 2.5 : 1)
                )
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 18))
    }

    private func pick(_ name: String?, _ type: SkillBoardIconType?) {
        onPick(name, type)
        dismiss()
    }
}
