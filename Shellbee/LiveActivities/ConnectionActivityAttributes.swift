import ActivityKit
import Foundation

nonisolated struct ConnectionActivityAttributes: ActivityAttributes, Sendable {
    nonisolated public struct ContentState: Codable, Hashable, Sendable {
        nonisolated public enum Phase: String, Codable, Sendable {
            case connecting
            case connected
            case reconnecting
            case failed
            case cancelled
        }
        public var phase: Phase
        public var attempt: Int
        public var maxAttempts: Int
        public var message: String

        public init(phase: Phase, attempt: Int, maxAttempts: Int, message: String) {
            self.phase = phase
            self.attempt = attempt
            self.maxAttempts = maxAttempts
            self.message = message
        }
    }

    public var serverHost: String
    
    public init(serverHost: String) {
        self.serverHost = serverHost
    }
}
