import XCTest
@testable import Shellbee

/// Integration tests that connect to a real Zigbee2MQTT instance running in Docker.
///
/// To run: start the Docker stack first:
///   docker compose up -d
///
/// If Z2M is not reachable on localhost:8080, all tests are skipped automatically.
final class Z2MIntegrationTests: XCTestCase, @unchecked Sendable {

    static let z2mHost = "localhost"
    static let z2mPort = 8080

    var store: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        store = await MainActor.run { AppStore() }
        try await skipIfZ2MUnavailable()
    }

    override func tearDown() async throws {
        await MainActor.run { store = nil }
        try await super.tearDown()
    }

    // MARK: - Connection

    @MainActor
    func testConnectsAndReceivesBridgeInfo() async throws {
        let (client, router) = makeClientAndRouter()
        let url = try XCTUnwrap(connectionConfig().webSocketURL)
        try await client.connect(url: url)

        let info = try await collectFirst(from: client, router: router, timeout: 15) { event in
            if case .bridgeInfo(let i) = event { return i }
            return nil
        }

        await client.disconnect()
        XCTAssertNotNil(info)
        XCTAssertFalse(info?.version.isEmpty ?? true)
    }

    @MainActor
    func testReceivesBridgeDevices() async throws {
        let (client, router) = makeClientAndRouter()
        let url = try XCTUnwrap(connectionConfig().webSocketURL)
        try await client.connect(url: url)

        let devices = try await collectFirst(from: client, router: router, timeout: 20) { event in
            if case .devices(let d) = event { return d }
            return nil
        }

        await client.disconnect()
        let list = try XCTUnwrap(devices)
        XCTAssertGreaterThanOrEqual(list.count, 1)
        XCTAssertTrue(list.contains { $0.type == .coordinator })
    }

    @MainActor
    func testReceivesAllSeededDeviceCategories() async throws {
        let (client, router) = makeClientAndRouter()
        let url = try XCTUnwrap(connectionConfig().webSocketURL)
        try await client.connect(url: url)

        let devices = try await collectFirst(from: client, router: router, timeout: 30) { event in
            if case .devices(let d) = event { return d }
            return nil
        }
        await client.disconnect()

        let nonCoordinator = (devices ?? []).filter { $0.type != .coordinator }
        let categories = Set(nonCoordinator.map(\.category))

        let expected: Set<Device.Category> = [.light, .switchPlug, .sensor, .climate, .cover, .lock, .fan, .remote]
        XCTAssertTrue(expected.isSubset(of: categories),
                      "Missing categories: \(expected.subtracting(categories))")
    }

    @MainActor
    func testReceivesDeviceAvailability() async throws {
        let (client, router) = makeClientAndRouter()
        let url = try XCTUnwrap(connectionConfig().webSocketURL)
        try await client.connect(url: url)

        let got = try await collectFirst(from: client, router: router, timeout: 30) { event -> Bool? in
            if case .deviceAvailability = event { return true }
            return nil
        }
        await client.disconnect()
        XCTAssertTrue(got ?? false, "No availability message received")
    }

    @MainActor
    func testReceivesDeviceStates() async throws {
        let (client, router) = makeClientAndRouter()
        let url = try XCTUnwrap(connectionConfig().webSocketURL)
        try await client.connect(url: url)

        var count = 0
        let deadline = Date().addingTimeInterval(30)
        for await socketEvent in await client.events {
            guard case .message(let data) = socketEvent else { break }
            if let event = router.route(data), case .deviceState = event {
                count += 1
                if count >= 3 { break }
            }
            if Date() > deadline { break }
        }

        await client.disconnect()
        XCTAssertGreaterThanOrEqual(count, 3, "Expected ≥3 device state messages")
    }

    @MainActor
    func testReceivesGroups() async throws {
        let (client, router) = makeClientAndRouter()
        let url = try XCTUnwrap(connectionConfig().webSocketURL)
        try await client.connect(url: url)

        let groups = try await collectFirst(from: client, router: router, timeout: 20) { event in
            if case .groups(let g) = event { return g }
            return nil
        }
        await client.disconnect()

        let list = try XCTUnwrap(groups)
        XCTAssertGreaterThanOrEqual(list.count, 1)
    }

    @MainActor
    func testFullHydrationFlowPopulatesStore() async throws {
        let (client, router) = makeClientAndRouter()
        let url = try XCTUnwrap(connectionConfig().webSocketURL)
        try await client.connect(url: url)

        var gotInfo = false, gotDevices = false, gotGroups = false
        let deadline = Date().addingTimeInterval(30)

        for await socketEvent in await client.events {
            guard case .message(let data) = socketEvent else { break }
            if let event = router.route(data) {
                store.apply(event)
                switch event {
                case .bridgeInfo:  gotInfo    = true
                case .devices:     gotDevices = true
                case .groups:      gotGroups  = true
                default: break
                }
            }
            if gotInfo && gotDevices && gotGroups { break }
            if Date() > deadline { break }
        }

        await client.disconnect()

        XCTAssertTrue(gotInfo,    "bridge/info not received")
        XCTAssertTrue(gotDevices, "bridge/devices not received")
        XCTAssertTrue(gotGroups,  "bridge/groups not received")
        XCTAssertNotNil(store.bridgeInfo)
        XCTAssertFalse(store.devices.isEmpty)
        XCTAssertFalse(store.groups.isEmpty)
    }

    // MARK: - Helpers

    @MainActor
    private func connectionConfig() -> ConnectionConfig {
        ConnectionConfig(host: Self.z2mHost, port: Self.z2mPort,
                         useTLS: false, basePath: "/", authToken: nil)
    }

    @MainActor
    private func makeClientAndRouter() -> (Z2MWebSocketClient, Z2MMessageRouter) {
        (Z2MWebSocketClient(), Z2MMessageRouter())
    }

    @MainActor
    private func collectFirst<T>(
        from client: Z2MWebSocketClient,
        router: Z2MMessageRouter,
        timeout: TimeInterval,
        transform: (Z2MEvent) -> T?
    ) async throws -> T? {
        let deadline = Date().addingTimeInterval(timeout)
        for await socketEvent in await client.events {
            guard case .message(let data) = socketEvent else { return nil }
            if let event = router.route(data), let value = transform(event) {
                return value
            }
            if Date() > deadline { return nil }
        }
        return nil
    }

    private func skipIfZ2MUnavailable() async throws {
        let maybeURL = await MainActor.run { connectionConfig().webSocketURL }
        guard let url = maybeURL else {
            throw XCTSkip("Cannot construct Z2M URL")
        }
        let client = await MainActor.run { Z2MWebSocketClient() }
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await client.connect(url: url) }
                group.addTask {
                    try await Task.sleep(for: .seconds(5))
                    throw URLError(.timedOut)
                }
                try await group.next()
                group.cancelAll()
            }
            await client.disconnect()
        } catch {
            throw XCTSkip("Z2M not reachable at \(url) — run 'docker compose up -d'. (\(error))")
        }
    }
}
