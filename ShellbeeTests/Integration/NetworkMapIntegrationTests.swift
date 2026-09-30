import XCTest
@testable import Shellbee

final class NetworkMapIntegrationTests: XCTestCase, @unchecked Sendable {
    @MainActor
    func testBothMockBridgesReturnDistinctRawTopologies() async throws {
        let primary = try await fetchNetworkMap(
            port: 8080,
            token: "shellbee-integration-token"
        )
        let secondary = try await fetchNetworkMap(
            port: 8082,
            token: "shellbee-integration-token-2"
        )

        XCTAssertGreaterThan(primary.nodes.count, 1)
        XCTAssertGreaterThan(primary.links.count, 0)
        XCTAssertEqual(secondary.nodes.count, primary.nodes.count)
        XCTAssertTrue(secondary.nodes.contains { $0.friendlyName.hasPrefix("Lab") })
        XCTAssertFalse(primary.nodes.contains { $0.friendlyName.hasPrefix("Lab") })
        XCTAssertEqual(primary.nodes.filter { $0.role == .coordinator }.count, 1)
        XCTAssertEqual(secondary.nodes.filter { $0.role == .coordinator }.count, 1)
    }

    @MainActor
    private func fetchNetworkMap(port: Int, token: String) async throws -> NetworkTopology {
        guard await MockBridgeProbe.isReachable(host: "localhost", port: port) else {
            throw XCTSkip("Mock bridge is not reachable on port \(port)")
        }
        let config = ConnectionConfig(
            host: "localhost",
            port: port,
            useTLS: false,
            basePath: "/",
            authToken: token
        )
        let client = Z2MWebSocketClient()
        let stream = try await client.connect(url: try XCTUnwrap(config.webSocketURL))
        let outbound = Z2MOutboundEnvelope(
            topic: Z2MTopics.Request.networkMap,
            payload: .object(["type": .string("raw"), "routes": .bool(false)])
        )
        try await client.send(JSONEncoder().encode(outbound))
        let router = Z2MMessageRouter()
        // The mock paces its scan like real z2m (one router every 300 ms,
        // longer for the ones that fail): about 26 s for the 73 fixture
        // routers.
        let deadline = Date().addingTimeInterval(60)

        for await socketEvent in stream {
            guard case .message(let data) = socketEvent else { break }
            if case .networkMapResponse(let response) = router.route(data),
               response.status == "ok",
               let topology = response.data?.value {
                await client.disconnect()
                return topology
            }
            if Date() > deadline { break }
        }

        await client.disconnect()
        XCTFail("Bridge on port \(port) did not return a network map")
        return NetworkTopology(nodes: [], links: [])
    }
}
