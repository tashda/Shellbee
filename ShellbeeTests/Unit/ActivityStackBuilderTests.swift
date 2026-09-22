import XCTest
@testable import Shellbee

@MainActor
final class ActivityStackBuilderTests: XCTestCase {
    private let bridgeA = UUID()
    private let bridgeB = UUID()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testEventsStackBySubjectInNewestFirstOrder() {
        let entries = [
            bound(bridgeA, "Office Sensor", secondsAgo: 10),
            bound(bridgeA, "Kitchen Plug", secondsAgo: 20),
            bound(bridgeA, "Office Sensor", secondsAgo: 30),
            bound(bridgeA, nil, secondsAgo: 40)
        ]

        let sections = build(entries)

        XCTAssertEqual(sections.map(\.kind), [.recent])
        let stacks = sections[0].stacks
        XCTAssertEqual(stacks.map(\.subject), [.named("Office Sensor"), .named("Kitchen Plug"), .bridge])
        XCTAssertEqual(stacks[0].entries.count, 2)
        XCTAssertTrue(stacks[0].isStacked)
        XCTAssertFalse(stacks[1].isStacked)
        XCTAssertEqual(stacks[0].latest.id, entries[0].entry.id)
    }

    func testRecentErrorsAndWarningsArePinnedUnderNeedsAttention() {
        let entries = [
            bound(bridgeA, "Front Door Lock", secondsAgo: 10, level: .error),
            bound(bridgeA, "Office Sensor", secondsAgo: 20),
            bound(bridgeA, "Hallway Motion", secondsAgo: 30, level: .warning),
            bound(bridgeA, "Garage Door", secondsAgo: 2 * 24 * 60 * 60, level: .warning)
        ]

        let sections = build(entries)

        XCTAssertEqual(sections.map(\.kind), [.needsAttention, .recent])
        XCTAssertEqual(sections[0].stacks.map(\.subject), [.named("Front Door Lock"), .named("Hallway Motion")])
        XCTAssertEqual(sections[1].stacks.map(\.subject), [.named("Office Sensor"), .named("Garage Door")])
    }

    func testStacksNeverSpanBridges() {
        let entries = [
            bound(bridgeA, "Office Sensor", secondsAgo: 10),
            bound(bridgeB, "Office Sensor", secondsAgo: 20)
        ]

        let stacks = build(entries)[0].stacks

        XCTAssertEqual(stacks.count, 2)
        XCTAssertNotEqual(stacks[0].id, stacks[1].id)
    }

    func testEventCountIncludesCoalescedRows() {
        let entries = [
            bound(bridgeA, "Office Sensor", secondsAgo: 10, coalescedCount: 5),
            bound(bridgeA, "Office Sensor", secondsAgo: 20)
        ]

        XCTAssertEqual(build(entries)[0].stacks[0].eventCount, 6)
    }

    func testStackIdentityIsStableWhenNewEventsArrive() {
        let older = [bound(bridgeA, "Office Sensor", secondsAgo: 20)]
        let newer = [bound(bridgeA, "Office Sensor", secondsAgo: 5)] + older

        XCTAssertEqual(build(older)[0].stacks[0].id, build(newer)[0].stacks[0].id)
    }

    func testNoEntriesProducesNoSections() {
        XCTAssertTrue(build([]).isEmpty)
    }

    // MARK: - Helpers

    func testClearingABridgeMovesItsWarningsToRecentUntilANewOneArrives() {
        let old = bound(bridgeA, "Hallway Motion", secondsAgo: 60, level: .warning)
        var clearance = ActivityAttentionClearance(rawValue: "")
        clearance.clear(bridgeIDs: [bridgeA], through: now.addingTimeInterval(-30))

        let cleared = build([old], clearance: clearance)
        XCTAssertEqual(cleared.map(\.kind), [.recent])

        let fresh = bound(bridgeA, "Hallway Motion", secondsAgo: 10, level: .warning)
        let reopened = build([fresh, old], clearance: clearance)
        XCTAssertEqual(reopened.map(\.kind), [.needsAttention, .recent])
        XCTAssertEqual(reopened[0].stacks[0].latest.id, fresh.entry.id)
    }

    func testClearingOneStackLeavesOthersPinned() {
        let entries = [
            bound(bridgeA, "Front Door Lock", secondsAgo: 10, level: .error),
            bound(bridgeA, "Hallway Motion", secondsAgo: 20, level: .warning)
        ]
        let pinned = build(entries)
        var clearance = ActivityAttentionClearance(rawValue: "")
        clearance.clear(pinned[0].stacks[0])

        let sections = build(entries, clearance: clearance)
        XCTAssertEqual(sections.first?.kind, .needsAttention)
        XCTAssertEqual(sections.first?.stacks.map(\.subject), [.named("Hallway Motion")])
    }

    func testClearanceSurvivesEncoding() {
        var clearance = ActivityAttentionClearance(rawValue: "")
        clearance.clear(bridgeIDs: [bridgeA], through: now)
        XCTAssertEqual(ActivityAttentionClearance(rawValue: clearance.rawValue), clearance)
    }

    private func build(
        _ entries: [BridgeBoundLogEntry],
        clearance: ActivityAttentionClearance = .init(rawValue: "")
    ) -> [ActivityFeedSection] {
        ActivityStackBuilder.sections(from: entries, now: now, clearance: clearance) { item in
            item.entry.deviceName.map(ActivityStack.Subject.named) ?? .bridge
        }
    }

    private func bound(
        _ bridgeID: UUID,
        _ device: String?,
        secondsAgo: TimeInterval,
        level: LogLevel = .info,
        coalescedCount: Int = 1
    ) -> BridgeBoundLogEntry {
        BridgeBoundLogEntry(
            bridgeID: bridgeID,
            bridgeName: "Bridge",
            entry: LogEntry(
                id: UUID(), timestamp: now.addingTimeInterval(-secondsAgo), level: level,
                category: device == nil ? .bridgeActivity : .stateChange, namespace: nil,
                message: "event", deviceName: device, coalescedCount: coalescedCount
            )
        )
    }
}
