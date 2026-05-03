import Foundation

/// One bridge's worth of data for the Home Bridge card. Built from a
/// `BridgeSession` at render time. The card decides single-vs-multi layout
/// based on the number of entries it receives.
struct HomeBridgeCardEntry: Identifiable {
    let id: UUID
    let name: String
    let isFocused: Bool
    let connectionState: ConnectionSessionController.State
    let isWebSocketConnected: Bool
    let isBridgeOnline: Bool
    let info: BridgeInfo?
    let health: BridgeHealth?

    var version: String? { info?.version }
    var commit: String? { info?.commit }
    var coordinatorType: String? { info?.coordinator.type }
    var coordinatorIEEEAddress: String? { info?.coordinator.ieeeAddress }
    var networkChannel: Int? { info?.network?.channel }
    var panID: Int? { info?.network?.panID }
    var restartRequired: Bool { info?.restartRequired ?? false }
    var isPermitJoinActive: Bool { info?.permitJoin ?? false }
    var permitJoinEnd: Int? { info?.permitJoinEnd }

    var isReconnecting: Bool {
        if case .reconnecting = connectionState { return true }
        return false
    }

    var reconnectAttempt: Int {
        if case .reconnecting(let n) = connectionState { return n }
        return 0
    }

}
