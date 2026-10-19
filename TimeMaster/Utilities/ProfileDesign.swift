import SwiftUI
import CoreText

enum ProfileStyle {
    static let inset: CGFloat = 16
    static let spacing: CGFloat = 12
    static let corner: CGFloat = 20
    static let touchTarget: CGFloat = 44
    static let readableWidth: CGFloat = 640
    static let secondary = Color(white: 0.65)
}

enum TimeMasterFont {
    private static let registration: Void = {
        for name in ["Inter-Regular", "Inter-Black"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()

    private static func face(_ name: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        _ = registration
        return .custom(name, size: size, relativeTo: style)
    }

    static func title() -> Font { face("Inter-Black", size: 24, relativeTo: .title2) }
    static func heading() -> Font { face("Inter-Black", size: 20, relativeTo: .title3) }
    static func rowTitle() -> Font { face("Inter-Black", size: 15, relativeTo: .subheadline) }
    static func label() -> Font { face("Inter-Black", size: 16, relativeTo: .body) }
    static func body() -> Font { face("Inter-Regular", size: 16, relativeTo: .body) }
    static func secondary() -> Font { face("Inter-Regular", size: 14, relativeTo: .subheadline) }
    static func caption() -> Font { face("Inter-Regular", size: 12, relativeTo: .caption) }
}

struct ProfilePillLabel: View {
    let title: String
    let symbol: String
    let isSelected: Bool

    var body: some View {
        Label(title, systemImage: symbol)
            .font(TimeMasterFont.rowTitle())
            .padding(.horizontal, ProfileStyle.inset)
            .padding(.vertical, ProfileStyle.spacing)
            .foregroundStyle(isSelected ? .black : ProfileStyle.secondary)
            .background(isSelected ? .white : Theme.surface2, in: Capsule())
            .frame(minHeight: ProfileStyle.touchTarget)
    }
}

struct ProfilePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TimeMasterFont.label())
            .padding(.horizontal, ProfileStyle.inset)
            .frame(minHeight: 50)
            .foregroundStyle(.black)
            .background(.white, in: Capsule())
            .opacity(!isEnabled ? 0.35 : configuration.isPressed ? 0.75 : 1)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ProfileAvatar: View {
    let profile: LocalUserProfile
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let filename = profile.avatarFilename, let image = PhotoManager.shared.loadPhoto(filename: filename) {
                platformImage(image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .resizable().scaledToFit().padding(size * 0.24)
                    .foregroundStyle(ProfileStyle.secondary)
                    .background(Theme.surface2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("\(profile.displayName)'s avatar")
    }
}

func platformImage(_ image: PhotoPlatformImage) -> Image {
#if os(iOS)
    Image(uiImage: image)
#else
    Image(nsImage: image)
#endif
}

struct ProfileSettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { content }
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(ProfileStyle.inset)
        }
        .font(TimeMasterFont.body())
        .foregroundStyle(.white)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(title)
    }
}

struct ProfileSettingsSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Text(title.uppercased())
                .font(TimeMasterFont.caption())
                .foregroundStyle(ProfileStyle.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) { content }
                .modifier(TimeMasterCardSurface(flat: true))
            if let footer {
                Text(footer).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
            }
        }
    }
}

struct ProfileSettingsRow: View {
    let icon: String
    let title: String
    var detail: String? = nil
    var showsChevron = true

    var body: some View {
        HStack(spacing: ProfileStyle.spacing) {
            Image(systemName: icon).font(.body.weight(.medium))
                .frame(width: ProfileStyle.touchTarget)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(TimeMasterFont.rowTitle()).foregroundStyle(.white)
                if let detail {
                    Text(detail).font(TimeMasterFont.caption()).foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            if showsChevron {
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(ProfileStyle.secondary).accessibilityHidden(true)
            }
        }
        .padding(ProfileStyle.spacing)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

struct ProfileEmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            Image(systemName: symbol).font(.title).foregroundStyle(ProfileStyle.secondary).accessibilityHidden(true)
            Text(title).font(TimeMasterFont.heading())
            Text(detail).font(TimeMasterFont.secondary()).foregroundStyle(ProfileStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ProfileStyle.inset)
        .modifier(TimeMasterCardSurface(flat: true))
    }
}

extension View {
    func profileErrorAlert(_ message: Binding<String?>) -> some View {
        alert("Couldn't save", isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
