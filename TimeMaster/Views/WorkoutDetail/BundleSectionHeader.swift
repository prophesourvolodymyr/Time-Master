import SwiftUI

struct BundleSectionHeader: View {
    let section: Section
    let isExpanded: Bool
    let onToggle: () -> Void
    let onAddSet: () -> Void
    let onEdit: () -> Void
    let onOpenPage: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2)
                Button(action: onToggle) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.name)
                            .font(TimeMasterFont.black(20, relativeTo: .title3))
                            .lineLimit(2)
                        Text("\(section.bundleSets.count) sets · \(section.calculatedDuration / 60):\(String(format: "%02d", section.calculatedDuration % 60))")
                            .font(TimeMasterFont.caption().monospacedDigit())
                            .opacity(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                Button(action: onAddSet) {
                    Image(systemName: "plus").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Add set to \(section.name)")
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Edit bundle")
                Button(action: onToggle) {
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 32, height: 44)
                }
                .accessibilityLabel(isExpanded ? "Collapse bundle" : "Expand bundle")
            }
            .buttonStyle(.plain)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(section.bundleSets.flatMap(\.leafExercises)) { slot in
                        Button {
                            if let id = slot.exercisePageID { onOpenPage(id) }
                        } label: {
                            VStack(spacing: 5) {
                                BundleExerciseThumbnail(slot: slot, size: 56)
                                Text(slot.displayName)
                                    .font(TimeMasterFont.body(11, relativeTo: .caption2))
                                    .lineLimit(2)
                            }
                            .frame(width: 64)
                        }
                        .buttonStyle(.plain)
                        .disabled(slot.exercisePageID == nil)
                        .accessibilityLabel("\(slot.displayName), \(slot.duration) seconds")
                    }
                }
            }
        }
        .foregroundStyle(.black)
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}
