import Foundation

/// Owns the set of live `BridgeSession`s. Multiple bridges connect concurrently;
/// each session manages its own WebSocket and store. The registry exposes a
/// `primaryBridgeID` pointer that the UI binds to as the "focus" — the bridge
/// whose data the legacy single-bridge UI surfaces. Changing focus does NOT
/// disconnect any session; it just rebinds the published primary store.
@Observable
@MainActor
final class BridgeRegistry {
    private(set) var sessions: [UUID: BridgeSession] = [:]
    /// The bridge whose data the legacy single-bridge UI surfaces. Changes
    /// instantly when the user picks a different bridge in the toolbar — no
    /// reconnect, no data loss.
    var primaryBridgeID: UUID?

    private let history: ConnectionHistory

    init(history: ConnectionHistory) {
        self.history = history
    }

    /// Connect to `config`. If a session for that bridge id already exists,
    /// reuse it (and update its config snapshot if needed) — this is what the
    /// "retry from lost" path does. Otherwise spin up a fresh session. Existing
    /// sessions are untouched: connecting a new bridge never tears down others.
    func connect(config: ConnectionConfig) {
        if let existing = sessions[config.id] {
            existing.config = config
            existing.controller.connect(config: config)
            return
        }

        let session = BridgeSession(config: config, history: history)
        sessions[config.id] = session
        // First session becomes primary by default. Subsequent connects keep
        // the existing primary unless the caller explicitly switches focus.
        if primaryBridgeID == nil {
            primaryBridgeID = session.bridgeID
        }
        session.controller.connect(config: config)
    }

    /// Tear down a single bridge's session. The other bridges stay connected.
    /// If the disconnected bridge was the primary, focus shifts to whichever
    /// remaining session is currently connected (or any if none).
    func disconnect(bridgeID: UUID) async {
        guard let session = sessions[bridgeID] else { return }
        await session.controller.disconnect()
        sessions.removeValue(forKey: bridgeID)

        if primaryBridgeID == bridgeID {
            primaryBridgeID = sessions.values.first(where: { $0.isConnected })?.bridgeID
                ?? sessions.values.first?.bridgeID
        }
    }

    /// Disconnect every active session. Used on full-app sign-out / forget.
    func disconnectAll() async {
        for session in sessions.values {
            await session.controller.disconnect()
        }
        sessions.removeAll()
        primaryBridgeID = nil
    }

    /// Look up a session by id.
    func session(for bridgeID: UUID) -> BridgeSession? {
        sessions[bridgeID]
    }

    /// The currently focused session — the one the legacy single-bridge UI
    /// reads from.
    var primary: BridgeSession? {
        guard let primaryBridgeID else { return nil }
        return sessions[primaryBridgeID]
    }

    /// Stable, name-sorted list of all live sessions. Used by the saved-bridges
    /// screen and by the focus picker so order doesn't jitter as sessions
    /// connect/disconnect.
    var orderedSessions: [BridgeSession] {
        sessions.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    /// Set focus to `bridgeID`. No-op if that bridge isn't currently connected.
    func setPrimary(_ bridgeID: UUID) {
        guard sessions[bridgeID] != nil else { return }
        primaryBridgeID = bridgeID
    }
}
