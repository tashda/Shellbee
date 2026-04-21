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
    let supportsOTA: Bool
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

    var isReadable: Bool { (access ?? 0) & 0x01 != 0 }
    var isWritable: Bool { (access ?? 0) & 0x02 != 0 }

    enum CodingKeys: String, CodingKey {
        case type, name, label, description, access, property, endpoint, features, options, unit, values, presets
        case valueMin = "value_min"
        case valueMax = "value_max"
        case valueStep = "value_step"
        case valueOn = "value_on"
        case valueOff = "value_off"
    }
}

struct ExposePreset: Codable, Sendable, Equatable {
    let name: String
    let value: JSONValue
}
