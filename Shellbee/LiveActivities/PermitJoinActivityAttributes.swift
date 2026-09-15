import ActivityKit
import Foundation

/// Attributes for the finite pairing window. The end date is deliberately
/// part of the state so the system can render a native countdown without the
/// app waking up once per second.
nonisolated struct PermitJoinActivityAttributes: ActivityAttributes, Sendable {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        let joinedCount: Int
        let startedAt: Date
        let endsAt: Date
        let targetName: String?
    }

    let identifier: String
    let bridgeDisplayName: String

    init(identifier: String, bridgeDisplayName: String) {
        self.identifier = identifier
        self.bridgeDisplayName = bridgeDisplayName
    }
}
