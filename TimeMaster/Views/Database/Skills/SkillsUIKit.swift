import SwiftUI
import TimeMasterCore

// MARK: - Errors

/// Where the skill screens report a failed write. One alert per screen (`skillErrorAlert()`); the message is the
/// failure in plain words.
@MainActor
final class SkillErrorCenter: ObservableObject {
    static let shared = SkillErrorCenter()
    @Published var message: String?

    func report(_ title: String, _ error: Error) {
        message = "\(title): \(error.localizedDescription)"
    }

    /// Runs a throwing write and reports its failure. Returns whether it succeeded.
    @discardableResult
    func attempt(_ title: String, _ body: () throws -> Void) -> Bool {
        do {
            try body()
            return true
        } catch {
            report(title, error)
            return false
        }
    }
}

private struct SkillErrorAlert: ViewModifier {
    @ObservedObject private var center = SkillErrorCenter.shared

    func body(content: Content) -> some View {
        content.alert(
            "Couldn’t save",
            isPresented: Binding(get: { center.message != nil }, set: { if !$0 { center.message = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(center.message ?? "")
        }
    }
}

extension View {
    func skillErrorAlert() -> some View { modifier(SkillErrorAlert()) }
}

// MARK: - Icons

/// An SF Symbol or an emoji at one size.
struct SkillIconView: View {
    let iconName: String
    let iconType: SkillBoardIconType?
    var colorHex: String?
    var size: CGFloat = 16

    var body: some View {
        if iconType == .system {
            Image(systemName: iconName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(colorHex.map { Color(hex: $0) } ?? Theme.toolbarOrange)
        } else {
            Text(iconName)
                .font(.system(size: size))
        }
    }
}

/// What to draw for a page's icon, by priority: its own picture, its own symbol or emoji, the art generated for its
/// title, one picked from its title, nothing.
enum SkillIconResolution: Equatable {
    case picture(URL)
    case glyph(name: String, type: SkillBoardIconType, isAutomatic: Bool)
    case art(String)
    case none

    static func resolve(for page: ExercisePage, style: SkillAutoIcon.Style) -> SkillIconResolution {
        if let url = page.iconImageURL { return .picture(url) }
        if let name = page.manifest.iconName, !name.isEmpty {
            return .glyph(name: name, type: page.manifest.iconType ?? .emoji, isAutomatic: false)
        }
        if let art = SkillArt.assetName(for: page) { return .art(art) }
        if let pick = SkillAutoIcon.pick(forTitle: page.title, style: style) {
            return .glyph(name: pick.name, type: pick.type, isAutomatic: true)
        }
        return .none
    }
}

/// The icon of a skill page: the picture clipped to a rounded tile, or the glyph on a transparent background (no
/// fill, so an emoji sits straight on the card). Automatic icons are a little dimmer than chosen ones. With
/// `tilesSymbols` an SF Symbol (and the sparkles of a page without an icon) sits on a debossed tile, as on the board's
/// rows and cards.
struct SkillPageIconTile: View {
    let page: ExercisePage
    var size: CGFloat = 36
    var tilesSymbols = false
    @AppStorage(SkillSettings.autoIconStyleKey) private var autoStyleRaw = SkillAutoIcon.Style.emoji.rawValue

    private var style: SkillAutoIcon.Style { SkillAutoIcon.Style(rawValue: autoStyleRaw) ?? .emoji }

    var body: some View {
        switch SkillIconResolution.resolve(for: page, style: style) {
        case .picture(let url):
            Group {
                if url.isFileURL {
                    SkillLocalImage(url: url, maxPixel: Int(size * 3))
                } else {
                    RemoteImage(url: url, maxPixelSize: size * 3) {
                        Color.clear
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        case .art(let name):
            Image(name)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        case .glyph(let name, let type, let isAutomatic):
            if tilesSymbols && type == .system {
                SkillIconView(iconName: name, iconType: type, size: size * 0.48)
                    .opacity(isAutomatic ? 0.8 : 1)
                    .frame(width: size, height: size)
                    .skillTile(cornerRadius: size * 0.32)
            } else {
                SkillIconView(iconName: name, iconType: type, size: size * 0.64)
                    .opacity(isAutomatic ? 0.8 : 1)
                    .frame(width: size, height: size)
            }
        case .none:
            if tilesSymbols {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: size, height: size)
                    .skillTile(cornerRadius: size * 0.32)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Shared bits

/// Short, warm labels for the page list.
enum SkillCopy {
    static func count(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? "1 \(one)" : "\(n) \(many)" }
}
