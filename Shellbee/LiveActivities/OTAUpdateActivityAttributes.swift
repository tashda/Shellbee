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

    let identifier: String
}
