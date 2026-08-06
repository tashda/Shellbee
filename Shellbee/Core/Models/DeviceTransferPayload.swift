import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Stable, privacy-conscious representation for copying or dragging a device
/// into another app. Keep this intentionally smaller than `Device`: raw state,
/// connection details, and credentials never belong on the pasteboard.
struct DeviceTransferPayload: Codable, Sendable, Equatable, Transferable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let friendlyName: String
    let ieeeAddress: String
    let model: String?
    let manufacturer: String?
    let deviceType: String
    let bridgeID: UUID?
    let bridgeName: String?

    nonisolated init(device: Device, bridgeID: UUID?, bridgeName: String?) {
        schemaVersion = Self.currentSchemaVersion
        friendlyName = device.friendlyName
        ieeeAddress = device.ieeeAddress
        model = device.definition?.model ?? device.modelId
        manufacturer = device.definition?.vendor ?? device.manufacturer
        deviceType = switch device.type {
        case .router: "Router"
        case .endDevice: "End Device"
        case .coordinator: "Coordinator"
        case .unknown: "Unknown"
        }
        self.bridgeID = bridgeID
        self.bridgeName = bridgeName?.nilIfBlank
    }

    nonisolated var plainText: String {
        var components = [friendlyName, ieeeAddress]
        if let bridgeName {
            components.append("Bridge: \(bridgeName)")
        }
        return components.joined(separator: " — ")
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
        ProxyRepresentation(exporting: \.plainText)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case friendlyName = "friendly_name"
        case ieeeAddress = "ieee_address"
        case model, manufacturer
        case deviceType = "device_type"
        case bridgeID = "bridge_id"
        case bridgeName = "bridge_name"
    }
}

private extension String {
    nonisolated var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
