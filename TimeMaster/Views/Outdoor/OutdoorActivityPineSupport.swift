#if os(iOS)
import SwiftUI
import UIKit
import TimeMasterCore

struct OutdoorRouteThumbnailView: View {
    let points: [OutdoorTrackPoint]
    var compact: Bool
    private let cacheKey: String

    @State private var snapshotImage: UIImage?
    @State private var snapshotError: String?
    @State private var requestedSignature: String?

    init(points: [OutdoorTrackPoint], compact: Bool = false, cacheKey: String? = nil) {
        self.points = points
        self.compact = compact
        self.cacheKey = [cacheKey ?? "route", Self.fallbackCacheKey(for: points)].joined(separator: "|")
    }

    var body: some View {
        GeometryReader { proxy in
            let cornerRadius: CGFloat = compact ? 12 : 18
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface2.opacity(0.88))

                if points.count < 2 {
                    status(systemImage: "map", title: "Route unavailable")
                } else if let snapshotImage {
                    Image(uiImage: snapshotImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else if snapshotError != nil {
                    OutdoorRoutePolylineFallback(points: points)
                } else {
                    ProgressView()
                        .tint(Theme.textPrimary)
                        .accessibilityLabel("Loading route map preview")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                requestSnapshot(size: proxy.size)
            }
            .onChange(of: proxy.size) { size in
                requestSnapshot(size: size)
            }
            .onChange(of: cacheKey) { _ in
                requestSnapshot(size: proxy.size)
            }
        }
        .aspectRatio(compact ? 1.35 : 1.55, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(points.count > 1 ? "Recorded route map preview" : "Recorded route unavailable")
    }

    private func status(systemImage: String, title: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(compact ? .caption : .title3)
            Text(title)
                .font(compact ? .caption2 : .caption)
        }
        .foregroundStyle(Theme.textSecondary)
    }

    private func requestSnapshot(size: CGSize) {
        guard points.count > 1, size.width > 1, size.height > 1 else { return }
        let signature = "\(cacheKey)|\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
        guard requestedSignature != signature else { return }
        requestedSignature = signature
        snapshotImage = nil
        snapshotError = nil
        guard let styleURL = OutdoorMapProviderConfiguration.main.exploreStyleURL else {
            snapshotError = "Explore map style unavailable"
            return
        }
        OutdoorMapRouteSnapshotService.shared.snapshot(
            points: points,
            styleURL: styleURL,
            size: size,
            cacheKey: cacheKey
        ) { image, error in
            guard requestedSignature == signature else { return }
            snapshotImage = image
            snapshotError = image == nil ? (error?.localizedDescription ?? "Map snapshot unavailable") : nil
        }
    }

    private static func fallbackCacheKey(for points: [OutdoorTrackPoint]) -> String {
        guard let first = points.first, let last = points.last else { return "empty-route" }
        return [
            String(points.count),
            String(first.timestamp.timeIntervalSince1970),
            String(first.latitude),
            String(first.longitude),
            String(last.timestamp.timeIntervalSince1970),
            String(last.latitude),
            String(last.longitude)
        ].joined(separator: ":")
    }
}

private struct OutdoorRoutePolylineFallback: View {
    let points: [OutdoorTrackPoint]

