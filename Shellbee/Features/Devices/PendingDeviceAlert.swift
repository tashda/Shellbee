import SwiftUI

enum PendingDeviceAlert: Identifiable {
    case reconfigure(Device)
    case interview(Device)

    var id: String {
        switch self {
        case .reconfigure(let device):
            "reconfigure-\(device.id)"
        case .interview(let device):
            "interview-\(device.id)"
        }
    }

    var title: String {
        switch self {
        case .reconfigure(let device):
            "Reconfigure \(device.friendlyName)?"
        case .interview(let device):
            "Interview \(device.friendlyName)?"
        }
    }

    var message: String {
        switch self {
        case .reconfigure:
            "This re-sends the current Zigbee2MQTT configuration to the device."
        case .interview:
            "This asks Zigbee2MQTT to re-interview the device and refresh its capabilities."
        }
    }

    var confirmTitle: String {
        switch self {
        case .reconfigure:
            "Reconfigure"
        case .interview:
            "Interview"
        }
    }

    var role: ButtonRole? { nil }
}

