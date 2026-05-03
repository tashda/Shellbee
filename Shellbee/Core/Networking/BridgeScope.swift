import Foundation

/// A bridge-scoped read/write surface — the canonical way to address one
/// specific bridge from the UI. Every read goes through `store`; every write
/// goes through this scope's `send` / `restart` / `sendOptions` and routes
/// to the wrapped session's controller.
///
/// `BridgeScope` is the multi-bridge migration's answer to the legacy
/// `environment.store` / `environment.send(topic:)` shims, which silently
/// targeted "the focused bridge". Code that holds a `BridgeScope` cannot
/// accidentally write to the wrong bridge — the bridge id is part of the
/// scope's identity.
///
/// Construct via `AppEnvironment.scope(for:)`. The scope captures the session
/// at construction time; if the session disappears (user disconnects that
/// bridge), reads/writes become no-ops on a stale store. UI that holds a
/// scope across a bridge disconnect should observe `session.isConnected` and
/// react accordingly.
@MainActor
struct BridgeScope: Identifiable {
    let bridgeID: UUID
    let session: BridgeSession
    private weak var environment: AppEnvironment?

    init(bridgeID: UUID, session: BridgeSession, environment: AppEnvironment) {
        self.bridgeID = bridgeID
        self.session = session
        self.environment = environment
    }

    var id: UUID { bridgeID }

    var store: AppStore { session.store }
    var displayName: String { session.displayName }
    var bridgeInfo: BridgeInfo? { store.bridgeInfo }
    var isConnected: Bool { session.isConnected }
    var connectionState: ConnectionSessionController.State { session.connectionState }

    /// Send any topic to the scoped bridge.
    func send(topic: String, payload: JSONValue) {
        session.controller.send(topic: topic, payload: payload)
    }

    /// Send a `bridge/request/options` request with the `{"options": {...}}`
    /// envelope Z2M expects.
    func sendOptions(_ options: [String: JSONValue]) {
        send(topic: Z2MTopics.Request.options, payload: .object(["options": .object(options)]))
    }

    /// Restart the scoped bridge.
    func restart() {
        send(topic: Z2MTopics.Request.restart, payload: .string(""))
    }

    /// Set a device's state on the scoped bridge.
    func sendDeviceState(_ friendlyName: String, payload: JSONValue) {
        send(topic: Z2MTopics.deviceSet(friendlyName), payload: payload)
    }

    /// Ask a device to physically identify itself. De-dupes against the
    /// scoped store's `identifyInProgress` set so rapid taps don't flood the
    /// network.
    func identifyDevice(_ friendlyName: String) {
        guard !store.identifyInProgress.contains(friendlyName) else { return }
        store.identifyInProgress.insert(friendlyName)
        sendDeviceState(friendlyName, payload: .object(["identify": .string("identify")]))
        let store = self.store
        Task { [weak store] in
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run { _ = store?.identifyInProgress.remove(friendlyName) }
        }
    }

    /// Optimistically rename a device on the scoped bridge.
    func renameDevice(from: String, to: String, homeassistantRename: Bool) {
        let trimmed = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != from else { return }
        store.optimisticRename(from: from, to: trimmed)
        send(topic: Z2MTopics.Request.deviceRename, payload: .object([
            "from": .string(from),
            "to": .string(trimmed),
            "homeassistant_rename": .bool(homeassistantRename)
        ]))
    }
}
