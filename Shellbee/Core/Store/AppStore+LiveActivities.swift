import Foundation

extension AppStore {
    /// Keep the pairing activity derived from bridge state. This means a
    /// reconnect, bridge/info refresh, or explicit close all converge on the
    /// same visibility decision instead of leaving a stale activity behind.
    func syncPermitJoinLiveActivity() {
        let info = bridgeInfo
        PermitJoinLiveActivityCoordinator.shared.sync(
            bridgeID: activeBridgeID,
            bridgeDisplayName: activeBridgeName,
            isOpen: info?.permitJoin == true,
            endMilliseconds: info?.permitJoinEnd,
            targetName: info?.permitJoinTarget,
            joinedCount: permitJoinJoinedCount
        )
    }
}
