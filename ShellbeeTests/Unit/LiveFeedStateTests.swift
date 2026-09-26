import XCTest
@testable import Shellbee

final class LiveFeedStateTests: XCTestCase {
    func testFollowingLiveUsesTheCurrentItems() {
        let state = LiveFeedSnapshotState<Item>()
        let live = [Item(id: 1), Item(id: 2)]

        XCTAssertEqual(state.displayedItems(from: live), live)
        XCTAssertFalse(state.isReadingHistory)
    }

    func testReadingHistoryKeepsTheSnapshotStableAsItemsArrive() {
        var state = LiveFeedSnapshotState<Item>()
        let history = [Item(id: 2), Item(id: 1)]
        let live = [Item(id: 3)] + history

        state.beginReadingHistory(with: history)

        XCTAssertTrue(state.isReadingHistory)
        XCTAssertEqual(state.displayedItems(from: live), history)
    }

    func testFollowLiveDropsTheSnapshotAndShowsNewItems() {
        var state = LiveFeedSnapshotState<Item>()
        let history = [Item(id: 2), Item(id: 1)]
        let live = [Item(id: 3)] + history

        state.beginReadingHistory(with: history)
        state.followLive()

        XCTAssertFalse(state.isReadingHistory)
        XCTAssertEqual(state.displayedItems(from: live), live)
    }

    func testSecondReadingGestureDoesNotReplaceTheOriginalSnapshot() {
        var state = LiveFeedSnapshotState<Item>()
        let history = [Item(id: 2), Item(id: 1)]

        state.beginReadingHistory(with: history)
        state.beginReadingHistory(with: [Item(id: 3)] + history)

        XCTAssertEqual(state.displayedItems(from: []), history)
    }

    private struct Item: Identifiable, Equatable {
        let id: Int
    }
}
