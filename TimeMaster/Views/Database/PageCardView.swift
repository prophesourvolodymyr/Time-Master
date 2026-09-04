import SwiftUI
import UniformTypeIdentifiers

struct PageCardView: View {
    let page: ExercisePage
    var isGridMode: Bool = false
    var onAddToWorkout: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onAddChild: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onMoveIntoContainer: ((String) -> Void)? = nil
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if isGridMode {
                gridCard
            } else {
                listRow
            }
        }
        .onDrag {
            NSItemProvider(object: page.manifest.id as NSString)
        }
        .onDrop(of: [UTType.plainText], isTargeted: $isDropTargeted) { providers in
            guard page.isContainer, let onMoveIntoContainer else { return false }
            providers.first?.loadObject(ofClass: NSString.self) { object, _ in
                guard let id = object as? String, id != page.manifest.id else { return }
                DispatchQueue.main.async { onMoveIntoContainer(id) }
            }
            return true
        }
        .overlay {
            RoundedRectangle(cornerRadius: isGridMode ? 14 : 10)
                .stroke(isDropTargeted ? Theme.primary : Color.clear, lineWidth: 2)
        }
    }

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverHeroGrid
            infoGrid
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu { contextMenuContent }
    }

    private var listRow: some View {
        HStack(spacing: 12) {
            coverArea
            infoArea
            Spacer(minLength: 4)
            chevron
        }
        .padding(.vertical, 4)
        .contextMenu { contextMenuContent }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if page.isLeaf, let onAddToWorkout {
            Button { onAddToWorkout() } label: {
                Label("Add to Workout", systemImage: "figure.strengthtraining.traditional")
            }
        }
        if let onEdit {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        if page.isContainer, let onAddChild {
            Button { onAddChild() } label: {
                Label("Add Child Page", systemImage: "doc.badge.plus")
            }
        }
        if let onDuplicate {
            Button { onDuplicate() } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
        }
        if let onDelete {
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var coverHeroGrid: some View {
        ZStack(alignment: .bottomLeading) {
            if let coverURL = page.coverImageURL {
                coverImageGrid(url: coverURL)
            } else if let type = page.effectiveWorkoutType {
                gradientCoverGrid(color: Color(hex: type.colorHex))
            } else {
                gradientCoverGrid(color: nil)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if page.isContainer {
                        HStack(spacing: 2) {
                            Image(systemName: "rectangle.stack")
                                .font(.system(size: 7))
                            Text("\(page.totalChildCount)")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 3))
                    }
                    if let type = page.effectiveWorkoutType {
                        Text(type.name)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(hex: type.colorHex))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: type.colorHex).opacity(0.3), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
            .padding(8)
        }
        .frame(height: 120)
        .clipped()
    }

    private func coverImageGrid(url: URL) -> some View {
        AsyncCoverImage(url: url, height: 120, contentMode: .fill, overlayGradient: false)
            .frame(height: 120)
    }

    private func gradientCoverGrid(color: Color?) -> some View {
        Group {
            if let color {
                LinearGradient(
                    colors: [color.opacity(0.2), color.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var infoGrid: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(page.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)

            HStack(spacing: 5) {
                if page.isContainer {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 7))
                    Text("\(page.totalChildCount)")
                }
                if page.hasWorkoutConfig {
                    Text("\(page.manifest.duration ?? 0)s")
                }
                if page.hasMedia {
                    Text("\(page.mediaURLs.count) media")
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(Theme.textSecondary.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var coverArea: some View {
        if let coverURL = page.coverImageURL {
            AsyncCoverImage(url: coverURL, height: 48, overlayGradient: false)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            gradientFallback
        }
    }

    private var gradientFallback: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 48, height: 48)
    }

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(page.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            HStack(spacing: 6) {
                if page.isContainer {
                    childCountBadge
                }
                if let type = page.effectiveWorkoutType {
                    workoutTypeTag(name: type.name, iconName: type.iconName, colorHex: type.colorHex)
                }
                if page.hasMedia {
                    Text("\(page.mediaURLs.count) media")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                }
                if page.isLeaf && page.effectiveWorkoutType == nil {
                    Text("Exercise")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                }
            }
        }
    }

    private var childCountBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 8))
            Text("\(page.totalChildCount)")
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(Theme.textSecondary.opacity(0.7))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
    }

    private func workoutTypeTag(name: String, iconName: String, colorHex: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 8))
            Text(name)
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(Color(hex: colorHex))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(hex: colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary.opacity(0.4))
    }
}
