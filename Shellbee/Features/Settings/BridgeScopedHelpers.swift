import Foundation

/// Helpers used by per-bridge Settings views. Each view takes an optional
/// `bridgeID`; when nil it falls back to the focused bridge (preserving the
/// pre-multi-bridge contract). When non-nil it scopes reads to that bridge's
/// store and routes writes to that bridge's WebSocket.
extension AppEnvironment {
    /// Resolve the right `(store, sendOptions, send)` triple for a per-bridge
    /// Settings view. `bridgeID` may be nil — the focused bridge is used.
    @MainActor
    func bridgeScope(_ bridgeID: UUID?) -> BridgeScopeBindings {
        BridgeScopeBindings(environment: self, bridgeID: bridgeID)
    }
}

/// Lightweight wrapper that gives Settings views a bridge-scoped read/write
/// surface without each view re-implementing the resolve-or-fallback logic.
@MainActor
struct BridgeScopeBindings {
    let environment: AppEnvironment
    let bridgeID: UUID?

    var store: AppStore {
        if let bridgeID, let session = environment.registry.session(for: bridgeID) {
            return session.store
        }
        return environment.store
    }

    var session: BridgeSession? {
        bridgeID.flatMap { environment.registry.session(for: $0) }
    }

    var bridgeInfo: BridgeInfo? { store.bridgeInfo }

    /// Send a `bridge/request/options` envelope to the scoped bridge.
    func sendOptions(_ options: [String: JSONValue]) {
        if let bridgeID {
            environment.sendBridgeOptions(options, to: bridgeID)
        } else {
            environment.sendBridgeOptions(options)
        }
    }

    /// Send an arbitrary topic to the scoped bridge.
    func send(topic: String, payload: JSONValue) {
        if let bridgeID {
            environment.send(bridge: bridgeID, topic: topic, payload: payload)
        } else {
            environment.send(topic: topic, payload: payload)
        }
    }

    /// Restart the scoped bridge.
    func restart() {
        if let bridgeID {
            environment.restartBridge(bridgeID)
        } else {
            environment.restartBridge()
        }
    }

    /// True when the scoped bridge currently holds an active connection.
    /// Used by per-bridge Settings to disable Apply buttons while offline.
    var isConnected: Bool {
        if let bridgeID {
            return session?.isConnected ?? false
        }
        return environment.connectionState.isConnected
    }
}
