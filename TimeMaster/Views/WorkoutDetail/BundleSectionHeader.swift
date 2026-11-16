import SwiftUI

struct BundleSectionHeader: View {
    let section: Section
    let isExpanded: Bool
    var rail = BuilderRail()
    var slice: BuilderSlice = .top
    var progress: Double?
    let onToggle: () -> Void
    let onAddSet: () -> Void
    let onEdit: () -> Void
    let onOpenPage: (UUID) -> Void
    @Environment(\.workoutHeroSources) private var heroSources

    private var summary: String {
        let seconds = section.calculatedDuration
        return "\(section.bundleSets.count) sets · \(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 0) {
                BuilderHandle(tone: .light)
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityHidden(true)
                    .frame(width: BuilderMetrics.root, height: BuilderMetrics.root)
                    .background(
                        RoundedRectangle(cornerRadius: BuilderMetrics.thumbnailRadius(BuilderMetrics.root), style: .continuous)
                            .fill(Color.black.opacity(0.07))
                    )
                    .overlay {
                        if let progress {
                            BuilderProgressRing(
                                progress: progress,
                                cornerRadius: BuilderMetrics.thumbnailRadius(BuilderMetrics.root)
                            )
                        }
                    }
                    .padding(.leading, BuilderMetrics.handleGap)
                Button(action: onToggle) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.name)
                            .font(TimeMasterFont.black(17, relativeTo: .headline))
                            .lineLimit(1)
                        Text(summary)
                            .font(TimeMasterFont.caption().monospacedDigit())
                            .opacity(0.6)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: BuilderMetrics.root, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, BuilderMetrics.rootGap)
                .accessibilityLabel("\(section.name), \(summary)")
                .accessibilityHint(isExpanded ? "Collapses the bundle" : "Expands the bundle")
                BuilderCluster {
                    Button(action: onAddSet) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(BuilderChipButtonStyle(tone: .light))
                    .accessibilityLabel("Add set to \(section.name)")
                } middle: {
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(BuilderChipButtonStyle(tone: .light))
                    .accessibilityLabel("Edit bundle")
                } last: {
                    BuilderDisclosureChip(
                        isExpanded: isExpanded,
                        tone: .light,
                        expandLabel: "Expand bundle",
                        collapseLabel: "Collapse bundle",
                        action: onToggle
                    )
                }
                .frame(height: BuilderMetrics.root)
                .padding(.leading, 8)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(section.bundleSets.flatMap(\.leafExercises)) { slot in
                        let key = "bundle-strip-\(slot.id)"
                        Button {
                            guard let id = slot.exercisePageID else { return }
                            heroSources?.markTapped(key)
                            onOpenPage(id)
                        } label: {
                            VStack(spacing: 5) {
                                BundleExerciseThumbnail(slot: slot, size: 52)
                                    .workoutHeroSource(key)
                                Text(slot.displayName)
                                    .font(TimeMasterFont.body(11, relativeTo: .caption2))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 60)
                        }
                        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 10))
                        .disabled(slot.exercisePageID == nil)
                        .accessibilityLabel("\(slot.displayName), \(slot.duration) seconds")
                    }
                }
            }
            .padding(.leading, BuilderMetrics.textX(1))
        }
        .foregroundStyle(.black)
        .modifier(BuilderRowChrome(rail: rail, slice: slice, tone: .light, vertical: BuilderMetrics.headerVertical))
    }
}
