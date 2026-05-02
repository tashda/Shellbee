import Foundation

/// A single bridge's full live state: its config, its WebSocket controller,
/// and its dedicated `AppStore`. One `BridgeSession` per saved-bridge that the
/// user has connected. Multiple sessions run concurrently — the registry
/// (`BridgeRegistry`) owns N of them, and the UI is "focused" on one at a
/// time via the registry's `primaryBridgeID`. Switching focus does not
/// teardown a session.
@Observable
@MainActor
final class BridgeSession {
    let bridgeID: UUID
    var config: ConnectionConfig
    let store: AppStore
    let controller: ConnectionSessionController

    init(config: ConnectionConfig, history: ConnectionHistory) {
        self.bridgeID = config.id
        self.config = config
        self.store = AppStore()
        self.controller = ConnectionSessionController(
            store: store,
            history: history,
            bridgeID: config.id
        )
    }

    var connectionState: ConnectionSessionController.State {
        controller.connectionState
    }

    var isConnected: Bool {
        controller.connectionState.isConnected
    }

    var displayName: String {
        config.name?.isEmpty == false ? config.name! : config.host
    }
}
