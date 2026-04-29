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

        /// How long after a device first joins the network it shows the
        /// "Recently Added" badge in the device list. 30 minutes covers
        /// most pairing → naming → first-test workflows without lingering
        /// on the homepage forever.
        static let recentDeviceWindow: TimeInterval = 30 * 60
    }
}
