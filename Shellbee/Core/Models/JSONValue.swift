import Foundation

enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        self = .null
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}

extension JSONValue {
    var stringValue: String? { guard case .string(let s) = self else { return nil }; return s }
    var boolValue: Bool? { guard case .bool(let b) = self else { return nil }; return b }
    var intValue: Int? { guard case .int(let i) = self else { return nil }; return i }
    var object: [String: JSONValue]? { guard case .object(let o) = self else { return nil }; return o }
    var array: [JSONValue]? { guard case .array(let a) = self else { return nil }; return a }

    func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    var numberValue: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i): return Double(i)
        default: return nil
        }
    }

    var stringified: String {
        switch self {
        case .null:
            return "None"
        case .bool(let value):
            return value ? "On" : "Off"
        case .int(let value):
            return "\(value)"
        case .double(let value):
            return value.formatted(.number.precision(.fractionLength(0...2)))
        case .string(let value):
            return value
        case .array(let values):
            return values.map(\.stringified).joined(separator: ", ")
        case .object:
            return "Object"
        }
    }

    func value(at payloadPath: [String]) -> JSONValue? {
        guard let first = payloadPath.first else { return self }
        guard case .object(let object) = self, let next = object[first] else { return nil }
        return next.value(at: Array(payloadPath.dropFirst()))
    }
}
