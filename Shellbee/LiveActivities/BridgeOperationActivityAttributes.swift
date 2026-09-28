import ActivityKit
import Foundation

nonisolated struct BridgeOperationActivityAttributes: ActivityAttributes, Sendable {
    nonisolated enum Operation: String, Codable, Sendable {
        case touchlinkScan
        case touchlinkIdentify
        case otaCheck
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
        /// Check All for Updates: devices checked, in total, and that
        /// didn't answer. `foundCount` holds updates found.
        var completedCount = 0
        var totalCount = 0
        var failedCount = 0
        /// The app's theme when this content was sent; see
        /// `LiveActivityAppearance`. Optional so older content still decodes.
        var appearance: LiveActivityAppearance? = .current
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
