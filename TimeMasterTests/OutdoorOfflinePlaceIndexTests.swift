import XCTest
import SQLite3
@testable import TimeMaster

final class OutdoorOfflinePlaceIndexTests: XCTestCase {
    func testAnchorRespectsTravelAccessAndSearchRadius() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        let connection = try XCTUnwrap(database)
        defer { sqlite3_close(connection) }
        let sql = """
        CREATE TABLE anchors(id INTEGER PRIMARY KEY,lat REAL,lon REAL,cycling INTEGER,walking INTEGER);
        CREATE VIRTUAL TABLE anchor_bounds USING rtree(id,min_lat,max_lat,min_lon,max_lon);
        INSERT INTO anchors VALUES(1,49.2701,-123.13,1,0),(2,49.271,-123.13,0,1),(3,49.3,-123.13,1,1);
        INSERT INTO anchor_bounds SELECT id,lat,lat,lon,lon FROM anchors;
        """
        XCTAssertEqual(sqlite3_exec(connection, sql, nil, nil, nil), SQLITE_OK)
        let index = try OutdoorOfflinePlaceIndex(url: url)
        let origin = TripCoordinate(latitude: 49.27, longitude: -123.13)
        XCTAssertEqual(try index.anchor(near: origin, cycling: false, radius: 500), TripCoordinate(latitude: 49.271, longitude: -123.13))
        XCTAssertEqual(try index.anchor(near: origin, cycling: true, radius: 500), TripCoordinate(latitude: 49.2701, longitude: -123.13))
        XCTAssertNil(try index.anchor(near: origin, cycling: false, radius: 50))
    }
}
