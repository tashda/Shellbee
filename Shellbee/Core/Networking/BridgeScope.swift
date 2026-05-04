import Foundation

/// The canonical bridge-scoped read/write surface. Every UI surface that
/// operates on a specific bridge holds a `BridgeScope`; reads go through
/// `store`, writes through `send` / `restart` / `sendOptions`. The bridge id
/// is part of the scope's identity, so code holding a scope cannot
/// accidentally write to the wrong bridge.
///
/// Construct via `AppEnvironment.scope(for:)`. The scope is lenient — it
/// resolves the session lazily on every read/write, so a bridge that
/// disconnects after the scope is created becomes "empty" rather than
/// crashing. UI that needs to react to disconnect should observe
/// `isConnected` / `connectionState`.
@MainActor
struct BridgeScope: Identifiable {
    let bridgeID: UUID
    private weak var environment: AppEnvironment?

    init(bridgeID: UUID, environment: AppEnvironment) {
        self.bridgeID = bridgeID
        self.environment = environment
    }

    var id: UUID { bridgeID }

    /// Live `BridgeSession` for this scope, if the bridge is currently in the
    /// registry. Nil after disconnect — callers should check before assuming
    /// connectivity.
    var session: BridgeSession? {
        environment?.registry.session(for: bridgeID)
    }

    /// The scoped bridge's store. Returns a shared empty store if the bridge
    /// has been removed from the registry — preserves call-site ergonomics
    /// across the disconnect boundary; the empty store carries no devices,
    /// groups, or state, so dependent UI degrades gracefully to empty.
    var store: AppStore {
        session?.store ?? AppStore.empty
    }

    var displayName: String { session?.displayName ?? "" }
    var bridgeInfo: BridgeInfo? { session?.store.bridgeInfo }
    var isConnected: Bool { session?.isConnected ?? false }
    var connectionState: ConnectionSessionController.State {
        session?.connectionState ?? .idle
    }

    /// Send any topic to the scoped bridge. No-op if the bridge isn't in the
    /// registry — the legacy "silently send to focused bridge" fallback is
    /// gone.
    func send(topic: String, payload: JSONValue) {
        session?.controller.send(topic: topic, payload: payload)
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
        guard let store = session?.store else { return }
        guard !store.identifyInProgress.contains(friendlyName) else { return }
        store.identifyInProgress.insert(friendlyName)
        sendDeviceState(friendlyName, payload: .object(["identify": .string("identify")]))
        Task { [weak store] in
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run { _ = store?.identifyInProgress.remove(friendlyName) }
        }
    }

    /// Optimistically rename a device on the scoped bridge.
    func renameDevice(from: String, to: String, homeassistantRename: Bool) {
        guard let store = session?.store else { return }
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

extension AppStore {
    /// Shared empty store used by `BridgeScope` when the underlying bridge
    /// session has been removed (e.g. user disconnected mid-detail). UI
    /// reading from this store shows empty data and recovers when the user
    /// navigates back.
    @MainActor static let empty = AppStore()
}
