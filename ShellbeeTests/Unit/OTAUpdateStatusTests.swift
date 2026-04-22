import XCTest
@testable import Shellbee

final class OTAUpdateStatusTests: XCTestCase {

    // MARK: - Phase parsing

    @MainActor

    func testAllPhasesParseFromRawValue() {
        let cases: [(String, OTAUpdateStatus.Phase)] = [
            ("available", .available),
            ("checking",  .checking),
            ("requested", .requested),
            ("scheduled", .scheduled),
            ("updating",  .updating),
            ("idle",      .idle)
        ]
        for (raw, expected) in cases {
            XCTAssertEqual(OTAUpdateStatus.Phase(rawValue: raw), expected, "Failed for \(raw)")
        }
    }

    @MainActor

    func testUnknownPhaseReturnsNil() {
        XCTAssertNil(OTAUpdateStatus.Phase(rawValue: "bogus"))
    }

    // MARK: - isActive

    @MainActor

    func testCheckingIsActive() {
        XCTAssertTrue(makeStatus(.checking).isActive)
    }

    @MainActor

    func testRequestedIsActive() {
        XCTAssertTrue(makeStatus(.requested).isActive)
    }

    @MainActor

    func testScheduledIsActive() {
        XCTAssertTrue(makeStatus(.scheduled).isActive)
    }

    @MainActor

    func testUpdatingIsActive() {
        XCTAssertTrue(makeStatus(.updating).isActive)
    }

    @MainActor

    func testAvailableIsNotActive() {
        XCTAssertFalse(makeStatus(.available).isActive)
    }

    @MainActor

    func testIdleIsNotActive() {
        XCTAssertFalse(makeStatus(.idle).isActive)
    }

    // MARK: - sortPriority

    @MainActor

    func testUpdatingHasHighestPriority() {
        XCTAssertLessThan(makeStatus(.updating).sortPriority, makeStatus(.scheduled).sortPriority)
    }

    @MainActor

    func testScheduledBeforeRequested() {
        XCTAssertLessThan(makeStatus(.scheduled).sortPriority, makeStatus(.checking).sortPriority)
    }

    @MainActor

    func testAvailableHasLowestPriority() {
        XCTAssertGreaterThan(makeStatus(.available).sortPriority, makeStatus(.updating).sortPriority)
    }

    // MARK: - Helpers

    private func makeStatus(_ phase: OTAUpdateStatus.Phase) -> OTAUpdateStatus {
        OTAUpdateStatus(deviceName: "Test", phase: phase, progress: nil, remaining: nil)
    }
}
