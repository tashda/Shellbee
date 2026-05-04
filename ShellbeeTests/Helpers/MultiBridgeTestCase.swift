import XCTest
@testable import Shellbee

/// Base class for unit tests that exercise `AppEnvironment` / `BridgeRegistry`
/// with one or more `connect(config:)` calls.
///
/// Why this exists: `BridgeRegistry.connect` spawns a background `Task` that
/// dials the bridge over the network. On the CI runner (no reachable bridge)
/// the dial fails, but the Task is still alive when the test finishes; if the
/// next test's `setUp` allocates a fresh env before the prior dial-Task
/// finishes unwinding, the running Task races deallocation of the old session
/// and the runtime crashes with `pointer being freed was not allocated`.
///
/// This base class keeps a list of every `AppEnvironment` / `BridgeRegistry`
/// the test created and `await`s `disconnectAll()` on each in `tearDown`,
/// draining the in-flight Tasks before the next test starts.
@MainActor
class MultiBridgeTestCase: XCTestCase {

    private var liveEnvs: [AppEnvironment] = []
    private var liveRegistries: [BridgeRegistry] = []

    override func setUp() async throws {
        try await super.setUp()
        clearMultiBridgeDefaults()
        ConnectionConfig.clearPersistedSecretsForTests()
    }

    override func tearDown() async throws {
        for env in liveEnvs {
            await env.disconnectAll()
        }
        for registry in liveRegistries {
            await registry.disconnectAll()
        }
        liveEnvs.removeAll()
        liveRegistries.removeAll()
        clearMultiBridgeDefaults()
        ConnectionConfig.clearPersistedSecretsForTests()
        try await super.tearDown()
    }

    // MARK: - Subclass entry points

    /// Construct an `AppEnvironment` whose live sessions will be torn down in
    /// `tearDown`. Use this everywhere a test would otherwise call
    /// `AppEnvironment()` directly.
    func makeEnvironment() -> AppEnvironment {
        let env = AppEnvironment()
        liveEnvs.append(env)
        return env
    }

    /// Construct a `BridgeRegistry` whose live sessions will be torn down in
    /// `tearDown`.
    func makeRegistry(history: ConnectionHistory) -> BridgeRegistry {
        let registry = BridgeRegistry(history: history)
        liveRegistries.append(registry)
        return registry
    }

    // MARK: - Defaults hygiene

    private func clearMultiBridgeDefaults() {
        for key in [
            "connectionHistory",
            "savedBridges.defaultID",
            "savedBridges.autoConnectIDs",
            "AppStore.deviceFirstSeenByBridge",
            "AppStore.deviceFirstSeen",
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
