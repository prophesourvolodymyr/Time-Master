#if os(iOS)
import UIKit
import MapLibre

struct TripMapEditing {
    var trip: OutdoorTrip
    var revision: Int
    var picking: Bool
    var topInset: CGFloat
    var onPick: (TripCoordinate) -> Void
    var onBeginDrag: (UUID, Int) -> Void
    var onDrag: (TripCoordinate, Bool) -> Void
    var onCancelDrag: () -> Void
    var onLocation: (TripCoordinate) -> Void
}

final class TripStopAnnotation: MLNPointAnnotation {
    var number = 0
}

@MainActor
final class OutdoorTripMapInteraction: NSObject, UIGestureRecognizerDelegate {
    private weak var map: MLNMapView?
    private var input: TripMapEditing?
    private var renderedRevision: Int?
    private var renderedStyle: ObjectIdentifier?
    private var annotations: [TripStopAnnotation] = []
    private var hit: (UUID, Int)?
    private var dragHandle: UIView?
    private var previousScrollEnabled = true
    private lazy var hold = UILongPressGestureRecognizer(target: self, action: #selector(drag(_:)))
    private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(pick(_:)))

    init(map: MLNMapView) {
        self.map = map
        super.init()
        hold.minimumPressDuration = 0.18
        hold.allowableMovement = 14
        hold.delegate = self
        tap.delegate = self
        tap.require(toFail: hold)
        map.addGestureRecognizer(hold)
        map.addGestureRecognizer(tap)
    }

    func update(_ input: TripMapEditing?) {
        self.input = input
        hold.isEnabled = input != nil && input?.picking == false
        tap.isEnabled = input?.picking == true
        render()
    }

    func render() {
        guard let map, let style = map.style else { return }
        guard renderedRevision != input?.revision || renderedStyle != ObjectIdentifier(style) else { return }
        renderedRevision = input?.revision
        renderedStyle = ObjectIdentifier(style)
        let features = (input?.trip.legs ?? []).filter { $0.coordinates.count > 1 }.map { leg -> MLNPolylineFeature in
            var coordinates = leg.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let line = MLNPolylineFeature(coordinates: &coordinates, count: UInt(coordinates.count))
            line.attributes = ["mode": leg.mode.rawValue]
            return line
        }
        let source: MLNShapeSource
        if let existing = style.source(withIdentifier: "trip-editor-route") as? MLNShapeSource {
            source = existing
            source.shape = MLNShapeCollectionFeature(shapes: features)
        } else {
            source = MLNShapeSource(identifier: "trip-editor-route", shape: MLNShapeCollectionFeature(shapes: features), options: nil)
            style.addSource(source)
        }
        for mode in TripLegMode.allCases {
            let id = "trip-editor-\(mode.rawValue)"
            let layer: MLNLineStyleLayer
            if let existing = style.layer(withIdentifier: id) as? MLNLineStyleLayer { layer = existing }
            else {
                layer = MLNLineStyleLayer(identifier: id, source: source)
                layer.predicate = NSPredicate(format: "mode == %@", mode.rawValue)
                style.addLayer(layer)
            }
            layer.lineColor = NSExpression(forConstantValue: mode == .bus ? UIColor.systemPurple : UIColor.systemBlue)
            layer.lineWidth = NSExpression(forConstantValue: 5)
            layer.lineJoin = NSExpression(forConstantValue: "round")
            layer.lineCap = NSExpression(forConstantValue: "round")
            if mode == .bus { layer.lineDashPattern = NSExpression(forConstantValue: [2, 1.5]) }
        }
        map.removeAnnotations(annotations)
        annotations = (input?.trip.stops ?? []).enumerated().map { index, stop in
            let annotation = TripStopAnnotation()
            annotation.number = index
            annotation.title = index == 0 ? "Start · \(stop.name)" : "\(index) · \(stop.name)"
            annotation.coordinate = CLLocationCoordinate2D(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
            return annotation
        }
        map.addAnnotations(annotations)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let input, let map else { return false }
        if gestureRecognizer === tap { return input.picking }
        guard input.trip.isRouted else { return false }
        let point = gestureRecognizer.location(in: map)
        var bestDistance: CGFloat = 24
        hit = nil
        for leg in input.trip.legs where leg.mode == .active {
            guard leg.coordinates.count > 1 else { continue }
            var previous = map.convert(CLLocationCoordinate2D(latitude: leg.coordinates[0].latitude, longitude: leg.coordinates[0].longitude), toPointTo: map)
            for index in 1..<leg.coordinates.count {
                let coordinate = leg.coordinates[index]
                let next = map.convert(CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude), toPointTo: map)
                let dx = next.x - previous.x, dy = next.y - previous.y
                let denominator = dx * dx + dy * dy
                let t = denominator > 0 ? min(1, max(0, ((point.x - previous.x) * dx + (point.y - previous.y) * dy) / denominator)) : 0
                let distance = hypot(point.x - previous.x - t * dx, point.y - previous.y - t * dy)
                if distance < bestDistance { bestDistance = distance; hit = (leg.id, index - 1) }
                previous = next
            }
        }
        return hit != nil
    }

    @objc private func pick(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let map, let input, input.picking else { return }
        input.onPick(coordinate(at: gesture.location(in: map), map: map))
    }

    @objc private func drag(_ gesture: UILongPressGestureRecognizer) {
        guard let map, let input else { restoreMap(); return }
        let point = gesture.location(in: map)
        switch gesture.state {
        case .began:
            guard let hit else { return }
            previousScrollEnabled = map.isScrollEnabled
            map.isScrollEnabled = false
            let handle = UIView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
            handle.backgroundColor = .systemBlue
            handle.layer.cornerRadius = 12
            handle.layer.borderWidth = 3
            handle.layer.borderColor = UIColor.white.cgColor
            handle.isUserInteractionEnabled = false
            handle.center = point
            map.addSubview(handle)
            dragHandle = handle
            UISelectionFeedbackGenerator().selectionChanged()
            input.onBeginDrag(hit.0, hit.1)
            input.onDrag(coordinate(at: point, map: map), false)
        case .changed:
            dragHandle?.center = point
            input.onDrag(coordinate(at: point, map: map), false)
        case .ended:
            input.onDrag(coordinate(at: point, map: map), true)
            restoreMap()
        case .cancelled, .failed:
            input.onCancelDrag()
            restoreMap()
        default: break
        }
    }

    private func coordinate(at point: CGPoint, map: MLNMapView) -> TripCoordinate {
        let coordinate = map.convert(point, toCoordinateFrom: map)
        return TripCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private func restoreMap() {
        if dragHandle != nil { map?.isScrollEnabled = previousScrollEnabled }
        dragHandle?.removeFromSuperview()
        dragHandle = nil
        hit = nil
    }
}
#endif