    var body: some View {
        Canvas { context, size in
            let coordinates = points.map { CGPoint(x: CGFloat($0.longitude), y: CGFloat($0.latitude)) }
            guard coordinates.count > 1 else { return }
            let minX = coordinates.map(\.x).min() ?? 0
            let maxX = coordinates.map(\.x).max() ?? 1
            let minY = coordinates.map(\.y).min() ?? 0
            let maxY = coordinates.map(\.y).max() ?? 1
            let spanX = max(0.000001, maxX - minX)
            let spanY = max(0.000001, maxY - minY)
            let inset: CGFloat = 12
            let drawableWidth = max(1, size.width - inset * 2)
            let drawableHeight = max(1, size.height - inset * 2)

            func projected(_ coordinate: CGPoint) -> CGPoint {
                CGPoint(
                    x: inset + ((coordinate.x - minX) / spanX) * drawableWidth,
                    y: inset + (1 - ((coordinate.y - minY) / spanY)) * drawableHeight
                )
            }

            var route = Path()
            route.move(to: projected(coordinates[0]))
            for coordinate in coordinates.dropFirst() {
                route.addLine(to: projected(coordinate))
            }
            context.stroke(
                route,
                with: .color(Theme.restAccent),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )

            let start = projected(coordinates[0])
            let finish = projected(coordinates[coordinates.count - 1])
            context.fill(
                Path(ellipseIn: CGRect(x: start.x - 4, y: start.y - 4, width: 8, height: 8)),
                with: .color(.green)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: finish.x - 4, y: finish.y - 4, width: 8, height: 8)),
                with: .color(.red)
            )
        }
        .background(Theme.surface2.opacity(0.72))
        .accessibilityHidden(true)
    }
}

struct OutdoorMetricTile: View {
    let label: String
    let value: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .tracking(0.4)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        .accessibilityElement(children: .combine)
    }
}

struct OutdoorTypeBadge: View {
    let kind: OutdoorActivityKind

    var body: some View {
        Label(kind.displayName, systemImage: kind.iconName)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Theme.surface2.opacity(0.9), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .accessibilityLabel("Workout type")
            .accessibilityValue(kind.displayName)
    }
}

struct OutdoorTypeIconBadge: View {
    let kind: OutdoorActivityKind

    var body: some View {
        Image(systemName: kind.iconName)
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 30, height: 30)
            .background(Theme.surface2.opacity(0.94), in: Circle())
            .overlay {
                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            }
            .accessibilityLabel("Workout type")
            .accessibilityValue(kind.displayName)
    }
}

struct OutdoorPlayedTrackSummary: View {
    let tracks: [OutdoorPlayedTrackEvent]
    var visible: Bool = true

    var body: some View {
        if visible {
            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    ForEach(Array(tracks.prefix(4).enumerated()), id: \.offset) { index, track in
                        OutdoorMusicArtworkView(
                            artworkReference: track.artworkReference,
                            size: 32
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        }
                        .offset(x: CGFloat(index) * 10)
                        .accessibilityHidden(true)
                    }
                }
                .frame(width: tracks.isEmpty ? 32 : 32 + CGFloat(min(tracks.count, 4) - 1) * 10, height: 34)
                Text(tracks.isEmpty ? "No played tracks" : tracks.count == 1 ? "1 played track" : "\(tracks.count) played tracks")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(tracks.isEmpty ? "No played tracks" : tracks.count == 1 ? "One played track" : "\(tracks.count) played tracks")
        }
    }
}

struct OutdoorInlineError: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityAddTraits(.updatesFrequently)
    }
}

struct OutdoorDeletionConfirmation: View {
    let activity: OutdoorActivity
    @Binding var isPresented: Bool
    let onDelete: () -> Void
    @AccessibilityFocusState private var dialogFocused: Bool

