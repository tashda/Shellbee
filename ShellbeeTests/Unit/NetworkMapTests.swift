import XCTest
@testable import Shellbee

@MainActor
final class NetworkMapTests: XCTestCase {
    func testRouterDecodesRawNetworkMapResponse() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "topic": "bridge/response/networkmap",
            "payload": responsePayload()
        ])

        guard case .networkMapResponse(let response) = Z2MMessageRouter().route(data) else {
            return XCTFail("Expected a network-map response")
        }

        XCTAssertEqual(response.status, "ok")
        XCTAssertEqual(response.data?.type, "raw")
        XCTAssertEqual(response.data?.value.nodes.count, 3)
        XCTAssertEqual(response.data?.value.links.first?.linkQuality, 172)
        XCTAssertEqual(response.data?.value.nodes.last?.role, .endDevice)
    }

    func testNestedLinkEndpointsAndLQIFallbackDecode() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "source": ["ieeeAddr": "router"],
            "target": ["ieeeAddr": "coordinator"],
            "lqi": 88
        ])

        let link = try JSONDecoder().decode(NetworkTopologyLink.self, from: data)

        XCTAssertEqual(link.sourceIEEEAddress, "router")
        XCTAssertEqual(link.targetIEEEAddress, "coordinator")
        XCTAssertEqual(link.linkQuality, 88)
    }

    func testLayoutIsDeterministicAndKeepsMultiHopChain() {
        let topology = makeTopology()

        let first = NetworkMapLayoutEngine.layout(topology: topology, width: 800, minimumHeight: 480)
        let second = NetworkMapLayoutEngine.layout(topology: topology, width: 800, minimumHeight: 480)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.nodes.first(where: { $0.id == "coordinator" })?.depth, 0)
        XCTAssertEqual(first.nodes.first(where: { $0.id == "router" })?.depth, 1)
        XCTAssertEqual(first.nodes.first(where: { $0.id == "leaf" })?.depth, 2)
        XCTAssertEqual(first.edges.filter(\.isPrimary).count, 2)
    }

    func testAdditionalParentLinkDoesNotRelayoutNodes() {
        let topology = makeTopology(additionalLink: false)
        let withAdditionalLink = makeTopology(additionalLink: true)

        let base = NetworkMapLayoutEngine.layout(topology: topology, width: 800, minimumHeight: 480)
        let additional = NetworkMapLayoutEngine.layout(topology: withAdditionalLink, width: 800, minimumHeight: 480)

        XCTAssertEqual(base.nodes, additional.nodes)
        XCTAssertEqual(additional.edges.count, base.edges.count + 1)
        XCTAssertEqual(additional.edges.filter { !$0.isPrimary }.count, 1)
    }

    func testFiltersComposeRoleAndHealthFacets() {
        let router = node(id: "router", name: "Router", role: .router)
        XCTAssertTrue(NetworkMapFilter.matches(
            node: router,
            filters: [.routers, .weakLinks],
            isOffline: false,
            hasWeakLink: true
        ))
        XCTAssertFalse(NetworkMapFilter.matches(
            node: router,
            filters: [.endDevices, .weakLinks],
            isOffline: false,
            hasWeakLink: true
        ))
    }

    func testCacheRoundTripIsScopedByBridge() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetworkMapTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = NetworkMapCache(directoryURL: directory)
        let firstBridge = UUID()
        let secondBridge = UUID()
        let record = NetworkMapCacheRecord(topology: makeTopology(), updatedAt: Date(timeIntervalSince1970: 123))

        cache.save(record, bridgeID: firstBridge)

        XCTAssertEqual(cache.load(bridgeID: firstBridge), record)
        XCTAssertNil(cache.load(bridgeID: secondBridge))
    }

    func testStorePersistsSuccessfulResponseAndClearsRefreshState() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetworkMapStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = NetworkMapCache(directoryURL: directory)
        let bridgeID = UUID()
        let store = AppStore(networkMapCache: cache)
        store.setActiveBridge(bridgeID)
        store.networkMapIsRefreshing = true
        let topology = makeTopology()

        store.apply(.networkMapResponse(NetworkMapResponse(
            data: .init(routes: false, type: "raw", value: topology),
            status: "ok",
            error: nil
        )))

        XCTAssertEqual(store.networkTopology, topology)
        XCTAssertNotNil(store.networkMapLastUpdated)
        XCTAssertFalse(store.networkMapIsRefreshing)
        XCTAssertEqual(cache.load(bridgeID: bridgeID)?.topology, topology)
    }

    func testFailedRefreshKeepsCachedTopologyAndSurfacesError() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetworkMapFailureTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStore(networkMapCache: NetworkMapCache(directoryURL: directory))
        let topology = makeTopology()
        store.apply(.networkMapResponse(NetworkMapResponse(
            data: .init(routes: false, type: "raw", value: topology),
            status: "ok",
            error: nil
        )))
        store.networkMapIsRefreshing = true

        store.apply(.networkMapResponse(NetworkMapResponse(
            data: nil,
            status: "error",
            error: "Coordinator timed out"
        )))

        XCTAssertEqual(store.networkTopology, topology)
        XCTAssertFalse(store.networkMapIsRefreshing)
        XCTAssertEqual(store.operationErrors.first?.message, "Coordinator timed out")
    }

    private func makeTopology(additionalLink: Bool = false) -> NetworkTopology {
        var links = [
            NetworkTopologyLink(
                sourceIEEEAddress: "router",
                targetIEEEAddress: "coordinator",
                linkQuality: 180
            ),
            NetworkTopologyLink(
                sourceIEEEAddress: "leaf",
                targetIEEEAddress: "router",
                linkQuality: 40
            )
        ]
        if additionalLink {
            links.append(NetworkTopologyLink(
                sourceIEEEAddress: "leaf",
                targetIEEEAddress: "coordinator",
                linkQuality: 20
            ))
        }
        return NetworkTopology(
            nodes: [
                node(id: "leaf", name: "Leaf", role: .endDevice),
                node(id: "coordinator", name: "Coordinator", role: .coordinator),
                node(id: "router", name: "Router", role: .router)
            ],
            links: links
        )
    }

    private func node(
        id: String,
        name: String,
        role: NetworkTopologyNode.Role
    ) -> NetworkTopologyNode {
        NetworkTopologyNode(
            ieeeAddress: id,
            friendlyName: name,
            networkAddress: nil,
            role: role,
            manufacturerName: nil,
            modelID: nil
        )
    }

    private func responsePayload() -> [String: Any] {
        [
            "status": "ok",
            "data": [
                "routes": false,
                "type": "raw",
                "value": [
                    "nodes": [
                        ["ieeeAddr": "coordinator", "friendlyName": "Coordinator", "type": "Coordinator"],
                        ["ieeeAddr": "router", "friendlyName": "Router", "type": "Router"],
                        ["ieeeAddr": "leaf", "friendlyName": "Leaf", "type": "EndDevice"]
                    ],
                    "links": [[
                        "sourceIeeeAddr": "router",
                        "targetIeeeAddr": "coordinator",
                        "linkquality": 172
                    ]]
                ]
            ]
        ]
    }
}
