import Foundation

extension AppStore {
    /// Keep the pairing activity derived from bridge state. This means a
    /// reconnect, bridge/info refresh, or explicit close all converge on the
    /// same visibility decision instead of leaving a stale activity behind.
    func syncPermitJoinLiveActivity() {
        let info = bridgeInfo
        let isOpen = info?.permitJoin == true
        // A window opened elsewhere (the Z2M frontend, another client) never
        // passes through `setPermitJoin`, so reset the count on any
        // closed-to-open transition rather than only on in-app opens.
        if isOpen, !permitJoinWasOpen {
            permitJoinJoinedCount = 0
        }
        permitJoinWasOpen = isOpen
        PermitJoinLiveActivityCoordinator.shared.sync(
            bridgeID: activeBridgeID,
            bridgeDisplayName: LiveActivityBridgeLabel.name(activeBridgeName),
            isOpen: isOpen,
            endMilliseconds: info?.permitJoinEnd,
            targetName: info?.permitJoinTarget,
            joinedCount: permitJoinJoinedCount
        )
    }
}
