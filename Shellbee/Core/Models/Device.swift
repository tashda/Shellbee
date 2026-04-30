import Foundation
import SwiftUI

struct Device: Codable, Identifiable, Sendable, Equatable, Hashable {
    let ieeeAddress: String
    let type: DeviceType
    let networkAddress: Int
    let supported: Bool
    var friendlyName: String
    var disabled: Bool
    var description: String?
    var definition: DeviceDefinition?
    var powerSource: String?
    var modelId: String?
    var manufacturer: String?
    let interviewCompleted: Bool
    let interviewing: Bool
    var softwareBuildId: String?
    var dateCode: String?
    var endpoints: [String: JSONValue]?
    var options: [String: JSONValue]?

    var id: String { ieeeAddress }

    var availableEndpoints: [Int] {
        guard let keys = endpoints?.keys, !keys.isEmpty else { return [1] }
        let ints = keys.compactMap(Int.init).sorted()
        return ints.isEmpty ? [1] : ints
    }

    /// Whether the device exposes the Zigbee Identify cluster as a writable
    /// property. Z2M renders this as `{ "name": "identify", "type": "enum",
    /// "property": "identify", "access": 2, "values": ["identify"] }`.
    var supportsIdentify: Bool {
        guard let exposes = definition?.exposes else { return false }
        return exposes.flattened.contains { expose in
            expose.property == "identify" && expose.isWritable
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Device, rhs: Device) -> Bool { lhs.ieeeAddress == rhs.ieeeAddress }

    enum CodingKeys: String, CodingKey {
        case ieeeAddress = "ieee_address"
        case type, supported, disabled, description, definition, manufacturer, interviewing
        case networkAddress = "network_address"
        case friendlyName = "friendly_name"
        case powerSource = "power_source"
        case modelId = "model_id"
        case interviewCompleted = "interview_completed"
        case softwareBuildId = "software_build_id"
        case dateCode = "date_code"
        case endpoints, options
    }
}

enum DeviceType: String, Codable, Sendable, Equatable, ChipRepresentable {
    case router = "Router"
    case endDevice = "EndDevice"
    case coordinator = "Coordinator"
    case unknown

    var chipLabel: String {
        switch self {
        case .router: return "Router"
        case .endDevice: return "End Device"
        case .coordinator: return "Coordinator"
        case .unknown: return "Unknown"
        }
    }

    var chipIcon: String? {
        switch self {
        case .router: return "router"
        case .endDevice: return "leaf"
        case .coordinator: return "hub.hop.fill"
        case .unknown: return nil
        }
    }

    var chipTint: Color {
        switch self {
        case .router: return .indigo
        case .endDevice: return .green
        case .coordinator: return .purple
        case .unknown: return .secondary
        }
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        self = DeviceType(rawValue: try c.decode(String.self)) ?? .unknown
    }
}

struct DeviceDefinition: Codable, Sendable, Equatable {
    let model: String
    let vendor: String
    let description: String
    let supportsOTA: Bool?
    let exposes: [Expose]
    let options: [Expose]?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case model, vendor, description, exposes, options, icon
        case supportsOTA = "supports_ota"
    }
}

struct Expose: Codable, Sendable, Equatable {
    let type: String
    let name: String?
    let label: String?
    let description: String?
    let access: Int?
    let property: String?
    let endpoint: String?
    let features: [Expose]?
    let options: [Expose]?
    let unit: String?
    let valueMin: Double?
    let valueMax: Double?
    let valueStep: Double?
    let values: [String]?
    let valueOn: JSONValue?
    let valueOff: JSONValue?
    let presets: [ExposePreset]?

    nonisolated var isReadable: Bool { (access ?? 0) & 0x01 != 0 }
    nonisolated var isWritable: Bool { (access ?? 0) & 0x02 != 0 }

    // The custom init(from:) below suppresses Swift's synthesized
    // memberwise initializer, so we restore it explicitly for tests and
    // fixture builders that construct exposes in code.
    nonisolated init(
        type: String,
        name: String?,
        label: String?,
        description: String?,
        access: Int?,
        property: String?,
        endpoint: String?,
        features: [Expose]?,
        options: [Expose]?,
        unit: String?,
        valueMin: Double?,
        valueMax: Double?,
        valueStep: Double?,
        values: [String]?,
        valueOn: JSONValue?,
        valueOff: JSONValue?,
        presets: [ExposePreset]?
    ) {
        self.type = type
        self.name = name
        self.label = label
        self.description = description
        self.access = access
        self.property = property
        self.endpoint = endpoint
        self.features = features
        self.options = options
        self.unit = unit
        self.valueMin = valueMin
        self.valueMax = valueMax
        self.valueStep = valueStep
        self.values = values
        self.valueOn = valueOn
        self.valueOff = valueOff
        self.presets = presets
    }

    enum CodingKeys: String, CodingKey {
        case type, name, label, description, access, property, endpoint, features, options, unit, values, presets
        case valueMin = "value_min"
        case valueMax = "value_max"
        case valueStep = "value_step"
        case valueOn = "value_on"
        case valueOff = "value_off"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        access = try c.decodeIfPresent(Int.self, forKey: .access)
        property = try c.decodeIfPresent(String.self, forKey: .property)
        endpoint = try c.decodeIfPresent(String.self, forKey: .endpoint)
        features = try c.decodeIfPresent([Expose].self, forKey: .features)
        options = try c.decodeIfPresent([Expose].self, forKey: .options)
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        valueMin = try c.decodeIfPresent(Double.self, forKey: .valueMin)
        valueMax = try c.decodeIfPresent(Double.self, forKey: .valueMax)
        valueStep = try c.decodeIfPresent(Double.self, forKey: .valueStep)
        valueOn = try c.decodeIfPresent(JSONValue.self, forKey: .valueOn)
        valueOff = try c.decodeIfPresent(JSONValue.self, forKey: .valueOff)
        presets = try c.decodeIfPresent([ExposePreset].self, forKey: .presets)
        // Real z2m sends enum `values` as strings most of the time, but some
        // device definitions (e.g. Eurotronic SPZB0001 trv_mode) use numbers
        // or booleans. Stringify so consumers can keep treating values as
        // labels.
        if let raw = try c.decodeIfPresent([JSONValue].self, forKey: .values) {
            values = raw.map { v in
                if let s = v.stringValue { return s }
                if let n = v.numberValue { return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n) }
                if let b = v.boolValue { return b ? "true" : "false" }
                return ""
            }
        } else {
            values = nil
        }
    }
}

struct ExposePreset: Codable, Sendable, Equatable {
    let name: String
    let value: JSONValue
}

extension Expose {
    // All exposes in the tree — each node plus its descendants.
    nonisolated var flattened: [Expose] {
        [self] + (features ?? []).flatMap(\.flattened)
    }
}

extension [Expose] {
    // All nodes in the tree (parents + children).
    nonisolated var flattened: [Expose] {
        flatMap(\.flattened)
    }

    // Only leaf nodes — exposes that have no features of their own.
    nonisolated var flattenedLeaves: [Expose] {
        flatMap { e in
            (e.features?.isEmpty == false) ? (e.features ?? []).flattenedLeaves : [e]
        }
    }
}
