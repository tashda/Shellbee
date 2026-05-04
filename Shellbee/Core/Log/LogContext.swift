import Foundation

struct LogContext: Sendable {
    let devices: [DeviceRef]
    let stateChanges: [StateChange]
    let action: LogAction
    /// Full state snapshot at the moment the log entry was emitted. Set on
    /// synthesized state-change entries so LogDetailView can populate the
    /// hero card with every relevant field (brightness, color, color_temp,
    /// …) instead of only the changed properties.
    let payload: [String: JSONValue]?

    var primaryDevice: DeviceRef? { devices.first }
    var hasMultipleDevices: Bool { devices.count > 1 }

    init(
        devices: [DeviceRef],
        stateChanges: [StateChange],
        action: LogAction,
        payload: [String: JSONValue]? = nil
    ) {
        self.devices = devices
        self.stateChanges = stateChanges
        self.action = action
        self.payload = payload
    }

    var inferredCategory: LogCategory {
        if case .stateChange = action { return .stateChange }
        return .general
    }

    // MARK: - DeviceRef

    struct DeviceRef: Sendable {
        let friendlyName: String
        let role: Role?

        enum Role: Sendable {
            case subject, source, target
            var label: String {
                switch self {
                case .subject: return "Subject"
                case .source: return "Source"
                case .target: return "Target"
                }
            }
        }
    }

    // MARK: - StateChange

    struct StateChange: Identifiable, Sendable {
        let id: UUID
        let property: String
        let from: JSONValue?
        let to: JSONValue
        let displayLabel: String
        let displayFrom: String?
        let displayTo: String

        var shortDescription: String {
            if let from = displayFrom {
                return "\(displayLabel): \(from) → \(displayTo)"
            }
            return "\(displayLabel): \(displayTo)"
        }
    }

    // MARK: - LogAction

    enum LogAction: Sendable {
        case mqttPublish
        case bridgeResponse
        case stateChange
        case bindSuccess, bindFailure, unbind
        case groupAdd, groupRemove
        case publishFailure(command: String)
        case requestFailure
        case otaProgress(percent: Int)
        case otaFinished
        case reportingConfigure
        case general
    }
}
