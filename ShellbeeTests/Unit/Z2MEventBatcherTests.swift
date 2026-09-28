import XCTest
@testable import Shellbee

final class Z2MEventBatcherTests: XCTestCase {
    private func frame(_ topic: String) -> Data {
        Data(#"{"topic":"\#(topic)","payload":{"state":"ON"}}"#.utf8)
    }

    private func topics(_ batch: [Z2MEventBatcher.Item]) -> [String] {
        batch.compactMap { item in
            if case .message(_, .deviceState(let name, _)?) = item { return name }
            return nil
        }
    }

    func testLoneMessageArrivesAtOnceAndBurstIsBatchedInOrder() async {
        let (events, input) = AsyncStream<Z2MSocketEvent>.makeStream()
        var iterator = Z2MEventBatcher.batches(from: events, router: Z2MMessageRouter()).makeAsyncIterator()

        input.yield(.message(frame("lamp")))
        let first = await iterator.next()
        XCTAssertEqual(first.map(topics), ["lamp"])

        for i in 0..<20 { input.yield(.message(frame("d\(i)"))) }
        var received: [String] = []
        while received.count < 20, let batch = await iterator.next() {
            received += topics(batch)
        }
        XCTAssertEqual(received, (0..<20).map { "d\($0)" })

        input.yield(.disconnected("bye"))
        var sawDisconnect = false
        while let batch = await iterator.next() {
            if batch.contains(where: { if case .disconnected = $0 { return true }; return false }) { sawDisconnect = true }
        }
        XCTAssertTrue(sawDisconnect)
    }

    func testUnusedBridgeTopicsAreDropped() {
        let data = Data(#"{"topic":"bridge/definitions","payload":{"clusters":{}}}"#.utf8)
        guard case .unknown(let topic)? = Z2MMessageRouter().route(data) else {
            return XCTFail("bridge/definitions should not become device state")
        }
        XCTAssertEqual(topic, "bridge/definitions")
    }
}
