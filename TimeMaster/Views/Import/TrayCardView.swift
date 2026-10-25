import SwiftUI
import UniformTypeIdentifiers

struct TrayCardView: View {
    let item: TrayItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    let onMerge: (UUID) -> Void
    let onPreview: ((TrayMedia) -> Void)?
    var selectedIDs: Set<UUID> = []
    var onToggleSelection: (() -> Void)?
    var onGroupSelection: (() -> Void)?
    var onUngroup: (() -> Void)?

    @State private var isDropTargeted = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack {
                ForEach(Array(item.mediaList.dropFirst().prefix(2).enumerated()), id: \.offset) { index, media in
                    thumbnail(media)
                        .frame(width: CGFloat(88 - index * 6), height: 94)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .offset(y: -CGFloat(index + 1) * 4)
                }
                if let first = item.mediaList.first {
                    thumbnail(first)
                        .frame(width: 94, height: 94)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Theme.toolbarOrange.opacity(0.82))
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 94, height: 94)
            .padding(.top, item.mediaList.count > 1 ? 8 : 0)
            .overlay(alignment: .bottomLeading) {
                Label("\(item.mediaList.count)", systemImage: item.mediaList.count > 1 ? "square.stack.3d.up.fill" : item.mediaList.first?.isClip == true ? "film.fill" : "photo.fill")
                    .font(TimeMasterFont.micro())
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 5))
                    .padding(5)
            }
            .overlay(alignment: .topTrailing) {
                if let onToggleSelection {
                    Button(action: onToggleSelection) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? Theme.toolbarOrange : Color.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSelected ? "Deselect media" : "Select media")
                    .padding(3)
                }
            }
            Text(cardLabel)
                .font(TimeMasterFont.micro().monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 94, alignment: .leading)
        }
        .padding(6)
        .background(isHovered ? Theme.surface2 : Theme.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDropTargeted || isSelected ? Theme.toolbarOrange : Theme.separator, lineWidth: isDropTargeted ? 2 : 1)
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .onDrag {
            let ids = selectedIDs.contains(item.id) ? selectedIDs : [item.id]
            return NSItemProvider(object: ids.map(\.uuidString).sorted().joined(separator: ",") as NSString)
        }
        .onDrop(of: [UTType.plainText], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let string = object as? String else { return }
                let ids = string.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
                Task { @MainActor in
                    for id in ids where id != item.id { onMerge(id) }
                }
            }
            return true
        }
        .contextMenu {
            if let first = item.mediaList.first, let onPreview {
                Button(first.isClip ? "Preview clip" : "Preview still", systemImage: "eye") { onPreview(first) }
            }
            if let onToggleSelection {
                Button(isSelected ? "Deselect" : "Select", systemImage: "checkmark.circle", action: onToggleSelection)
            }
            if let onGroupSelection {
                Button("Stack selected here", systemImage: "square.stack.3d.up", action: onGroupSelection)
            }
            if item.mediaList.count > 1, let onUngroup {
                Button("Separate stack", systemImage: "square.stack.3d.up.slash", action: onUngroup)
            }
            Button("Remove", systemImage: "trash", role: .destructive, action: onRemove)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.mediaList.count) media, \(cardLabel)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: Text("Select"), onToggleSelection ?? onSelect)
        .accessibilityAction(named: Text("Remove"), onRemove)
    }

    private var cardLabel: String {
        if !item.name.isEmpty { return item.name }
        if item.mediaList.count > 1 { return "\(item.mediaList.count) media" }
        guard let first = item.mediaList.first, let start = first.startTime, let end = first.endTime else { return "Still" }
        let seconds = max(0, end - start)
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }

    @ViewBuilder
    private func thumbnail(_ media: TrayMedia) -> some View {
        #if os(iOS)
        Image(uiImage: media.thumbnail).resizable().scaledToFill()
        #else
        Image(nsImage: media.thumbnail).resizable().scaledToFill()
        #endif
    }
}
