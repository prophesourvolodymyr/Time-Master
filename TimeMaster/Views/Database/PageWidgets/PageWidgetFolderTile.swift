import SwiftUI

/// In this folder: what a folder holds all the way down (exercises, skills, clips, and its folders and notes when it has
/// any), under the covers of its first pages. An empty folder says so. A tap opens its pages.
struct PageWidgetFolderTile: View {
    let folder: PageWidgetFolder
    let onOpen: (PageWidgetTarget) -> Void

    var body: some View {
        PageWidgetTile(kind: .folder, target: .children, summary: summary, onOpen: onOpen) {
            ZStack(alignment: .topLeading) {
                if !folder.covers.isEmpty {
                    covers
                }
                VStack(alignment: .leading, spacing: 4) {
                    PageWidgetHeader(
                        kind: .folder,
                        trailing: folder.pageCount > 0 ? "\(folder.pageCount)" : nil,
                        overPicture: !folder.covers.isEmpty
                    )
                    if folder.pageCount == 0 {
                        PageWidgetEmptyState(systemImage: "plus.circle", title: "Nothing here yet")
                    } else {
                        Spacer(minLength: 0)
                        HStack(alignment: .bottom, spacing: 8) {
                            stat(folder.exercises, one: "Exercise", many: "Exercises")
                            stat(folder.skills, one: "Skill", many: "Skills")
                            stat(folder.clips, one: "Clip", many: "Clips")
                        }
                        if let extras = folder.extras {
                            Text(extras)
                                .font(TimeMasterFont.micro())
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
                .padding(PageWidgetMetrics.inset)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// The covers of the folder's first pages side by side across the top, fading into the tile.
    private var covers: some View {
        HStack(spacing: 2) {
            ForEach(folder.covers, id: \.self) { url in
                PageWidgetPoster(url: url, maxPixel: 320)
            }
        }
        .frame(height: 78)
        .overlay {
            LinearGradient(colors: [.black.opacity(0.5), .black.opacity(0.1)], startPoint: .top, endPoint: .bottom)
        }
        .mask {
            LinearGradient(colors: [.black, .black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
        }
    }

    private func stat(_ value: Int, one: String, many: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)")
                .font(TimeMasterFont.black(22, relativeTo: .title3).monospacedDigit())
                .foregroundStyle(value == 0 ? Theme.textSecondary : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(value == 1 ? one : many)
                .font(TimeMasterFont.micro())
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
