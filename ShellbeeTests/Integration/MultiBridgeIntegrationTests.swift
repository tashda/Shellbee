import XCTest
import Network
@testable import Shellbee

/// Integration tests that connect to TWO real Z2M instances concurrently
/// (the dual-bridge mock stack on `localhost:8080` and `localhost:8082`).
///
/// To run: start the dual stack first:
///   docker compose up -d
/// or, on the GitHub macOS runner:
///   MULTI_BRIDGE=1 ./.github/scripts/start-mock-bridge.sh
///
/// Verifies the wire-level guarantees the multi-bridge UX depends on:
/// each bridge delivers its own `bridge/info` and device list, and the two
/// device lists do not bleed into each other (the secondary seeder's
/// `FIXTURE_PREFIX=Lab` makes friendly names visibly distinct).
///
/// If either bridge is unreachable, every test in this file is skipped.
final class MultiBridgeIntegrationTests: XCTestCase, @unchecked Sendable {

    static let primaryHost = "localhost"
    static let primaryPort = 8080
    static let primaryToken = "shellbee-integration-token"

    static let secondaryHost = "localhost"
    static let secondaryPort = 8082
    static let secondaryToken = "shellbee-integration-token-2"

    override func setUp() async throws {
        try await super.setUp()
        try await skipIfDualStackUnavailable()
    }

    // MARK: - Wire-level isolation

    /// Both bridges accept independent connections and each delivers its
    /// own `bridge/info`. This is the floor of multi-bridge support.
    @MainActor
    func testBothBridgesDeliverBridgeInfoConcurrently() async throws {
        async let primaryInfo = collectBridgeInfo(for: primaryConfig(), timeout: 15)
        async let secondaryInfo = collectBridgeInfo(for: secondaryConfig(), timeout: 15)

        let (a, b) = try await (primaryInfo, secondaryInfo)
        XCTAssertNotNil(a, "primary bridge did not deliver bridge/info")
        XCTAssertNotNil(b, "secondary bridge did not deliver bridge/info")
        XCTAssertFalse(a?.version.isEmpty ?? true)
        XCTAssertFalse(b?.version.isEmpty ?? true)
    }

    /// Devices from each bridge land in that bridge's own store and do
    /// not leak into the other. The secondary seeder runs with
    /// `FIXTURE_PREFIX=Lab`, so every friendly name on the secondary
    /// bridge starts with "Lab " — primary-bridge names never do.
    @MainActor
    func testDeviceListsAreIsolatedBetweenBridges() async throws {
        async let primary = collectDevices(for: primaryConfig(), timeout: 20)
        async let secondary = collectDevices(for: secondaryConfig(), timeout: 20)

        let (primaryDevices, secondaryDevices) = try await (primary, secondary)

        XCTAssertFalse(primaryDevices.isEmpty,   "primary bridge devices not received")
        XCTAssertFalse(secondaryDevices.isEmpty, "secondary bridge devices not received")

        let primaryNames   = Set(primaryDevices.map(\.friendlyName))
        let secondaryNames = Set(secondaryDevices.map(\.friendlyName))

        // The IEEEs are salted on the secondary stack, so addresses must differ.
        let primaryIEEEs   = Set(primaryDevices.map(\.ieeeAddress))
        let secondaryIEEEs = Set(secondaryDevices.map(\.ieeeAddress))
        XCTAssertTrue(primaryIEEEs.intersection(secondaryIEEEs).isEmpty,
                      "IEEE addresses leaked across bridges (\(primaryIEEEs.intersection(secondaryIEEEs)))")

        // FIXTURE_PREFIX=Lab on the secondary seeder means every friendly
        // name on bridge 2 starts with "Lab "; none on bridge 1 should.
        XCTAssertTrue(secondaryNames.allSatisfy { $0.hasPrefix("Lab ") },
                      "secondary bridge names should all be prefixed 'Lab ': \(secondaryNames)")
        XCTAssertTrue(primaryNames.allSatisfy { !$0.hasPrefix("Lab ") },
                      "primary bridge names should not carry the Lab prefix: \(primaryNames)")
    }

