import ActivityKit
import Foundation

nonisolated struct BridgeOperationActivityAttributes: ActivityAttributes, Sendable {
    nonisolated enum Operation: String, Codable, Sendable {
        case touchlinkScan
        case touchlinkIdentify
    }

    nonisolated struct ContentState: Codable, Hashable, Sendable {
        nonisolated enum Phase: String, Codable, Sendable {
            case active
            case completed
            case failed
        }

        let phase: Phase
        let detail: String
        let foundCount: Int
        let startedAt: Date
        let endsAt: Date
    }

    let identifier: String
    let operation: Operation
    let bridgeDisplayName: String
    let deviceName: String?

    init(
        identifier: String,
        operation: Operation,
        bridgeDisplayName: String,
        deviceName: String? = nil
    ) {
        self.identifier = identifier
        self.operation = operation
        self.bridgeDisplayName = bridgeDisplayName
        self.deviceName = deviceName
    }
}
