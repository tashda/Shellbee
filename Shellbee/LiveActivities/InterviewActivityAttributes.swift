import ActivityKit
import Foundation

nonisolated struct InterviewActivityAttributes: ActivityAttributes, Sendable {
    nonisolated public struct ContentState: Codable, Hashable, Sendable {
        nonisolated public enum Phase: String, Codable, Sendable {
            case interviewing
            case successful
            case failed
        }
        public var phase: Phase

        public init(phase: Phase) {
            self.phase = phase
        }
    }

    public var deviceName: String
    public var ieeeAddress: String

    public init(deviceName: String, ieeeAddress: String) {
        self.deviceName = deviceName
        self.ieeeAddress = ieeeAddress
    }
}
