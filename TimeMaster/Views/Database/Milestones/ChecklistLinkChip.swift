import SwiftUI
import TimeMasterCore

/// A link on a to-do or a milestone: the target's picture or symbol and its name. A workout chip also starts the
/// workout; a target that is gone reads as missing in amber. The context menu removes the link.
struct ChecklistLinkChip: View {
    let link: TodoLink
    let target: ChecklistLinkTarget
    /// Titles of the page's own links, for web chips.
    var linkMetadata: [LinkMetadata] = []
    var comments: [String: String] = [:]
    let onOpen: () -> Void
    var onPlay: (() -> Void)?
    var onRemove: (() -> Void)?

    @ScaledMetric(relativeTo: .caption) private var thumb: CGFloat = 20

    static let missingColor = Color(hex: "FFB020")

    var body: some View {
        let color = target.isMissing ? Self.missingColor : Theme.toolbarOrange
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 6) {
                    leading
                    Text(label)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(target.isMissing ? Self.missingColor : Theme.textPrimary)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
                .padding(.trailing, onPlay == nil ? 10 : 6)
                .padding(.vertical, 4)
                .contentShape(Capsule())
            }
            .keyNavPlainButtonStyle(shape: .capsule)
            .disabled(target.isMissing)
            .accessibilityLabel(target.isMissing ? "\(label), no longer there" : "Open \(label)")
            if let onPlay, case .workout = target {
                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: thumb + 2, height: thumb + 2)
                        .background(Theme.toolbarOrange, in: Circle())
                        .padding(.trailing, 4)
                        .contentShape(Circle())
                }
                .keyNavPlainButtonStyle(shape: .circle)
                .help("Start \(label)")
                .accessibilityLabel("Start \(label)")
            }
        }
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
        .contextMenu {
            if let onRemove {
                Button(role: .destructive, action: onRemove) { Label("Remove link", systemImage: "link.badge.minus") }
            }
        }
    }

    @ViewBuilder
    private var leading: some View {
        switch target {
        case .workout(let workout):
            WorkoutCoverMosaic(workout: workout, size: thumb)
        case .page(let material):
            if let url = material.coverURL {
                SkillLocalImage(url: url, maxPixel: Int(thumb * 3))
                    .frame(width: thumb, height: thumb)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else if let page = material.page {
                SkillPageIconTile(page: page, size: thumb)
            } else {
                symbol("square.grid.2x2")
            }
        case .media(let filename, _):
            symbol(ChecklistLook.symbol(forFile: filename))
        case .web(let url):
            symbol(Self.webSymbol(url))
        case .missingWorkout, .missingPage, .missingMedia, .unreadable:
            symbol("exclamationmark.triangle.fill")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: thumb * 0.6, weight: .semibold))
            .foregroundStyle(target.isMissing ? Self.missingColor : Theme.toolbarOrange)
            .frame(width: thumb, height: thumb)
    }

    private var label: String {
        if let custom = link.label { return custom }
        switch target {
        case .workout(let workout): return workout.name
        case .page(let material): return material.title
        case .media(let filename, _):
            if let comment = comments[filename]?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty {
                return String(comment.split(whereSeparator: \.isNewline).first ?? "")
            }
            return ChecklistMedia.isPicture(filename) ? "Picture" : (ChecklistLook.symbol(forFile: filename) == "play.rectangle" ? "Video" : "File")
        case .web(let url):
            return linkMetadata.first { $0.url == link.url }?.title ?? url.host ?? url.absoluteString
        case .missingWorkout: return "Missing workout"
        case .missingPage: return "Missing page"
        case .missingMedia: return "Missing file"
        case .unreadable(let text): return text
        }
    }

    static func webSymbol(_ url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host.contains("youtube") || host.contains("youtu.be") || host.contains("vimeo") || host.contains("tiktok") { return "play.rectangle.fill" }
        if host.contains("instagram") { return "camera.fill" }
        return "globe"
    }
}
