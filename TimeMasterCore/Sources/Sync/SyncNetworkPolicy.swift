import Foundation

public enum SyncNetworkPolicy {
    public static func isLocal(_ bytes: [UInt8]) -> Bool {
        switch bytes.count {
        case 4:
            let a = bytes[0], b = bytes[1]
            if a == 10 || a == 127 { return true }
            if a == 172, (16...31).contains(b) { return true }
            if a == 192, b == 168 { return true }
            if a == 169, b == 254 { return true }
            return false
        case 16:
            if bytes.prefix(15).allSatisfy({ $0 == 0 }), bytes[15] == 1 { return true }
            if bytes[0] == 0xfe, bytes[1] & 0xc0 == 0x80 { return true }
            if bytes[0] & 0xfe == 0xfc { return true }
            if bytes.prefix(10).allSatisfy({ $0 == 0 }), bytes[10] == 0xff, bytes[11] == 0xff {
                return isLocal(Array(bytes[12...]))
            }
            return false
        default:
            return false
        }
    }
}
