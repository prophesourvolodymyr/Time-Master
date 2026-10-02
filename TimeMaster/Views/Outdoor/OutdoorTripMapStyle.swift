#if os(iOS)
import UIKit
import CoreLocation
import MapLibre

enum OutdoorTripMapStyle {
    static func color(for mode: TripLegMode) -> UIColor {
        mode == .bus ? .systemYellow : .systemBlue
    }

    static func draw(_ route: PlannedRoute, on overlay: MLNMapSnapshotOverlay) {
        if let trip = route.trip { draw(trip, on: overlay); return }
        let context = overlay.context
        context.saveGState()
        defer { context.restoreGState() }
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let path = CGMutablePath()
        for (index, point) in route.points.enumerated() {
            let projected = overlay.point(for: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))
            if index == 0 { path.move(to: projected) } else { path.addLine(to: projected) }
        }
        context.addPath(path)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(8)
        context.strokePath()
        context.addPath(path)
        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(5)
        context.strokePath()
    }

    static func draw(_ trip: OutdoorTrip, on overlay: MLNMapSnapshotOverlay) {
        let context = overlay.context
        context.saveGState()
        defer { context.restoreGState() }
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for leg in trip.legs where leg.coordinates.count > 1 {
            let path = CGMutablePath()
            for (index, point) in leg.coordinates.enumerated() {
                let projected = overlay.point(for: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))
                if index == 0 { path.move(to: projected) } else { path.addLine(to: projected) }
            }
            context.setLineDash(phase: 0, lengths: [])
            context.addPath(path)
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(8)
            context.strokePath()
            context.addPath(path)
            context.setStrokeColor(color(for: leg.mode).cgColor)
            context.setLineWidth(5)
            context.setLineDash(phase: 0, lengths: leg.mode == .bus ? [10, 7.5] : [])
            context.strokePath()
        }
        context.setLineDash(phase: 0, lengths: [])
        for (index, stop) in trip.stops.enumerated() {
            let point = overlay.point(for: CLLocationCoordinate2D(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude))
            let marker = CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24)
            context.setFillColor(color(for: index == 0 ? .active : stop.incomingMode).cgColor)
            context.fillEllipse(in: marker)
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(2)
            context.strokeEllipse(in: marker)
            let text = "\(index + 1)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: UIColor.white]
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2), withAttributes: attributes)
        }
    }
}
#endif
