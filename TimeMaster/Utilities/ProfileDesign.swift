import SwiftUI
import CoreText
#if os(iOS)
import UIKit
#endif

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
        for name in ["Manrope-Regular", "Inter-Black", "Inter-BlackItalic", "TimeMaster-Regular"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()

    private static func face(_ name: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        _ = registration
        return .custom(name, size: size, relativeTo: style)
    }

    static func title() -> Font { black(24, relativeTo: .title2) }
    static func display() -> Font { black(28, relativeTo: .largeTitle) }
    static func pageTitle(_ size: CGFloat = 44, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        face("TimeMaster-Regular", size: size, relativeTo: style)
    }
    static func black(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        face("Inter-Black", size: size, relativeTo: style)
    }
    static func blackItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        face("Inter-BlackItalic", size: size, relativeTo: style)
    }
    static func sectionTitle() -> Font { black(17, relativeTo: .headline) }
    static func heading() -> Font { black(20, relativeTo: .title3) }
    static func rowTitle() -> Font { black(15, relativeTo: .subheadline) }
    static func label() -> Font { black(16, relativeTo: .body) }
    static func body(_ size: CGFloat = 16, relativeTo style: Font.TextStyle = .body) -> Font {
        face("Manrope-Regular", size: size, relativeTo: style)
    }
    static func secondary() -> Font { body(14, relativeTo: .subheadline) }
    static func caption() -> Font { body(12, relativeTo: .caption) }
    static func micro() -> Font { body(11, relativeTo: .caption2) }
    static func technical() -> Font { body(12, relativeTo: .caption).monospacedDigit() }

    #if os(iOS)
    static func uiBlack(_ size: CGFloat) -> UIFont {
        _ = registration
        return UIFont(descriptor: UIFontDescriptor(name: "Inter-Black", size: size), size: size)
    }
    #endif

    static func initialCapitalizedTitle(_ title: String) -> String {
        guard let first = title.firstIndex(where: \.isLetter), title[first].isLowercase else {
            return title
        }
        var result = title
        result.replaceSubrange(first...first, with: title[first].uppercased())
        return result
    }

    static func styledText(_ text: AttributedString, size: CGFloat = 16, relativeTo style: Font.TextStyle = .body) -> AttributedString {
        var result = text
        result.font = body(size, relativeTo: style)
        var strongFont: Font?
        var italicFont: Font?
        for run in text.runs {
            let intent = run.inlinePresentationIntent ?? []
            if intent.contains(.emphasized) {
                if italicFont == nil { italicFont = blackItalic(size, relativeTo: style) }
                result[run.range].font = italicFont
            } else if intent.contains(.stronglyEmphasized) {
                if strongFont == nil { strongFont = black(size, relativeTo: style) }
                result[run.range].font = strongFont
            } else {
                continue
            }
            result[run.range].inlinePresentationIntent = intent.subtracting([.emphasized, .stronglyEmphasized])
        }
        return result
    }

    private static let titleFallbackScale: CGFloat = {
        _ = registration
        let title = CTFontCreateWithName("TimeMaster-Regular" as CFString, 1, nil)
        let fallback = CTFontCreateWithName("Inter-Black" as CFString, 1, nil)
        return CTFontGetCapHeight(title) / CTFontGetCapHeight(fallback)
    }()

    static func pageTitleFallback(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        black(size * titleFallbackScale, relativeTo: style)
    }
}

struct TimeMasterPageTitle: View {
    private let title: String
    private let size: CGFloat
    private let style: Font.TextStyle

    init(_ title: String, size: CGFloat = 44, relativeTo style: Font.TextStyle = .largeTitle) {
        self.title = TimeMasterFont.initialCapitalizedTitle(title)
        self.size = size
        self.style = style
    }

    var body: some View {
        titleText
            .font(TimeMasterFont.pageTitle(size, relativeTo: style))
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }

    private static func supports(_ byte: UInt8) -> Bool {
        byte == 32 || (65...90).contains(byte) || (97...122).contains(byte)
    }

    private var titleText: Text {
        guard !title.utf8.allSatisfy(Self.supports) else { return Text(title) }
        var result = AttributedString(title)
        let characters = result.characters
        let fallback = TimeMasterFont.pageTitleFallback(size, relativeTo: style)
        var index = characters.startIndex
        while index < characters.endIndex {
            if let byte = characters[index].asciiValue, Self.supports(byte) {
                index = characters.index(after: index)
                continue
            }
            let start = index
            repeat {
                index = characters.index(after: index)
            } while index < characters.endIndex && !(characters[index].asciiValue.map(Self.supports) ?? false)
            result[start..<index].font = fallback
        }
        return Text(result)
    }
}

private struct TimeMasterNavigationTitle: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .everPageOpening()
            .preference(key: MacWindowTitlePreferenceKey.self, value: TimeMasterFont.initialCapitalizedTitle(title))
            .toolbarBackground(Theme.background, for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
        #else
        content
            .everPageOpening()
            .navigationTitle(TimeMasterFont.initialCapitalizedTitle(title))
            .toolbar {
                if !title.isEmpty {
                    ToolbarItem(placement: .principal) {
                        TimeMasterPageTitle(title, size: 26, relativeTo: .headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

extension View {
    func timeMasterNavigationTitle(_ title: String) -> some View {
        modifier(TimeMasterNavigationTitle(title: title))
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
        .timeMasterNavigationTitle(title)
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
