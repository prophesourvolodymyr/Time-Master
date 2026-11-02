#if os(macOS)
import Foundation

enum EverAgentIncoming: Sendable {
    case response(id: String, outcome: Result<JSONValue, EverAgentError>)
    case event(EverAgentEvent)
    case closed(EverAgentError)
}

enum EverAgentWire {
    static func encodeRequest(id: String, method: String, params: [String: JSONValue], maximumBytes: Int) throws -> [UInt8] {
        var line: [UInt8] = []
        line.reserveCapacity(256)
        JSONValue.object(["id": .string(id), "method": .string(method), "params": .object(params)]).write(to: &line)
        guard line.count <= maximumBytes else { throw EverAgentError.requestTooLarge(bytes: line.count, limit: maximumBytes) }
        line.append(0x0A)
        return line
    }

    static func decode(_ line: UnsafeBufferPointer<UInt8>) throws -> EverAgentIncoming? {
        guard line.contains(where: { $0 != 0x20 && $0 != 0x09 && $0 != 0x0D }) else { return nil }
        let value: JSONValue
        do {
            value = try JSONValue.parse(line)
        } catch {
            throw EverAgentError.protocol("The gateway sent a line that is not valid JSON (\(error)).")
        }
        guard case .object(let object) = value else { return nil }
        if object["type"]?.stringValue == "event" {
            return EverAgentEvent(json: value).map { .event($0) }
        }
        guard let id = object["id"]?.stringValue else { return nil }
        let failure = value["error"]
        if !failure.isNull {
            let details = failure["details"]
            return .response(id: id, outcome: .failure(.remote(
                code: failure["code"].stringValue ?? "unknown",
                message: failure["message"].stringValue ?? "",
                details: details.isNull ? nil : details
            )))
        }
        guard let result = object["result"] else {
            return .response(id: id, outcome: .failure(.protocol("The gateway answered request \(id) without a result or an error.")))
        }
        return .response(id: id, outcome: .success(result))
    }
}
#endif
