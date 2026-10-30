import Foundation

extension KeyedDecodingContainer {
    /// The value under `key`, or nil when it is missing, null or of another type. Fields added to a manifest after
    /// release decode with this, so a value an older or newer build wrote differently never fails the whole file.
    func lenient<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}

extension KeyedEncodingContainer {
    /// Writes `value` only when it holds something, so a manifest that never used a field does not grow it.
    mutating func encodeUnlessEmpty<T: Encodable & Collection>(_ value: T, forKey key: Key) throws {
        guard !value.isEmpty else { return }
        try encode(value, forKey: key)
    }
}

extension Array where Element: Hashable {
    /// The elements in their order with later repeats dropped.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
