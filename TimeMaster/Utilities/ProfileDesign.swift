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
    static func display() -> Font { face("Inter-Black", size: 28, relativeTo: .largeTitle) }
    static func sectionTitle() -> Font { face("Inter-Black", size: 17, relativeTo: .headline) }
    static func heading() -> Font { face("Inter-Black", size: 20, relativeTo: .title3) }
    static func rowTitle() -> Font { face("Inter-Black", size: 15, relativeTo: .subheadline) }
    static func label() -> Font { face("Inter-Black", size: 16, relativeTo: .body) }
    static func body() -> Font { face("Inter-Regular", size: 16, relativeTo: .body) }
    static func secondary() -> Font { face("Inter-Regular", size: 14, relativeTo: .subheadline) }
    static func caption() -> Font { face("Inter-Regular", size: 12, relativeTo: .caption) }
    static func micro() -> Font { face("Inter-Regular", size: 11, relativeTo: .caption2) }
    static func technical() -> Font { .system(size: 12, weight: .regular, design: .monospaced) }
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
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(StoreArtworkStyle.mono.ink)
                    .frame(width: size, height: size)
                    .background(StoreArtworkStyle.mono.color, in: Circle())
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
