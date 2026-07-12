import SwiftUI

struct PageCardView: View {
    let page: ExercisePage

    var body: some View {
        HStack(spacing: 12) {
            coverArea
            infoArea
            Spacer(minLength: 4)
            chevron
        }
        .padding(.vertical, 4)
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
        #if os(iOS)
        if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
            return AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            )
        }
        #elseif os(macOS)
        if let data = try? Data(contentsOf: url), let nsImage = NSImage(data: data) {
            return AnyView(
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            )
        }
        #endif
        return AnyView(gradientFallback)
    }

    private func iconFallback(iconName: String) -> some View {
        let color = page.manifest.workoutType?.colorHex ?? "FFFFFF"
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
                if let wt = page.manifest.workoutType {
                    workoutTypeTag(name: wt.name, iconName: wt.iconName, colorHex: wt.colorHex)
                }
                if page.isLeaf && page.manifest.workoutType == nil && !page.isContainer {
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
