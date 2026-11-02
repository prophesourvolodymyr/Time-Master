#if os(macOS)
import Darwin
import XCTest
@testable import TimeMasterCore

final class EverAgentSocketDiscoveryTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = URL(fileURLWithPath: "/tmp").appendingPathComponent("ea-home-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    private func makeSocket(_ relative: String, ageInSeconds: TimeInterval) throws {
        let url = home.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        defer { close(descriptor) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(url.path.utf8CString)
        XCTAssertLessThanOrEqual(bytes.count, MemoryLayout.size(ofValue: address.sun_path))
        withUnsafeMutableBytes(of: &address.sun_path) { target in
            for (index, byte) in bytes.enumerated() { target[index] = UInt8(bitPattern: byte) }
        }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        XCTAssertEqual(bound, 0)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-ageInSeconds)], ofItemAtPath: url.path)
    }

    func testTheLegacySocketAndEveryContainerSocketAreFoundNewestFirst() throws {
        try makeSocket(".ompp/server/control.sock", ageInSeconds: 900)
        try makeSocket(".ompp/c/cf67778b-ac3/control.sock", ageInSeconds: 100)
        try makeSocket(".ompp/c/0a1b2c3d4e5f/control.sock", ageInSeconds: 500)
        let found = EverAgentSocketDiscovery.candidates(home: home).map { $0.replacingOccurrences(of: home.path, with: "") }
        XCTAssertEqual(found, ["/.ompp/c/cf67778b-ac3/control.sock", "/.ompp/c/0a1b2c3d4e5f/control.sock", "/.ompp/server/control.sock"])
    }

    func testRegularFilesFoldersWithoutASocketAndAMissingOmppFolderGiveNothing() throws {
        XCTAssertEqual(EverAgentSocketDiscovery.candidates(home: home), [])
        let server = home.appendingPathComponent(".ompp/server")
        try FileManager.default.createDirectory(at: server, withIntermediateDirectories: true)
        try Data().write(to: server.appendingPathComponent("control.sock"))
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".ompp/c/empty"), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: home.appendingPathComponent(".ompp/c/notes.txt"))
        XCTAssertEqual(EverAgentSocketDiscovery.candidates(home: home), [])
    }

    func testAStaleSocketIsListedButTheClientReportsNothingIsListening() async throws {
        try makeSocket(".ompp/c/stale/control.sock", ageInSeconds: 10)
        let path = try XCTUnwrap(EverAgentSocketDiscovery.candidates(home: home).first)
        let client = EverAgentClient(socketPath: path)
        do {
            try await client.connect()
            XCTFail("Connecting to a socket nobody listens on should fail")
        } catch EverAgentError.gatewayNotRunning {
        }
    }
}
#endif
