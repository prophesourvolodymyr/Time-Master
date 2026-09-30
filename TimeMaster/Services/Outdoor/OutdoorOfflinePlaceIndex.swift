#if os(iOS)
import Foundation
import SQLite3

final class OutdoorOfflinePlaceIndex {
    private let database: OpaquePointer
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(url: URL) throws {
        var pointer: OpaquePointer?
        let status = sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        guard status == SQLITE_OK, let pointer else {
            let reason = pointer.map { String(cString: sqlite3_errmsg($0)) } ?? "missing database"
            if let pointer { sqlite3_close(pointer) }
            throw TripServiceError.message("Could not open the offline place index: \(reason).")
        }
        database = pointer
        sqlite3_limit(database, SQLITE_LIMIT_LENGTH, 16_000_000)
        guard sqlite3_exec(database, "PRAGMA query_only=ON; PRAGMA trusted_schema=OFF;", nil, nil, nil) == SQLITE_OK else {
            let reason = String(cString: sqlite3_errmsg(database))
            sqlite3_close(database)
            throw TripServiceError.message("Could not open the offline place index safely: \(reason).")
        }
    }

    deinit { sqlite3_close(database) }

    func validate() throws {
        try statement("PRAGMA quick_check") { query in
            guard sqlite3_step(query) == SQLITE_ROW, text(query, 0) == "ok" else { throw failure() }
        }
        for sql in [
            "SELECT id,name,detail,lat,lon,category FROM places LIMIT 0",
            "SELECT rowid FROM places_fts WHERE places_fts MATCH 'timemaster' LIMIT 0",
            "SELECT id,min_lat,max_lat,min_lon,max_lon FROM places_bounds LIMIT 0",
            "SELECT id,lat,lon,cycling,walking FROM anchors LIMIT 0",
            "SELECT id,min_lat,max_lat,min_lon,max_lon FROM anchor_bounds LIMIT 0",
            "SELECT id,unpaved FROM way_surfaces LIMIT 0"
        ] { try statement(sql) { _ in () } }
    }

    func search(_ query: String, near: TripCoordinate?) throws -> [TripPlace] {
        let terms = query.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).prefix(8)
        guard !terms.isEmpty else { return [] }
        let match = terms.map { "\"\($0)\"*" }.joined(separator: " AND ")
        let order = near == nil ? "bm25(places_fts)" : "(p.lat-?2)*(p.lat-?2)+(p.lon-?3)*(p.lon-?3)*?4,bm25(places_fts)"
        return try statement("SELECT p.id,p.name,p.detail,p.lat,p.lon FROM places_fts JOIN places p ON p.rowid=places_fts.rowid WHERE places_fts MATCH ?1 ORDER BY \(order) LIMIT 64") { query in
            sqlite3_bind_text(query, 1, match, -1, transient)
            if let near {
                sqlite3_bind_double(query, 2, near.latitude)
                sqlite3_bind_double(query, 3, near.longitude)
                sqlite3_bind_double(query, 4, pow(cos(near.latitude * .pi / 180), 2))
            }
            return try readPlaces(query)
        }
    }

    func places(near: TripCoordinate, radius: Double, categories: Set<TripPlaceCategory>) throws -> [TripPlace] {
        guard !categories.isEmpty else { return [] }
        let categories = categories.sorted { $0.rawValue < $1.rawValue }
        let placeholders = categories.indices.map { "?\($0 + 5)" }.joined(separator: ",")
        return try statement("SELECT p.id,p.name,p.detail,p.lat,p.lon FROM places_bounds b JOIN places p ON p.rowid=b.id WHERE b.max_lat>=?1 AND b.min_lat<=?2 AND b.max_lon>=?3 AND b.min_lon<=?4 AND p.category IN (\(placeholders))") { query in
            bindBounds(query, near: near, radius: radius)
            for (index, category) in categories.enumerated() { sqlite3_bind_text(query, Int32(index + 5), category.rawValue, -1, transient) }
            return try readPlaces(query).filter { $0.coordinate.distance(to: near) <= radius }
                .sorted { $0.coordinate.distance(to: near) < $1.coordinate.distance(to: near) }
        }
    }

    func anchor(near: TripCoordinate, cycling: Bool, radius: Double) throws -> TripCoordinate? {
        try statement("SELECT a.lat,a.lon FROM anchor_bounds b JOIN anchors a ON a.id=b.id WHERE b.max_lat>=?1 AND b.min_lat<=?2 AND b.max_lon>=?3 AND b.min_lon<=?4 AND ((?5=1 AND a.cycling=1) OR (?5=0 AND a.walking=1))") { query in
            bindBounds(query, near: near, radius: radius)
            sqlite3_bind_int(query, 5, cycling ? 1 : 0)
            var closest: TripCoordinate?
            var distance = radius
            while try next(query) {
                let point = TripCoordinate(latitude: sqlite3_column_double(query, 0), longitude: sqlite3_column_double(query, 1))
                guard point.isValid else { continue }
                let candidate = point.distance(to: near)
                if candidate < distance { closest = point; distance = candidate }
            }
            return closest
        }
    }

    func surfaces(_ ids: Set<Int64>) throws -> [Int64: Bool] {
        try statement("SELECT unpaved FROM way_surfaces WHERE id=?1") { query in
            var result: [Int64: Bool] = [:]
            result.reserveCapacity(ids.count)
            for id in ids {
                sqlite3_bind_int64(query, 1, id)
                if try next(query), sqlite3_column_type(query, 0) != SQLITE_NULL { result[id] = sqlite3_column_int(query, 0) != 0 }
                sqlite3_reset(query)
                sqlite3_clear_bindings(query)
            }
            return result
        }
    }

    private func readPlaces(_ query: OpaquePointer) throws -> [TripPlace] {
        var result: [TripPlace] = []
        while try next(query) {
            let coordinate = TripCoordinate(latitude: sqlite3_column_double(query, 3), longitude: sqlite3_column_double(query, 4))
            guard coordinate.isValid else { throw TripServiceError.message("The offline place index contains invalid coordinates.") }
            result.append(TripPlace(id: text(query, 0), name: text(query, 1), detail: text(query, 2), coordinate: coordinate))
        }
        return result
    }

    private func bindBounds(_ query: OpaquePointer, near: TripCoordinate, radius: Double) {
        let latitude = radius / 110_000
        let longitude = min(360, radius / (110_000 * max(0.01, cos(near.latitude * .pi / 180))))
        sqlite3_bind_double(query, 1, near.latitude - latitude)
        sqlite3_bind_double(query, 2, near.latitude + latitude)
        sqlite3_bind_double(query, 3, near.longitude - longitude)
        sqlite3_bind_double(query, 4, near.longitude + longitude)
    }

    private func statement<T>(_ sql: String, _ body: (OpaquePointer) throws -> T) throws -> T {
        var pointer: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &pointer, nil) == SQLITE_OK, let pointer else { throw failure() }
        defer { sqlite3_finalize(pointer) }
        return try body(pointer)
    }
    private func next(_ query: OpaquePointer) throws -> Bool {
        switch sqlite3_step(query) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw failure()
        }
    }
    private func text(_ query: OpaquePointer, _ column: Int32) -> String {
        sqlite3_column_text(query, column).map { String(cString: $0) } ?? ""
    }
    private func failure() -> TripServiceError {
        .message("The offline place index could not be read: \(String(cString: sqlite3_errmsg(database))). Reimport this area.")
    }
}
#endif
