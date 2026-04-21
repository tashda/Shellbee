import Foundation

struct OTAUpdateStatus: Codable, Sendable, Equatable, Hashable {
    enum Phase: String, Codable, Sendable {
        case available
        case checking
        case requested
        case scheduled
        case updating
        case idle
    }

    let deviceName: String
    let phase: Phase
    let progress: Double?
    let remaining: Int?

    var isActive: Bool {
        switch phase {
        case .checking, .requested, .scheduled, .updating:
            return true
        case .available, .idle:
            return false
        }
    }

    var sortPriority: Int {
        switch phase {
        case .updating:
            return 0
        case .scheduled:
            return 1
        case .requested, .checking:
            return 2
        case .available, .idle:
            return 3
        }
    }
}
