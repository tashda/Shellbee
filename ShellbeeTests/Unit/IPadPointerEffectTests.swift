import XCTest
@testable import Shellbee

@MainActor
final class IPadPointerEffectTests: XCTestCase {
    func testHighlightRemainsHighlightWithReduceMotion() {
        XCTAssertEqual(
            IPadPointerEffect.highlight.resolved(reduceMotion: true),
            .highlight
        )
    }

    func testLiftIsUsedWhenMotionIsAllowed() {
        XCTAssertEqual(
            IPadPointerEffect.lift.resolved(reduceMotion: false),
            .lift
        )
    }

    func testLiftFallsBackToHighlightForReduceMotion() {
        XCTAssertEqual(
            IPadPointerEffect.lift.resolved(reduceMotion: true),
            .highlight
        )
    }
}
