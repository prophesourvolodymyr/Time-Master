#if os(macOS)
import Darwin
import XCTest
@testable import TimeMasterCore

final class EverAgentJSONTests: XCTestCase {
    func testParsesEveryValueKind() throws {
        let value = try JSONValue(parsing: #" {"a":[1,2.5,-3,1e3,true,false,null,"x"],"b":{"c":"d"},"e":[],"f":{}} "#)
        XCTAssertEqual(value, ["a": [1, 2.5, -3, 1000, true, false, .null, "x"], "b": ["c": "d"], "e": [], "f": [:]])
    }

    func testParsesEscapesAndSurrogatePairs() throws {
        XCTAssertEqual(try JSONValue(parsing: #""\"\\\/\b\f\n\r\t\u00e9\ud83d\ude00""#), .string("\"\\/\u{08}\u{0C}\n\r\té😀"))
        XCTAssertEqual(try JSONValue(parsing: "\"héllo 😀\""), .string("héllo 😀"))
    }

    func testRepairsLoneSurrogatesAndInvalidUTF8InsteadOfFailing() throws {
        XCTAssertEqual(try JSONValue(parsing: #""\ud800""#), .string("\u{FFFD}"))
        XCTAssertEqual(try JSONValue(parsing: #""\udc00""#), .string("\u{FFFD}"))
        XCTAssertEqual(try JSONValue(parsing: #""\ud800\u0041""#), .string("\u{FFFD}A"))
        XCTAssertEqual(try JSONValue(parsing: #""a\ud800""#), .string("a\u{FFFD}"))
        XCTAssertEqual(try JSONValue(parsing: Data([0x22, 0x61, 0xFF, 0x62, 0x22])), .string("a\u{FFFD}b"))
    }

    func testParsesNumbersExactlyAndRejectsBadOnes() throws {
        XCTAssertEqual(try JSONValue(parsing: "0"), 0)
        XCTAssertEqual(try JSONValue(parsing: "-0"), 0)
        XCTAssertEqual(try JSONValue(parsing: "123456789012345"), 123_456_789_012_345)
        XCTAssertEqual(try JSONValue(parsing: "-9007199254740991"), -9_007_199_254_740_991)
        XCTAssertEqual(try JSONValue(parsing: "12345678901234567890"), .number(1.2345678901234567e19))
        XCTAssertEqual(try JSONValue(parsing: "0.1"), 0.1)
        XCTAssertEqual(try JSONValue(parsing: "1E+2"), 100)
        XCTAssertEqual(try JSONValue(parsing: "-2.5e-3"), -0.0025)
        for bad in ["01", "1.", ".5", "-", "+1", "1e", "1e+", "0x10", "NaN", "Infinity", "1e400", "--1"] {
            XCTAssertThrowsError(try JSONValue(parsing: bad), bad)
        }
    }

    func testRejectsMalformedDocuments() {
        let bad = ["", "   ", "{", "}", "[", "[1,]", "[,1]", "[1 2]", "{\"a\":1,}", "{\"a\" 1}", "{a:1}", "{'a':1}", "{\"a\":}", "tru", "nul", "truee", "\"abc", "\"\\x\"", "\"\\u12\"", "\"\\u12G4\"", "1 2", "{}}", "[]]", "\u{0}"]
        for text in bad {
            XCTAssertThrowsError(try JSONValue(parsing: text), "Parsed: \(text)") { error in
                XCTAssertTrue(error is JSONValue.ParseError, "Wrong error type for \(text)")
            }
        }
    }

    func testReportsTheOffsetOfTheFirstProblem() {
        XCTAssertThrowsError(try JSONValue(parsing: #"{"a": [1, x]}"#)) { error in
            XCTAssertEqual((error as? JSONValue.ParseError)?.offset, 10)
        }
    }

    func testLimitsNestingDepth() throws {
        let deepest = String(repeating: "[", count: JSONParser.maximumDepth) + String(repeating: "]", count: JSONParser.maximumDepth)
        XCTAssertNoThrow(try JSONValue(parsing: deepest))
        let tooDeep = String(repeating: "[", count: JSONParser.maximumDepth + 1) + String(repeating: "]", count: JSONParser.maximumDepth + 1)
        XCTAssertThrowsError(try JSONValue(parsing: tooDeep))
        XCTAssertThrowsError(try JSONValue(parsing: String(repeating: "{\"a\":", count: 100_000)))
    }

    func testSkipsAByteOrderMarkAndSurroundingWhitespace() throws {
        XCTAssertEqual(try JSONValue(parsing: Data([0xEF, 0xBB, 0xBF] + Array(" \n[1]\r\n".utf8))), [1])
    }

    func testSerializesCompactlyWithSortedKeys() {
        let value: JSONValue = ["b": [1, 2], "a": ["z": true, "y": .null], "c": "x"]
        XCTAssertEqual(value.jsonString, #"{"a":{"y":null,"z":true},"b":[1,2],"c":"x"}"#)
    }

    func testSerializesIntegralNumbersWithoutAFraction() {
        XCTAssertEqual(JSONValue.number(0).jsonString, "0")
        XCTAssertEqual(JSONValue.number(-0.0).jsonString, "0")
        XCTAssertEqual(JSONValue.number(42).jsonString, "42")
        XCTAssertEqual(JSONValue.number(-7).jsonString, "-7")
        XCTAssertEqual(JSONValue.number(1_000_000_000_000_000).jsonString, "1000000000000000")
        XCTAssertEqual(JSONValue.number(1.5).jsonString, "1.5")
        XCTAssertEqual(JSONValue.number(0.1).jsonString, "0.1")
        XCTAssertEqual(JSONValue.number(1e-7).jsonString, "1e-07")
        XCTAssertEqual(JSONValue.number(.nan).jsonString, "null")
        XCTAssertEqual(JSONValue.number(.infinity).jsonString, "null")
        XCTAssertEqual(JSONValue.int(9_007_199_254_740_991).jsonString, "9007199254740991")
    }

    func testEscapesStringsLikeJavaScript() throws {
        let tricky = "q\"b\\s/ n\n r\r t\t \u{08}\u{0C} \u{01}\u{1F} é 😀 \u{2028}"
        XCTAssertEqual(JSONValue.string(tricky).jsonString, "\"q\\\"b\\\\s/ n\\n r\\r t\\t \\b\\f \\u0001\\u001f é 😀 \u{2028}\"")
        XCTAssertEqual(try JSONValue(parsing: JSONValue.string(tricky).jsonString), .string(tricky))
    }

    func testRoundTripsGeneratedDocumentsThroughFoundation() throws {
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next(_ bound: Int) -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((seed >> 33) % UInt64(bound))
        }
        let words = ["", "plain", "quote\"d", "back\\slash", "new\nline", "tab\t", "ünï", "日本語", "😀", "\u{01}", "slash/"]
        func make(_ depth: Int) -> Any {
            switch next(depth > 3 ? 4 : 6) {
            case 0: return words[next(words.count)]
            case 1: return next(2_000_000) - 1_000_000
            case 2: return Double(next(100_000)) / 64.0
            case 3: return next(2) == 0
            case 4: return (0..<next(5)).map { _ in make(depth + 1) }
            default: return Dictionary(uniqueKeysWithValues: (0..<next(5)).map { index in ("k\(index)\(words[next(words.count)])", make(depth + 1)) })
            }
        }
        for _ in 0..<60 {
            let document = ["root": make(0), "list": [make(1), make(1)]] as [String: Any]
            let foundationBytes = try JSONSerialization.data(withJSONObject: document)
            let parsed = try JSONValue(parsing: foundationBytes)
            let reparsed = try JSONSerialization.jsonObject(with: parsed.serialized())
            XCTAssertTrue((reparsed as AnyObject).isEqual(document), "Round trip changed \(parsed)")
        }
    }

    func testAccessorsAreLenient() {
        let value: JSONValue = ["a": ["b": [10, "x", ["c": true]]], "n": 7.9, "s": "text"]
        XCTAssertEqual(value["a"]["b"][0].intValue, 10)
        XCTAssertEqual(value["a"]["b"][1].stringValue, "x")
        XCTAssertTrue(value["a"]["b"][2]["c"].boolValue)
        XCTAssertTrue(value["a"]["b"][9].isNull)
        XCTAssertTrue(value["missing"]["deeper"].isNull)
        XCTAssertEqual(value["n"].intValue, 7)
        XCTAssertEqual(value["s"].intValue, 0)
        XCTAssertEqual(value["s"].text, "text")
        XCTAssertEqual(value["n"].text, "")
        XCTAssertEqual(value["s"].arrayValue, [])
        XCTAssertEqual(value["s"].objectValue, [:])
        XCTAssertFalse(value["s"].boolValue)
        XCTAssertEqual(JSONValue.number(.infinity).intValue, 0)
        XCTAssertEqual(JSONValue.number(1e30).intValue, 0)
    }

    func testSubscriptAssignmentBuildsObjects() {
        var value = JSONValue.null
        value["a"] = 1
        value["b"] = ["c": "d"]
        XCTAssertEqual(value, ["a": 1, "b": ["c": "d"]])
    }

    func testBridgesToCodable() throws {
        struct Payload: Codable, Equatable {
            var name: String
            var count: Int
            var tags: [String]
            var extra: JSONValue
        }
        let payload = Payload(name: "n", count: 3, tags: ["a", "b"], extra: ["k": [1, .null, true, "s"]])
        let value = try JSONValue(encoding: payload)
        XCTAssertEqual(value["count"].intValue, 3)
        XCTAssertEqual(value["extra"]["k"][3], "s")
        XCTAssertEqual(try value.decoded(Payload.self), payload)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: Data(#"{"a":[1,"x",null,true,2.5]}"#.utf8)), ["a": [1, "x", .null, true, 2.5]])
    }
}

final class EverAgentFramingTests: XCTestCase {
    private func collect(_ splitter: inout EverAgentLineSplitter, _ pieces: [[UInt8]]) throws -> [String] {
        var lines: [String] = []
        for piece in pieces {
            try piece.withUnsafeBytes { buffer in
                try splitter.feed(buffer) { lines.append(String(decoding: $0, as: UTF8.self)) }
            }
        }
        return lines
    }

    func testReassemblesALineSplitAcrossReads() throws {
        var splitter = EverAgentLineSplitter()
        XCTAssertEqual(try collect(&splitter, [Array(#"{"a":"#.utf8)]), [])
        XCTAssertEqual(splitter.bufferedBytes, 5)
        XCTAssertEqual(try collect(&splitter, [Array("1}\n{\"b\"".utf8)]), [#"{"a":1}"#])
        XCTAssertEqual(try collect(&splitter, [Array(":2}\n".utf8)]), [#"{"b":2}"#])
        XCTAssertEqual(splitter.bufferedBytes, 0)
    }

    func testDeliversSeveralLinesFromOneRead() throws {
        var splitter = EverAgentLineSplitter()
        XCTAssertEqual(try collect(&splitter, [Array("one\ntwo\nthree\nfour".utf8)]), ["one", "two", "three"])
        XCTAssertEqual(splitter.bufferedBytes, 4)
        XCTAssertEqual(try collect(&splitter, [Array("\nfive\n".utf8)]), ["four", "five"])
    }

    func testHandlesANewlineThatStartsTheNextRead() throws {
        var splitter = EverAgentLineSplitter()
        XCTAssertEqual(try collect(&splitter, [Array("abc".utf8), Array("\n".utf8), Array("def\n".utf8)]), ["abc", "def"])
    }

    func testHandlesOneByteReads() throws {
        var splitter = EverAgentLineSplitter()
        let pieces = Array("hello\nworld\n\nlast\n".utf8).map { [$0] }
        XCTAssertEqual(try collect(&splitter, pieces), ["hello", "world", "last"])
    }

    func testSkipsBlankLines() throws {
        var splitter = EverAgentLineSplitter()
        XCTAssertEqual(try collect(&splitter, [Array("\n\na\n\n\nb\n".utf8)]), ["a", "b"])
    }

    func testKeepsCarriageReturnsForTheParserToIgnore() throws {
        var splitter = EverAgentLineSplitter()
        XCTAssertEqual(try collect(&splitter, [Array("a\r\nb\r\n".utf8)]), ["a\r", "b\r"])
    }

    func testHandlesLinesLargerThanAnyReadChunk() throws {
        var splitter = EverAgentLineSplitter()
        let count = 3 * 1024 * 1024 + 123
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz".utf8)
        let body = (0..<count).map { alphabet[$0 % 26] }
        var stream = body
        stream.append(0x0A)
        stream.append(contentsOf: Array("tail\n".utf8))
        var lines: [[UInt8]] = []
        while !stream.isEmpty {
            let piece = Array(stream.prefix(65_536))
            stream.removeFirst(piece.count)
            try piece.withUnsafeBytes { buffer in
                try splitter.feed(buffer) { lines.append(Array($0)) }
            }
        }
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].count, body.count)
        XCTAssertTrue(lines[0] == body)
        XCTAssertEqual(lines[1], Array("tail".utf8))
        XCTAssertEqual(splitter.bufferedBytes, 0)
    }

    func testRejectsLinesOverTheLimit() throws {
        var splitter = EverAgentLineSplitter(maximumLineBytes: 16)
        XCTAssertEqual(try collect(&splitter, [Array("0123456789".utf8)]), [])
        XCTAssertThrowsError(try collect(&splitter, [Array("0123456789".utf8)])) { error in
            guard case EverAgentError.protocol = error else { return XCTFail("Wrong error: \(error)") }
        }
        var whole = EverAgentLineSplitter(maximumLineBytes: 16)
        XCTAssertThrowsError(try collect(&whole, [Array("0123456789012345678\n".utf8)]))
        var exact = EverAgentLineSplitter(maximumLineBytes: 16)
        XCTAssertEqual(try collect(&exact, [Array("0123456789012345\n".utf8)]), ["0123456789012345"])
    }

    func testPropagatesErrorsFromTheLineHandler() {
        struct Stop: Error {}
        var splitter = EverAgentLineSplitter()
        XCTAssertThrowsError(try Array("a\nb\n".utf8).withUnsafeBytes { try splitter.feed($0) { _ in throw Stop() } }) { error in
            XCTAssertTrue(error is Stop)
        }
    }
}

final class EverAgentPOSIXTests: XCTestCase {
    func testWriteAllRetriesInterruptedAndShortWrites() throws {
        let input = Array("The quick brown fox jumps over the lazy dog".utf8)
        var script = [-1, 3, -1, -1, 1, 5, 2, 1_000]
        var written: [UInt8] = []
        var calls = 0
        try input.withUnsafeBytes { buffer in
            try EverAgentPOSIX.writeAll(buffer) { pointer, count in
                calls += 1
                let step = script.removeFirst()
                if step < 0 {
                    errno = EINTR
                    return -1
                }
                let taken = min(step, count)
                written.append(contentsOf: UnsafeRawBufferPointer(start: pointer, count: taken))
                return taken
            }
        }
        XCTAssertEqual(written, input)
        XCTAssertEqual(calls, 8)
    }

    func testWriteAllFailsWhenThePipeIsBroken() {
        let input = Array("data".utf8)
        for failure in [EPIPE, ECONNRESET, EBADF, ENOTCONN] {
            XCTAssertThrowsError(try input.withUnsafeBytes { try EverAgentPOSIX.writeAll($0) { _, _ in errno = failure; return -1 } }) { error in
                XCTAssertEqual(error as? EverAgentError, .connectionClosed)
            }
        }
        XCTAssertThrowsError(try input.withUnsafeBytes { try EverAgentPOSIX.writeAll($0) { _, _ in 0 } }) { error in
            XCTAssertEqual(error as? EverAgentError, .connectionClosed)
        }
    }

    func testWriteAllHasNothingToDoForEmptyInput() throws {
        try [UInt8]().withUnsafeBytes { try EverAgentPOSIX.writeAll($0) { _, _ in XCTFail("Nothing should be written"); return 0 } }
    }

    func testReadSomeRetriesInterruptedReadsAndReportsEndOfFile() {
        var script = [-1, -1, 7, 0]
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
        defer { buffer.deallocate() }
        func read() -> Int {
            EverAgentPOSIX.readSome(into: buffer) { _, _ in
                let step = script.removeFirst()
                if step < 0 { errno = EINTR }
                return step
            }
        }
        XCTAssertEqual(read(), 7)
        XCTAssertEqual(read(), 0)
    }

    func testReadSomeReportsRealErrors() {
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 1)
        defer { buffer.deallocate() }
        let count = EverAgentPOSIX.readSome(into: buffer) { _, _ in
            errno = ECONNRESET
            return -1
        }
        XCTAssertEqual(count, -1)
    }

    func testSocketAddressAcceptsPathsThatFitAndRejectsLongerOnes() throws {
        let capacity = MemoryLayout.size(ofValue: sockaddr_un().sun_path)
        let fits = "/" + String(repeating: "a", count: capacity - 2)
        XCTAssertEqual(fits.utf8.count, capacity - 1)
        XCTAssertNoThrow(try EverAgentPOSIX.socketAddress(for: fits))
        let tooLong = fits + "a"
        XCTAssertThrowsError(try EverAgentPOSIX.socketAddress(for: tooLong)) { error in
            XCTAssertEqual(error as? EverAgentError, .socketPathTooLong(path: tooLong, limit: capacity - 1))
        }
        XCTAssertThrowsError(try EverAgentPOSIX.socketAddress(for: "/tmp/a\0b")) { error in
            XCTAssertEqual(error as? EverAgentError, .gatewayNotRunning(path: "/tmp/a\0b"))
        }
    }

    func testSocketAddressStoresTheNulTerminatedPath() throws {
        var address = try EverAgentPOSIX.socketAddress(for: "/tmp/x.sock")
        XCTAssertEqual(Int32(address.sun_family), AF_UNIX)
        let path = withUnsafeBytes(of: &address.sun_path) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        XCTAssertEqual(path, "/tmp/x.sock")
    }
}

final class EverAgentWireTests: XCTestCase {
    private func decode(_ text: String) throws -> EverAgentIncoming? {
        var copy = text
        return try copy.withUTF8 { try EverAgentWire.decode($0) }
    }

    func testEncodesOneSortedLinePerRequest() throws {
        let line = try EverAgentWire.encodeRequest(id: "tmax-1", method: "m", params: ["b": [true, .null], "a": 1], maximumBytes: 1024)
        XCTAssertEqual(String(decoding: line, as: UTF8.self), #"{"id":"tmax-1","method":"m","params":{"a":1,"b":[true,null]}}"# + "\n")
        let empty = try EverAgentWire.encodeRequest(id: "x", method: "server.info", params: [:], maximumBytes: 1024)
        XCTAssertEqual(String(decoding: empty, as: UTF8.self), #"{"id":"x","method":"server.info","params":{}}"# + "\n")
    }

    func testEnforcesTheRequestLimitBeforeSending() {
        XCTAssertThrowsError(try EverAgentWire.encodeRequest(id: "x", method: "m", params: ["a": "0123456789"], maximumBytes: 20)) { error in
            guard case EverAgentError.requestTooLarge(let bytes, let limit) = error else { return XCTFail("Wrong error: \(error)") }
            XCTAssertEqual(limit, 20)
            XCTAssertGreaterThan(bytes, 20)
        }
        XCTAssertNoThrow(try EverAgentWire.encodeRequest(id: "x", method: "m", params: [:], maximumBytes: 38))
    }

    func testDecodesResults() throws {
        guard case .response(let id, .success(let result))? = try decode(#"{"id":"a","result":{"k":[1,2]}}"#) else { return XCTFail("Not a result") }
        XCTAssertEqual(id, "a")
        XCTAssertEqual(result, ["k": [1, 2]])
        guard case .response(_, .success(let null))? = try decode(#"{"id":"b","result":null}"#) else { return XCTFail("Not a null result") }
        XCTAssertEqual(null, .null)
    }

    func testDecodesErrors() throws {
        guard case .response(let id, .failure(let error))? = try decode(#"{"id":"a","error":{"code":"busy","message":"claimed elsewhere","details":{"x":1}}}"#) else { return XCTFail("Not an error") }
        XCTAssertEqual(id, "a")
        XCTAssertEqual(error, .remote(code: "busy", message: "claimed elsewhere", details: ["x": 1]))
        guard case .response(_, .failure(let bare))? = try decode(#"{"id":"b","error":{}}"#) else { return XCTFail("Not an error") }
        XCTAssertEqual(bare, .remote(code: "unknown", message: "", details: nil))
        guard case .response(let empty, .failure(let invalid))? = try decode(#"{"id":"","error":{"code":"invalid_request","message":"invalid JSON-RPC request"}}"#) else { return XCTFail("Not an error") }
        XCTAssertEqual(empty, "")
        XCTAssertEqual(invalid, .remote(code: "invalid_request", message: "invalid JSON-RPC request", details: nil))
        guard case .response(_, .success(let value))? = try decode(#"{"id":"c","error":null,"result":5}"#) else { return XCTFail("A null error must not fail the request") }
        XCTAssertEqual(value, 5)
    }

    func testAResponseWithoutAnOutcomeFailsOnlyThatRequest() throws {
        guard case .response(let id, .failure(let error))? = try decode(#"{"id":"a"}"#) else { return XCTFail("Not a failure") }
        XCTAssertEqual(id, "a")
        guard case EverAgentError.protocol = error else { return XCTFail("Wrong error: \(error)") }
    }

    func testDecodesEvents() throws {
        guard case .event(let event)? = try decode(#"{"type":"event","sequence":12,"topic":"agent","projectId":"p","sessionId":"s","data":{"type":"turn_start"}}"#) else { return XCTFail("Not an event") }
        XCTAssertEqual(event, EverAgentEvent(sequence: 12, topic: "agent", projectId: "p", sessionId: "s", data: ["type": "turn_start"]))
        XCTAssertFalse(event.resync)
        guard case .event(let resync)? = try decode(#"{"type":"event","sequence":0,"topic":"events.resync","data":{"reason":"backpressure"}}"#) else { return XCTFail("Not an event") }
        XCTAssertTrue(resync.resync)
        XCTAssertNil(resync.sessionId)
        XCTAssertEqual(resync.data["reason"], "backpressure")
    }

    func testAnEventIsRecognisedByItsTypeEvenWhenAnIdIsPresent() throws {
        guard case .event(let event)? = try decode(#"{"type":"event","id":"x","sequence":1,"topic":"session","data":{}}"#) else { return XCTFail("Not an event") }
        XCTAssertEqual(event.topic, "session")
    }

    func testIgnoresLinesItDoesNotUnderstand() throws {
        XCTAssertNil(try decode(""))
        XCTAssertNil(try decode("   \r"))
        XCTAssertNil(try decode("[1,2,3]"))
        XCTAssertNil(try decode("42"))
        XCTAssertNil(try decode(#"{"type":"authenticated"}"#))
        XCTAssertNil(try decode(#"{"type":"event","sequence":3,"data":{}}"#))
        XCTAssertNil(try decode(#"{"id":7,"result":1}"#))
        XCTAssertNil(try decode(#"{"note":"no id"}"#))
    }

    func testTreatsInvalidJSONAsAProtocolViolation() {
        for text in ["not json", #"{"id":"a","result":"#, #"{"id":"a"} trailing"#] {
            XCTAssertThrowsError(try decode(text), text) { error in
                guard case EverAgentError.protocol = error else { return XCTFail("Wrong error: \(error)") }
            }
        }
    }
}

final class EverAgentSocketTests: XCTestCase {
    private var gateway: FakeGateway?

    override func tearDown() async throws {
        gateway?.stop()
        gateway = nil
    }

    func testRefusesToConnectWhereNothingListens() {
        let missing = "/tmp/tmax-ea-missing-\(UUID().uuidString.prefix(8)).sock"
        XCTAssertThrowsError(try EverAgentSocket.connect(to: missing)) { error in
            XCTAssertEqual(error as? EverAgentError, .gatewayNotRunning(path: missing))
        }
    }

    func testTreatsAStaleSocketFileAsNotRunning() throws {
        let path = "/tmp/tmax-ea-stale-\(UUID().uuidString.prefix(8)).sock"
        var address = try EverAgentPOSIX.socketAddress(for: path)
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        defer { unlink(path) }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        XCTAssertEqual(bound, 0)
        Darwin.close(descriptor)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        XCTAssertThrowsError(try EverAgentSocket.connect(to: path)) { error in
            XCTAssertEqual(error as? EverAgentError, .gatewayNotRunning(path: path))
        }
    }

    func testTreatsARegularFileAsNotRunning() throws {
        let path = "/tmp/tmax-ea-file-\(UUID().uuidString.prefix(8)).txt"
        try Data("x".utf8).write(to: URL(fileURLWithPath: path))
        defer { try? FileManager.default.removeItem(atPath: path) }
        XCTAssertThrowsError(try EverAgentSocket.connect(to: path)) { error in
            XCTAssertEqual(error as? EverAgentError, .gatewayNotRunning(path: path))
        }
    }

    func testRejectsPathsLongerThanTheSocketAddressAllows() {
        let path = "/tmp/" + String(repeating: "d", count: 200) + "/control.sock"
        XCTAssertThrowsError(try EverAgentSocket.connect(to: path)) { error in
            guard case EverAgentError.socketPathTooLong(let reported, let limit) = error else { return XCTFail("Wrong error: \(error)") }
            XCTAssertEqual(reported, path)
            XCTAssertEqual(limit, MemoryLayout.size(ofValue: sockaddr_un().sun_path) - 1)
        }
    }

    func testWritingToAClosedPeerFailsInsteadOfRaisingSIGPIPE() async throws {
        let gateway = try FakeGateway()
        self.gateway = gateway
        let socket = try EverAgentSocket.connect(to: gateway.path)
        XCTAssertTrue(socket.hasNoSigPipe)
        let connection = try await gateway.nextConnection()
        connection.closeFromServer()
        try await connection.waitUntilClosed()
        let failed = expectation(description: "write failed")
        socket.send(Array(repeating: 0x41, count: 4096)) { error in
            XCTAssertEqual(error, .connectionClosed)
            failed.fulfill()
        }
        await fulfillment(of: [failed], timeout: 5)
    }

    func testShutdownWakesTheReaderAndReleasesTheDescriptor() async throws {
        let gateway = try FakeGateway()
        self.gateway = gateway
        weak var weakSocket: EverAgentSocket?
        let closed = expectation(description: "reader finished")
        do {
            let socket = try EverAgentSocket.connect(to: gateway.path)
            weakSocket = socket
            socket.startReading(onLine: { _ in }, onClose: { reason in
                XCTAssertEqual(reason, .connectionClosed)
                closed.fulfill()
            })
            _ = try await gateway.nextConnection()
            socket.shutdown()
            socket.shutdown()
        }
        await fulfillment(of: [closed], timeout: 5)
        let deadline = Date().addingTimeInterval(5)
        while weakSocket != nil && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertNil(weakSocket, "The socket must be deallocated, and its descriptor closed, once the reader has finished")
    }

    func testReaderStopsWithAProtocolErrorWhenTheGatewaySendsTooMuchWithoutANewline() async throws {
        let gateway = try FakeGateway()
        self.gateway = gateway
        let socket = try EverAgentSocket.connect(to: gateway.path)
        let closed = expectation(description: "reader finished")
        socket.startReading(maximumLineBytes: 1024, onLine: { _ in }, onClose: { reason in
            guard case .protocol = reason else { return XCTFail("Wrong reason: \(reason)") }
            closed.fulfill()
        })
        let connection = try await gateway.nextConnection()
        connection.sendRaw(Data(repeating: 0x61, count: 4096))
        await fulfillment(of: [closed], timeout: 5)
    }
}
#endif
