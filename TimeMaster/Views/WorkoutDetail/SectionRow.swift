import SwiftUI

struct SectionRow: View {
    let section: Section
    /// Called when the user taps the thumbnail. Only fired when the section has media.
    var onThumbnailTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            mediaThumbnail
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(section.name)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    if section.sets > 1 {
                        Text("\(section.sets)×")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(5)
                    }
                }
                HStack(spacing: 10) {
                    Label("\(section.duration)s", systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "line.3.horizontal")
                .font(.title3)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var mediaThumbnail: some View {
        if let item = section.mediaItems.first, let tap = onThumbnailTap {
            Button { tap() } label: {
                MediaThumbnailView(item: item, size: 60, cornerRadius: 12)
            }
            .buttonStyle(.plain)
        } else if let item = section.mediaItems.first {
            MediaThumbnailView(item: item, size: 60, cornerRadius: 12)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surface2)
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: 60, height: 60)
        }
    }
}

#Preview {
    SectionRow(section: Section(name: "Burpees", duration: 45, sets: 3))
        .padding()
        .background(Theme.surface)
        .preferredColorScheme(.dark)
}
