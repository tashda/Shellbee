import Foundation

struct LogContext: Sendable {
    let devices: [DeviceRef]
    let stateChanges: [StateChange]
    let action: LogAction

    var primaryDevice: DeviceRef? { devices.first }
    var hasMultipleDevices: Bool { devices.count > 1 }

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
