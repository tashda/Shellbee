import XCTest
@testable import Shellbee

@MainActor
final class OTABulkOperationQueueTests: XCTestCase {

    private final class Recorder {
        var sends: [(topic: String, id: String)] = []
        var summaries: [OTABulkOperationQueue.CompletionSummary] = []
    }

    private func makeQueue(
        recorder: Recorder,
        concurrency: Int = 1,
        checkTimeout: Duration = .seconds(60),
        updateTimeout: Duration = .seconds(600),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { _ in
            try await Task.sleep(for: .seconds(1_000))
        }
    ) -> OTABulkOperationQueue {
        OTABulkOperationQueue(
            sender: { topic, payload in
                let id = payload.object?["id"]?.stringValue ?? ""
                recorder.sends.append((topic, id))
            },
            onCompletion: { summary in
                recorder.summaries.append(summary)
            },
            updateTimeout: updateTimeout,
            sleep: sleep,
            settingsProvider: { (concurrency, checkTimeout) }
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    func testSendsSequentiallyInOrder() async {
        let recorder = Recorder()
        let queue = makeQueue(recorder: recorder)

        queue.enqueue(["a", "b", "c"], kind: .check)

        await waitUntil { recorder.sends.count == 1 }
        XCTAssertEqual(recorder.sends.map(\.id), ["a"])
        XCTAssertEqual(queue.progress?.total, 3)
        XCTAssertEqual(queue.progress?.completed, 0)
        XCTAssertEqual(queue.progress?.inFlight, 1)

        queue.handleResponse(friendlyName: "a", success: true, kind: .check)
        await waitUntil { recorder.sends.count == 2 }
        XCTAssertEqual(recorder.sends.last?.id, "b")

        queue.handleResponse(friendlyName: "b", success: true, kind: .check)
        await waitUntil { recorder.sends.count == 3 }
        XCTAssertEqual(recorder.sends.last?.id, "c")

        queue.handleResponse(friendlyName: "c", success: true, kind: .check)
        await waitUntil { !queue.isActive }

        XCTAssertEqual(recorder.summaries.count, 1)
        XCTAssertEqual(recorder.summaries.first?.total, 3)
        XCTAssertEqual(recorder.summaries.first?.succeeded, 3)
        XCTAssertEqual(recorder.summaries.first?.failed, 0)
        XCTAssertFalse(recorder.summaries.first?.wasCancelled ?? true)
    }

    func testTimeoutCountsAsFailureAndAdvances() async {
        let recorder = Recorder()
        let queue = makeQueue(recorder: recorder, checkTimeout: .milliseconds(20)) { duration in
            try await Task.sleep(for: duration)
        }

        queue.enqueue(["a", "b"], kind: .check)

        // First device: do not respond — let it time out.
        await waitUntil { recorder.sends.count >= 1 }
        XCTAssertEqual(recorder.sends.first?.id, "a")

        // Wait for the queue to advance past the timeout to "b".
        await waitUntil(timeout: 2.0) { recorder.sends.count == 2 }
        XCTAssertEqual(recorder.sends.last?.id, "b")

        // Respond to "b" before its timeout fires.
        queue.handleResponse(friendlyName: "b", success: true, kind: .check)

        await waitUntil(timeout: 2.0) { !queue.isActive }

        let summary = recorder.summaries.first
        XCTAssertEqual(summary?.total, 2)
        XCTAssertEqual(summary?.failed, 1)
        XCTAssertEqual(summary?.succeeded, 1)
    }

    func testCancelStopsProcessing() async {
        let recorder = Recorder()
        let queue = makeQueue(recorder: recorder)

        queue.enqueue(["a", "b", "c"], kind: .check)
        await waitUntil { recorder.sends.count == 1 }

        queue.cancelAll()
        await waitUntil { !queue.isActive }

        XCTAssertEqual(recorder.sends.count, 1, "Only the first in-flight send should have gone out")
        let summary = recorder.summaries.first
        XCTAssertEqual(summary?.wasCancelled, true)
    }

    func testIgnoresResponseForDeviceNotInQueue() async {
        let recorder = Recorder()
        let queue = makeQueue(recorder: recorder)

        queue.enqueue(["a"], kind: .check)
        await waitUntil { recorder.sends.count == 1 }

        // Stray response for another device — should not advance the queue.
        queue.handleResponse(friendlyName: "zzz", success: true, kind: .check)
        // Wrong kind for the current item — also ignored.
        queue.handleResponse(friendlyName: "a", success: true, kind: .update)

        try? await Task.sleep(for: .milliseconds(20))
        XCTAssertTrue(queue.isActive)
        XCTAssertEqual(queue.progress?.completed, 0)

        queue.handleResponse(friendlyName: "a", success: true, kind: .check)
        await waitUntil { !queue.isActive }
        XCTAssertEqual(recorder.summaries.first?.succeeded, 1)
    }

    func testConcurrencyDispatchesMultipleInFlight() async {
        let recorder = Recorder()
        let queue = makeQueue(recorder: recorder, concurrency: 3)

        queue.enqueue(["a", "b", "c", "d"], kind: .check)

        // Three workers should fire immediately, before any response lands.
        await waitUntil { recorder.sends.count == 3 }
        XCTAssertEqual(Set(recorder.sends.map(\.id)), ["a", "b", "c"])
        XCTAssertEqual(queue.progress?.inFlight, 3)

        queue.handleResponse(friendlyName: "b", success: true, kind: .check)
        await waitUntil { recorder.sends.count == 4 }
        XCTAssertEqual(recorder.sends.last?.id, "d")

        for name in ["a", "c", "d"] {
            queue.handleResponse(friendlyName: name, success: true, kind: .check)
        }
        await waitUntil { !queue.isActive }
        XCTAssertEqual(recorder.summaries.first?.succeeded, 4)
    }

    func testEnqueueWhileRunningAppendsToCurrentRun() async {
        let recorder = Recorder()
        let queue = makeQueue(recorder: recorder)

        queue.enqueue(["a"], kind: .check)
        await waitUntil { recorder.sends.count == 1 }

        queue.enqueue(["b"], kind: .check)
        XCTAssertEqual(queue.progress?.total, 2)

        queue.handleResponse(friendlyName: "a", success: true, kind: .check)
        await waitUntil { recorder.sends.count == 2 }
        XCTAssertEqual(recorder.sends.last?.id, "b")

        queue.handleResponse(friendlyName: "b", success: true, kind: .check)
        await waitUntil { !queue.isActive }
        XCTAssertEqual(recorder.summaries.first?.total, 2)
    }
}
