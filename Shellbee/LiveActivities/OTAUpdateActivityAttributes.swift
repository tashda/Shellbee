import ActivityKit
import Foundation

nonisolated struct OTAUpdateActivityAttributes: ActivityAttributes, Sendable {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        nonisolated enum Phase: String, Codable, Sendable {
            case active
            case completed
            case failed
        }

        nonisolated struct Item: Codable, Hashable, Sendable {
            let name: String
            let phase: OTAUpdateStatus.Phase
            let progress: Int?
            let remaining: Int?
            let categorySymbol: String?
        }

        let phase: Phase
        let activeCount: Int
        let headline: String
        let detail: String
        let progress: Int?
        let items: [Item]
    }

    /// Stable per-bridge identifier (e.g. `"ota-updates-<UUID>"`). Multi-bridge:
    /// every connected bridge gets its own OTA activity so simultaneous OTA
    /// runs on different bridges don't collide on a single activity slot.
    let identifier: String
    /// Friendly bridge name shown on the lock-screen / Dynamic Island so the
    /// user can tell which network's upgrade they're looking at. Optional —
    /// older activities decoded without this fall back to an empty string.
    var bridgeDisplayName: String

    init(identifier: String, bridgeDisplayName: String = "") {
        self.identifier = identifier
        self.bridgeDisplayName = bridgeDisplayName
    }

    enum CodingKeys: String, CodingKey {
        case identifier
        case bridgeDisplayName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try c.decode(String.self, forKey: .identifier)
        bridgeDisplayName = try c.decodeIfPresent(String.self, forKey: .bridgeDisplayName) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(identifier, forKey: .identifier)
        try c.encode(bridgeDisplayName, forKey: .bridgeDisplayName)
    }
}
