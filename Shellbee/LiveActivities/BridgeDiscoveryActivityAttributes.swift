import ActivityKit
import Foundation

nonisolated struct BridgeDiscoveryActivityAttributes: ActivityAttributes, Sendable {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        let foundCount: Int
        let startedAt: Date
        let endsAt: Date
    }

    let identifier: String

    init(identifier: String = "bridge-discovery") {
        self.identifier = identifier
    }
}