    // MARK: - Helpers

    @MainActor
    private func primaryConfig() -> ConnectionConfig {
        ConnectionConfig(host: Self.primaryHost, port: Self.primaryPort,
                         useTLS: false, basePath: "/", authToken: Self.primaryToken)
    }

    @MainActor
    private func secondaryConfig() -> ConnectionConfig {
        ConnectionConfig(host: Self.secondaryHost, port: Self.secondaryPort,
                         useTLS: false, basePath: "/", authToken: Self.secondaryToken)
    }

    @MainActor
    private func collectBridgeInfo(for config: ConnectionConfig, timeout: TimeInterval) async throws -> BridgeInfo? {
        let client = Z2MWebSocketClient()
        let router = Z2MMessageRouter()
        let url = try XCTUnwrap(config.webSocketURL)
        let stream = try await client.connect(url: url)

        let deadline = Date().addingTimeInterval(timeout)
        for await socketEvent in stream {
            guard case .message(let data) = socketEvent else { continue }
            if let event = router.route(data), case .bridgeInfo(let info) = event {
                await client.disconnect()
                return info
            }
            if Date() > deadline { break }
        }
        await client.disconnect()
        return nil
    }

    @MainActor
    private func collectDevices(for config: ConnectionConfig, timeout: TimeInterval) async throws -> [Device] {
        let client = Z2MWebSocketClient()
        let router = Z2MMessageRouter()
        let url = try XCTUnwrap(config.webSocketURL)
        let stream = try await client.connect(url: url)

        let deadline = Date().addingTimeInterval(timeout)
        for await socketEvent in stream {
            guard case .message(let data) = socketEvent else { continue }
            if let event = router.route(data), case .devices(let list) = event {
                await client.disconnect()
                return list
            }
            if Date() > deadline { break }
        }
        await client.disconnect()
        return []
    }

    private func skipIfDualStackUnavailable() async throws {
        async let p = ping(host: Self.primaryHost, port: Self.primaryPort)
        async let s = ping(host: Self.secondaryHost, port: Self.secondaryPort)
        let (primaryUp, secondaryUp) = await (p, s)
        guard primaryUp, secondaryUp else {
            throw XCTSkip("""
            Dual-bridge mock stack not running. Start with:
              docker compose up -d
            or on GitHub Actions:
              MULTI_BRIDGE=1 ./.github/scripts/start-mock-bridge.sh
            primary=\(primaryUp ? "up" : "down") secondary=\(secondaryUp ? "up" : "down")
            """)
        }
    }

    private func ping(host: String, port: Int) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let conn = NWConnection(host: NWEndpoint.Host(host),
                                    port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                                    using: .tcp)
            let resumed = ManagedAtomicBool(false)
            let resumeOnce: @Sendable (Bool) -> Void = { value in
                if resumed.compareExchange(expected: false, desired: true) {
                    cont.resume(returning: value)
                }
            }
            let timer = DispatchSource.makeTimerSource(queue: .global())
            timer.schedule(deadline: .now() + 3)
            timer.setEventHandler {
                conn.cancel()
                timer.cancel()
                resumeOnce(false)
            }
            timer.resume()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timer.cancel()
                    conn.cancel()
                    resumeOnce(true)
                case .failed, .cancelled:
                    timer.cancel()
                    resumeOnce(false)
                default: break
                }
            }
            conn.start(queue: .global())
        }
    }
}

/// Tiny atomic-bool wrapper used to guard `cont.resume` so the timer + state
/// callbacks can race without double-resuming the continuation.
private final class ManagedAtomicBool: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool
    init(_ initial: Bool) { value = initial }
    func compareExchange(expected: Bool, desired: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if value == expected { value = desired; return true }
        return false
    }
}
