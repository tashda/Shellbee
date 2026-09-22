import Foundation

enum NetworkMapRefreshPhase: Equatable, Sendable {
    case idle
    case requesting
    case building(deviceCount: Int)
    case completed(NetworkMapScanSummary)
    case failed(message: String)
}
