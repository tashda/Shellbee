import Foundation

/// Tunable values that shape app behavior — networking timeouts, UX
/// windows, retry budgets, etc. These are *behavior tokens*, distinct from
/// `DesignTokens` (visual). Today they're static defaults; over time some
/// will be exposed in Settings as user-configurable.
///
/// Add new values to a topical sub-enum (Networking, UX, …) rather than
/// the top level so this file stays browsable.
nonisolated enum AppConfig {

    /// WebSocket / discovery / network-layer timeouts and retry budgets.
    nonisolated enum Networking {
        /// Hard cap on how long we wait for the WebSocket handshake to
        /// complete before giving up and surfacing a connection failure.
        static let websocketConnectionTimeout: TimeInterval = 10

        /// After the WebSocket opens, how long to wait for the first
        /// inbound frame before treating the connection as silent / stuck.
        /// Z2M sends `bridge/info` immediately on connect, so a 5s window
        /// covers slow networks without making genuine breakage feel laggy.
        static let websocketFirstMessageTimeout: TimeInterval = 5

        /// How long the discovery service probes a candidate host:port
        /// before declaring it unreachable. Short enough to scan a /24 in
        /// a reasonable wall-clock time when most addresses don't answer.
        static let discoveryProbeTimeout: TimeInterval = 1.5
    }

    /// UX-tuning windows that aren't visual (durations, coalescing, recency).
    nonisolated enum UX {
        /// Notifications with the same `coalesceKey` arriving within this
        /// window collapse into a single banner with a `× N` count badge.
        /// Tuned so a burst of related events (e.g. an interview producing
        /// multiple log lines) reads as one notification, not four.
        static let notificationCoalesceWindow: TimeInterval = 1.5

        /// Default window after a device first joins the network during
        /// which it appears in the "Recently Added" section of the device
        /// list. User-overridable via Settings → General; this default
        /// covers most pairing → naming → first-test workflows without
        /// lingering forever.
        static let recentDeviceWindow: TimeInterval = recentDeviceWindowDefaultMinutes * 60

        /// User-facing key + options for the Recently-Added window picker
        /// in Settings → General. Stored as minutes. To hide the section
        /// entirely the user toggles "Show Recents" off in the device
        /// list's Sort menu — that's the single source of truth for
        /// visibility, this picker only controls the window length.
        static let recentDeviceWindowKey = "DeviceList.recentWindowMinutes"
        static let recentDeviceWindowDefaultMinutes: TimeInterval = 30
        static let recentDeviceWindowOptionsMinutes: [Int] = [5, 15, 30, 60, 120, 240, 1440]

        /// Resolves the active window (in seconds) honoring the user's
        /// stored preference if any, falling back to the default.
        static var configuredRecentDeviceWindow: TimeInterval {
            let raw = UserDefaults.standard.object(forKey: recentDeviceWindowKey) as? Int
            let minutes = raw.map(TimeInterval.init) ?? recentDeviceWindowDefaultMinutes
            return minutes * 60
        }
    }
}
