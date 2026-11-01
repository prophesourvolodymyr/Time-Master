import XCTest
@testable import TimeMasterCore

final class SyncNetworkPolicyTests: XCTestCase {
    func testOnlyAddressesFromTheLocalNetworkAreAccepted() {
        XCTAssertTrue(SyncNetworkPolicy.isLocal([192, 168, 1, 20]))
        XCTAssertTrue(SyncNetworkPolicy.isLocal([10, 0, 0, 5]))
        XCTAssertTrue(SyncNetworkPolicy.isLocal([172, 16, 0, 1]))
        XCTAssertTrue(SyncNetworkPolicy.isLocal([169, 254, 1, 1]))
        XCTAssertTrue(SyncNetworkPolicy.isLocal([127, 0, 0, 1]))
        XCTAssertFalse(SyncNetworkPolicy.isLocal([172, 32, 0, 1]))
        XCTAssertFalse(SyncNetworkPolicy.isLocal([8, 8, 8, 8]))
        XCTAssertFalse(SyncNetworkPolicy.isLocal([1, 2, 3]), "not an address")
    }

    func testIPv6LocalAndMappedAddresses() {
        var linkLocal = [UInt8](repeating: 0, count: 16)
        linkLocal[0] = 0xfe
        linkLocal[1] = 0x80
        XCTAssertTrue(SyncNetworkPolicy.isLocal(linkLocal))
        var global = [UInt8](repeating: 0, count: 16)
        global[0] = 0x20
        global[1] = 0x01
        XCTAssertFalse(SyncNetworkPolicy.isLocal(global))
        var mapped = [UInt8](repeating: 0, count: 16)
        mapped[10] = 0xff
        mapped[11] = 0xff
        mapped[12...15] = [192, 168, 0, 9]
        XCTAssertTrue(SyncNetworkPolicy.isLocal(mapped), "an IPv4 address in IPv6 clothes is judged as IPv4")
        mapped[12...15] = [8, 8, 8, 8]
        XCTAssertFalse(SyncNetworkPolicy.isLocal(mapped))
    }
}
