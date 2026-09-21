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
        /// Devices whose interview is running, oldest first. Interviews happen
        /// inside a pairing window, so they're shown here rather than as a
        /// separate card stacked under this one.
        var interviewing: [String] = []
        /// The most recent failed interview, until the next join or interview.
        var interviewFailure: String? = nil
    }

    let identifier: String
    let bridgeDisplayName: String

    init(identifier: String, bridgeDisplayName: String) {
        self.identifier = identifier
        self.bridgeDisplayName = bridgeDisplayName
    }
}
