import Foundation

/// The bridge name a Live Activity should show: only when the user has more
/// than one bridge to tell apart, otherwise nothing, so single-bridge setups
/// keep the simpler card.
enum LiveActivityBridgeLabel {
    static func name(_ displayName: String) -> String {
        ConnectionHistory.savedBridgeCount > 1 ? displayName : ""
    }
}
