import SwiftUI
import TimeMasterCore

struct PageWidgetFolderTile: View {
    let folder: PageWidgetFolder
    let onOpen: (PageWidgetTarget) -> Void

    static let chipLimit = 3

    var body: some View {
        PageWidgetTile(kind: .folder, target: .children, summary: summary, tint: .peach, onOpen: onOpen) {
            if folder.pageCount == 0 {
                PageWidgetEmptyState(systemImage: "plus.circle", title: "Nothing here yet")
            } else if folder.covers.isEmpty {
                face(overPicture: false)
            } else {
                ZStack(alignment: .bottomLeading) {
                    covers
                    face(overPicture: true)
                        .environment(\.widgetTint, .graphite)
                }
            }
        }
    }

    private func face(overPicture: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHero(text: "\(folder.pageCount)", size: 36)
                .shadow(color: overPicture ? .black.opacity(0.45) : .clear, radius: 3, y: 1)
            HStack(spacing: 6) {
                ForEach(Array(chips.prefix(Self.chipLimit))) { chip in
                    WidgetChip(systemImage: chip.id, text: "\(chip.count)", overPicture: overPicture)
                }
            }
        }
        .padding(PageWidgetMetrics.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Chip: Identifiable {
        let id: String
        let count: Int
    }

    private var chips: [Chip] {
        [
            Chip(id: "figure.run", count: folder.exercises),
            Chip(id: "flag.checkered", count: folder.skills),
            Chip(id: "play.rectangle.fill", count: folder.clips),
            Chip(id: "folder.fill", count: folder.folders),
            Chip(id: "note.text", count: folder.notes),
        ]
        .filter { $0.count > 0 }
    }

    private var covers: some View {
        HStack(spacing: 2) {
            ForEach(folder.covers, id: \.self) { url in
                PageWidgetPoster(url: url, maxPixel: 320)
            }
        }
        .overlay {
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var summary: String {
        guard folder.pageCount > 0 else { return "In this folder: nothing yet" }
        var parts = [
            SkillCopy.count(folder.exercises, "exercise", "exercises"),
            SkillCopy.count(folder.skills, "skill", "skills"),
            SkillCopy.count(folder.clips, "clip", "clips"),
        ]
        if let extras = folder.extras { parts.append(extras.replacingOccurrences(of: " · ", with: ", ")) }
        return "In this folder: " + parts.joined(separator: ", ")
    }
}
