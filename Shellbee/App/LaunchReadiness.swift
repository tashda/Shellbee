import Foundation

/// Whether the app has what it needs to show Home after launch, so the
/// splash covers the connect burst instead of lifting into it.
enum LaunchReadiness {
    /// The splash never stays longer than this; a slow or unreachable
    /// bridge fills in after it lifts, as it did before.
    static let maximumWait: TimeInterval = 4
    /// The connect burst counts as done once no message has arrived for
    /// this long.
    static let quietPeriod: TimeInterval = 0.3
    /// Shortest time the splash stays up once shown, so a fast launch
    /// finishes the icon's fade-in instead of flickering past it.
    static let minimumSplash: TimeInterval = 0.6

    /// Ready once every bridge still trying to connect has sent its info
    /// and device list and gone quiet. Bridges that failed or aren't
    /// connecting don't hold the splash.
    @MainActor
    static func isReady(_ sessions: [BridgeSession], now: Date = .now) -> Bool {
        sessions.allSatisfy { session in
            switch session.connectionState {
            case .idle, .failed, .lost:
                return true
            case .connecting, .reconnecting:
                return false
            case .connected:
                let store = session.store
                guard store.hasReceivedDevices, store.bridgeInfo != nil else { return false }
                guard let last = session.controller.lastInboundAt else { return true }
                return now.timeIntervalSince(last) >= quietPeriod
            }
        }
    }

    /// Devices loaded so far, for the splash's status line.
    @MainActor
    static func loadedDeviceCount(_ sessions: [BridgeSession]) -> Int {
        sessions.reduce(0) { $0 + $1.store.devices.count }
    }
}
