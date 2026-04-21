import Foundation

struct Z2MOperationError: Identifiable, Sendable {
    let id: UUID
    let topic: String
    let message: String
    let timestamp: Date
}
