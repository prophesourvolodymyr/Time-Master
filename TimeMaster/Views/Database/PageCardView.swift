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
        .overlay(
            RoundedRectangle(cornerRadius: isGridMode ? 14 : 10)
                .stroke(isDropTargeted ? Color.white.opacity(0.9) : Color.clear, lineWidth: 2)
        )
    }

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverHeroGrid
            infoGrid
        }
        .background(Theme.surface)
        .cornerRadius(14)
        .clipped()
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
        if page.isLeaf, let onAddToWorkout = onAddToWorkout {
            Button { onAddToWorkout() } label: {
                Label("Add to Workout", systemImage: "figure.strengthtraining.traditional")
            }
        }
        if let onEdit = onEdit {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        if page.isContainer, let onAddChild = onAddChild {
            Button { onAddChild() } label: {
                Label("Add Child Page", systemImage: "doc.badge.plus")
            }
        }
        if let onDuplicate = onDuplicate {
            Button { onDuplicate() } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
        }
        if let onDelete = onDelete {
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
            } else if let iconName = page.manifest.iconName {
                iconCoverGrid(iconName: iconName)
            } else if page.isContainer {
                gradientCoverGrid(iconName: "folder.fill", color: nil)
            } else if let wt = page.effectiveWorkoutType {
                gradientCoverGrid(iconName: wt.iconName, color: Color(hex: wt.colorHex))
            } else {
                gradientCoverGrid(iconName: "doc.text.fill", color: nil)
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
                            Image(systemName: "rectangle.stack").font(.system(size: 7))
                            Text("\(page.totalChildCount)").font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(3)
                    }
                    if let wt = page.effectiveWorkoutType {
                        Text(wt.name)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: wt.colorHex))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color(hex: wt.colorHex).opacity(0.3))
                            .cornerRadius(3)
                    }
                }
            }
            .padding(8)
        }
        .frame(height: 120)
    }

    private func coverImageGrid(url: URL) -> some View {
        AsyncCoverImage(url: url, height: 120, contentMode: .fill, overlayGradient: false)
            .frame(height: 120)
    }

    private func iconCoverGrid(iconName: String) -> some View {
        let color = page.effectiveWorkoutType?.colorHex ?? "FFFFFF"
        return AnyView(
            ZStack {
                Color(hex: color).opacity(0.25)
                Image(systemName: iconName)
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: color).opacity(0.5))
            }
        )
    }

    private func gradientCoverGrid(iconName: String, color: Color?) -> some View {
        if let color = color {
            return AnyView(
                ZStack {
                    Color.clear.background(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    Image(systemName: iconName)
                        .font(.system(size: 32))
                        .foregroundColor(color.opacity(0.4))
                }
            )
        }
        return AnyView(
            ZStack {
                Color.clear.background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                Image(systemName: iconName)
                    .font(.system(size: 32))
                    .foregroundColor(Theme.textSecondary.opacity(0.3))
            }
        )
    }

    private var infoGrid: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(page.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)

            HStack(spacing: 4) {
                if page.isContainer {
                    Image(systemName: "rectangle.stack").font(.system(size: 7))
                    Text("\(page.totalChildCount)")
                }
                if page.hasWorkoutConfig {
                    Text("\(page.manifest.duration ?? 0)s")
                }
            }
            .font(.system(size: 9))
            .foregroundColor(Theme.textSecondary.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var coverArea: some View {
        if let coverURL = page.coverImageURL {
            coverImage(url: coverURL)
        } else if let iconName = page.manifest.iconName {
            iconFallback(iconName: iconName)
        } else {
            gradientFallback
        }
    }

    private func coverImage(url: URL) -> some View {
        AsyncCoverImage(url: url, height: 48, overlayGradient: false)
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func iconFallback(iconName: String) -> some View {
        let color = page.effectiveWorkoutType?.colorHex ?? "FFFFFF"
        return AnyView(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: color).opacity(0.25))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: color))
                )
        )
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
            .overlay(
                Image(systemName: page.isContainer ? "folder.fill" : "doc.text.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
            )
    }

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(page.title)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            HStack(spacing: 6) {
                if page.isContainer {
                    childCountBadge
                }
                if let wt = page.effectiveWorkoutType {
                    workoutTypeTag(name: wt.name, iconName: wt.iconName, colorHex: wt.colorHex)
                }
                if page.isLeaf && page.effectiveWorkoutType == nil && !page.isContainer {
                    Text("Page")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
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
        .foregroundColor(Theme.textSecondary.opacity(0.7))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.06))
        .cornerRadius(4)
    }

    private func workoutTypeTag(name: String, iconName: String, colorHex: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 8))
            Text(name)
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundColor(Color(hex: colorHex))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(hex: colorHex).opacity(0.12))
        .cornerRadius(4)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundColor(Theme.textSecondary.opacity(0.4))
    }
}