    private var significant: Bool {
        activity.elapsedSeconds >= 60 * 60 || activity.distanceMeters >= 20_000
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            VStack(spacing: 14) {
                Image(systemName: "trash")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.red)
                Text("Delete workout?")
                    .font(.headline.weight(.semibold))
                Text(significant ? "This significant route requires a continuous 1.2-second hold to delete." : "This removes the saved route and its details from Library.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(OutdoorPineButtonStyle())
                    if significant {
                        OutdoorDestructiveHoldButton {
                            isPresented = false
                            onDelete()
                        }
                    } else {
                        Button("Delete", role: .destructive) {
                            isPresented = false
                            onDelete()
                        }
                        .buttonStyle(OutdoorPineButtonStyle())
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(radius: 20)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(significant ? "Delete significant workout confirmation" : "Delete workout confirmation")
            .accessibilityFocused($dialogFocused)
        }
        .accessibilityAddTraits(.isModal)
        .onAppear { dialogFocused = true }
        .transition(.opacity)
        .zIndex(20)
    }
}

struct OutdoorDestructiveHoldButton: View {
    let onComplete: () -> Void
    @State private var isPressing = false
    @State private var startedAt: Date?
    @State private var accessibilityDeleteArmed = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.02)) { context in
            let elapsed = startedAt.map { context.date.timeIntervalSince($0) } ?? 0
            let progress = isPressing ? min(1, max(0, elapsed / 1.2)) : 0
            Button {
            } label: {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(0.16))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(0.36))
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: progress, y: 1, anchor: .leading)
                    Text(progress >= 1 ? "Release" : "Hold to Delete")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.red)
                }
                .frame(minWidth: 130, minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.red.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard hypot(value.translation.width, value.translation.height) <= 24 else {
                            isPressing = false
                            startedAt = nil
                            return
                        }
                        if startedAt == nil { startedAt = Date() }
                        isPressing = true
                    }
                    .onEnded { _ in
                        let completed = startedAt.map { Date().timeIntervalSince($0) >= 1.2 } ?? false
                        isPressing = false
                        startedAt = nil
                        if completed { onComplete() }
                    }
            )
            .accessibilityAction(named: accessibilityDeleteArmed ? "Confirm deletion" : "Arm deletion") {
                if accessibilityDeleteArmed {
                    onComplete()
                } else {
                    accessibilityDeleteArmed = true
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Deletion armed. Use Confirm deletion to remove this significant workout."
                    )
                }
            }
            .accessibilityLabel("Hold for 1.2 seconds to delete")
            .accessibilityHint("Keep your finger down until the progress completes")
            .accessibilityValue(accessibilityDeleteArmed ? "Deletion armed" : "Deletion not armed")
        }
    }
}

extension OutdoorActivity {
    var isSignificantForDeletion: Bool {
        elapsedSeconds >= 60 * 60 || distanceMeters >= 20_000
    }
}

func outdoorDistanceText(_ meters: Double, unitSystem: TimeMasterCore.OutdoorUnitSystem, precision: Bool = false) -> String {
    switch unitSystem {
    case .metric:
        let value = meters / 1_000
        return String(format: precision || value < 10 ? "%.2f km" : "%.1f km", value)
    case .imperial:
        let value = meters / 1_609.344
        return String(format: precision || value < 10 ? "%.2f mi" : "%.1f mi", value)
    }
}

func outdoorSpeedText(_ metersPerSecond: Double?, unitSystem: TimeMasterCore.OutdoorUnitSystem) -> String {
    guard let speed = metersPerSecond, speed.isFinite else { return "—" }
    let value = unitSystem == .metric ? speed * 3.6 : speed * 2.236936
    return String(format: "%.1f %@", value, unitSystem == .metric ? "km/h" : "mph")
}

func outdoorElevationText(_ meters: Double?, unitSystem: TimeMasterCore.OutdoorUnitSystem) -> String {
    guard let meters, meters.isFinite else { return "—" }
    let value = unitSystem == .metric ? meters : meters * 3.28084
    return String(format: "%.0f %@", value, unitSystem == .metric ? "m" : "ft")
}

func outdoorDurationText(_ seconds: Int) -> String {
    let value = max(0, seconds)
    let hours = value / 3_600
    let minutes = (value % 3_600) / 60
    let remainder = value % 60
    if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, remainder) }
    return String(format: "%d:%02d", minutes, remainder)
}

func outdoorPaceText(_ secondsPerKilometer: Double?, unitSystem: TimeMasterCore.OutdoorUnitSystem) -> String {
    guard let secondsPerKilometer, secondsPerKilometer.isFinite, secondsPerKilometer > 0 else { return "—" }
    let secondsPerUnit = unitSystem == .metric ? secondsPerKilometer : secondsPerKilometer * 1.609344
    let totalSeconds = max(0, Int(secondsPerUnit.rounded()))
    return String(format: "%d:%02d/%@", totalSeconds / 60, totalSeconds % 60, unitSystem == .metric ? "km" : "mi")
}

func outdoorDateText(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
}
#endif
