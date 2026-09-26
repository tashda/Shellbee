import XCTest
@testable import Shellbee

final class OTABulkOperationQueueTests: XCTestCase {
    func testSendsSequentiallyInOrder() async { await OTABulkOperationQueueTestDriver.testSendsSequentiallyInOrder() }
    func testTimeoutCountsAsFailureAndAdvances() async { await OTABulkOperationQueueTestDriver.testTimeoutCountsAsFailureAndAdvances() }
    func testCancelStopsProcessing() async { await OTABulkOperationQueueTestDriver.testCancelStopsProcessing() }
    func testIgnoresResponseForDeviceNotInQueue() async { await OTABulkOperationQueueTestDriver.testIgnoresResponseForDeviceNotInQueue() }
    func testConcurrencyDispatchesMultipleInFlight() async { await OTABulkOperationQueueTestDriver.testConcurrencyDispatchesMultipleInFlight() }
    func testUpdateRetriesSendUntilTransmitted() async { await OTABulkOperationQueueTestDriver.testUpdateRetriesSendUntilTransmitted() }
    func testUpdateTimeoutRetriesOnceBeforeFailing() async { await OTABulkOperationQueueTestDriver.testUpdateTimeoutRetriesOnceBeforeFailing() }
    func testEnqueueWhileRunningAppendsToCurrentRun() async { await OTABulkOperationQueueTestDriver.testEnqueueWhileRunningAppendsToCurrentRun() }
}

@MainActor
private enum OTABulkOperationQueueTestDriver {

    private final class Recorder {
        var sends: [(topic: String, id: String)] = []
        var summaries: [OTABulkOperationQueue.CompletionSummary] = []
    }

    private final class SendGate {
        private var continuation: CheckedContinuation<Void, Never>?
        var isWaiting: Bool { continuation != nil }

        func wait() async {
            await withCheckedContinuation { continuation = $0 }
        }

        func release() {
            continuation?.resume()
            continuation = nil
        }
    }

    private static func makeQueue(
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
                return true
            },
            onCompletion: { summary in
                recorder.summaries.append(summary)
            },
            updateTimeout: updateTimeout,
            sleep: sleep,
            settingsProvider: { (concurrency, checkTimeout) }
        )
    }

    private static func waitUntil(
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

    static func testSendsSequentiallyInOrder() async {
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

    static func testTimeoutCountsAsFailureAndAdvances() async {
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

    static func testCancelStopsProcessing() async {
        let recorder = Recorder()
        let gate = SendGate()
        let queue = OTABulkOperationQueue(
            sender: { topic, payload in
                let id = payload.object?["id"]?.stringValue ?? ""
                recorder.sends.append((topic, id))
                await gate.wait()
                return true
            },
            onCompletion: { summary in recorder.summaries.append(summary) }
        )

        queue.enqueue(["a", "b", "c"], kind: .check)
        await waitUntil { recorder.sends.count == 1 && gate.isWaiting }

        queue.cancelAll()
        gate.release()
        await waitUntil { !queue.isActive }

        XCTAssertEqual(recorder.sends.count, 1, "Only the first in-flight send should have gone out")
        let summary = recorder.summaries.first
        XCTAssertEqual(summary?.wasCancelled, true)
    }

    static func testIgnoresResponseForDeviceNotInQueue() async {
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

    static func testConcurrencyDispatchesMultipleInFlight() async {
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

    static func testUpdateRetriesSendUntilTransmitted() async {
        // Simulates a WebSocket blip: the first two send attempts fail to
        // transmit (as if mid-reconnect), the third succeeds. The queue
        // should retry rather than silently stalling — see #144.
        final class FlakyRecorder {
            var attempts = 0
            var transmittedSends: [String] = []
        }
        let flaky = FlakyRecorder()
        let sendRetryDelay = OTABulkOperationQueue.sendRetryDelay
        let queue = OTABulkOperationQueue(
            sender: { _, payload in
                flaky.attempts += 1
                guard flaky.attempts >= 3 else { return false }
                flaky.transmittedSends.append(payload.object?["id"]?.stringValue ?? "")
                return true
            },
            onCompletion: nil,
            sleep: { duration in
                // Fast-forward the send-retry backoff so the test doesn't
                // actually wait; but let the per-device timeout be a no-op
                // long sleep instead of instant, so it doesn't fire and
                // trigger the unrelated timeout-retry path mid-test.
                if duration == sendRetryDelay { return }
                try await Task.sleep(for: .seconds(1_000))
            }
        )

        queue.enqueue(["a"], kind: .update)
        await waitUntil { flaky.transmittedSends.count == 1 }
        XCTAssertEqual(flaky.attempts, 3, "should retry failed transmissions instead of giving up immediately")

        queue.handleResponse(friendlyName: "a", success: true, kind: .update)
        await waitUntil { !queue.isActive }
    }

    static func testUpdateTimeoutRetriesOnceBeforeFailing() async {
        // A missed completion event (socket down when Z2M published it) looks
        // identical to a genuinely stuck device: no response before timeout.
        // Update requests get one reissue before being marked failed — the
        // retry succeeds here, simulating the response having arrived late.
        let recorder = Recorder()
        var sendCount = 0
        let queue = OTABulkOperationQueue(
            sender: { topic, payload in
                sendCount += 1
                let id = payload.object?["id"]?.stringValue ?? ""
                recorder.sends.append((topic, id))
                return true
            },
            onCompletion: { summary in recorder.summaries.append(summary) },
            updateTimeout: .milliseconds(20),
            sleep: { try await Task.sleep(for: $0) }
        )

        queue.enqueue(["a"], kind: .update)
        await waitUntil { sendCount == 1 }

        // Let the first attempt time out, then answer the retry.
        await waitUntil(timeout: 2.0) { sendCount == 2 }
        queue.handleResponse(friendlyName: "a", success: true, kind: .update)

        await waitUntil(timeout: 2.0) { !queue.isActive }
        XCTAssertEqual(recorder.summaries.first?.succeeded, 1)
        XCTAssertEqual(recorder.summaries.first?.failed, 0)
    }

    static func testEnqueueWhileRunningAppendsToCurrentRun() async {
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
