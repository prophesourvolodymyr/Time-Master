#if os(iOS)
import UIKit
import Photos
import TimeMasterCore

@MainActor
struct OutdoorTripImageExportService {
    enum ExportError: LocalizedError {
        case photosDenied
        var errorDescription: String? { "Allow Time-Master to add photos in Settings, then try saving the trip image again." }
    }

    func image(for route: PlannedRoute, units: OutdoorUnitSystem) async throws -> UIImage {
        guard route.trip?.isRouted != false, route.points.count > 1 else {
            throw TripServiceError.message("Finish calculating the trip before exporting its map.")
        }
        guard let logo = UIImage(named: "TimeMasterMark") else {
            throw TripServiceError.message("The Time-Master logo is missing from the app resources.")
        }
        let coordinates = route.trip?.stops.map(\.coordinate) ?? route.points.map { TripCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        let region = try await OutdoorOfflineTripPacks.shared.region(covering: coordinates)
        let size = CGSize(width: 1080, height: 1350)
        let inset = size.width * 0.04
        let mapSize = CGSize(width: size.width - inset * 2, height: size.height * 0.61)
        let map = try await OutdoorMapRouteSnapshotService.shared.tripSnapshot(route, styleURL: region.styleURL, size: mapSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            UIColor(white: 0.04, alpha: 1).setFill()
            renderer.fill(CGRect(origin: .zero, size: size))
            let logoSize = size.width * 0.06
            logo.draw(in: CGRect(x: inset, y: inset * 0.6, width: logoSize, height: logoSize))
            drawText("Planned Trip", in: CGRect(x: inset + logoSize + inset * 0.35, y: inset * 0.65, width: size.width * 0.5, height: logoSize), size: 36, weight: .semibold)
            let mapRect = CGRect(x: inset, y: inset * 2.5, width: mapSize.width, height: mapSize.height)
            renderer.cgContext.saveGState()
            UIBezierPath(roundedRect: mapRect, cornerRadius: inset * 0.6).addClip()
            map.draw(in: mapRect)
            renderer.cgContext.restoreGState()
            let titleY = mapRect.maxY + inset * 0.65
            drawText(route.title, in: CGRect(x: inset, y: titleY, width: mapSize.width, height: inset * 1.6), size: 42, weight: .bold)
            let metricsY = titleY + inset * 1.8
            let columnWidth = mapSize.width / 3
            let trip = route.trip
            metric(trip == nil ? "TRACK DISTANCE" : trip?.kind == .bike ? "RIDING DISTANCE" : "ON-FOOT DISTANCE", value: outdoorDistanceText(route.distanceMeters, unitSystem: units, precision: true), at: CGPoint(x: inset, y: metricsY), width: columnWidth)
            metric("ELEVATION GAIN", value: outdoorElevationText(trip?.ascentMeters, unitSystem: units), at: CGPoint(x: inset + columnWidth, y: metricsY), width: columnWidth)
            metric("EST. ACTIVE TIME", value: trip.map { outdoorDurationText(Int($0.activeDurationSeconds.rounded())) } ?? "Unknown", at: CGPoint(x: inset + columnWidth * 2, y: metricsY), width: columnWidth)
            let note: String
            if let trip {
                note = trip.hasBus
                    ? "\(outdoorDistanceText(trip.totalDistanceMeters, unitSystem: units, precision: true)) total · Yellow dashed legs: bus road estimates, not timetabled services"
                    : "\(trip.kind.displayName) · \(trip.preference.title(for: trip.kind)) · \(trip.effortTitle)"
            } else { note = "Imported track · Road, elevation, and timing estimates unavailable" }
            drawText(note, in: CGRect(x: inset, y: metricsY + inset * 2.5, width: mapSize.width, height: inset * 1.4), size: 23, weight: .regular, color: UIColor(white: 0.7, alpha: 1))
            drawText("Time-Master · © OpenStreetMap contributors · ODbL 1.0 · openstreetmap.org/copyright", in: CGRect(x: inset, y: size.height - inset * 1.5, width: mapSize.width, height: inset), size: 19, weight: .regular, color: UIColor(white: 0.5, alpha: 1))
        }
    }

    func saveToPhotos(_ image: UIImage) async throws {
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined { status = await PHPhotoLibrary.requestAuthorization(for: .addOnly) }
        guard status == .authorized || status == .limited else { throw ExportError.photosDenied }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { success, error in
                if success { continuation.resume() }
                else { continuation.resume(throwing: error ?? TripServiceError.message("Photos could not save the trip image.")) }
            })
        }
    }

    private func metric(_ title: String, value: String, at point: CGPoint, width: CGFloat) {
        drawText(title, in: CGRect(origin: point, size: CGSize(width: width - 12, height: 32)), size: 19, weight: .semibold, color: UIColor(white: 0.6, alpha: 1))
        drawText(value, in: CGRect(x: point.x, y: point.y + 38, width: width - 12, height: 62), size: 40, weight: .bold)
    }

    private func drawText(_ text: String, in rect: CGRect, size: CGFloat, weight: UIFont.Weight, color: UIColor = .white) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph])
    }
}
#endif
