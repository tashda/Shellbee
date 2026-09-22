import XCTest
@testable import Shellbee

@MainActor
final class AdaptiveWindowLayoutTests: XCTestCase {
    func testWindowClassesUseSceneWidthInsteadOfOrientation() {
        XCTAssertEqual(
            AdaptiveLayout.windowClass(in: CGSize(width: 600, height: 400)),
            .compact
        )
        XCTAssertEqual(
            AdaptiveLayout.windowClass(in: CGSize(width: 900, height: 1_400)),
            .standard
        )
        XCTAssertEqual(
            AdaptiveLayout.windowClass(in: CGSize(width: 1_300, height: 700)),
            .expansive
        )
    }

    func testBreakpointBoundariesAreDeterministic() {
        let standard = DesignTokens.Size.iPadStandardWindowMinimumWidth
        let expansive = DesignTokens.Size.iPadThreeColumnMinimumWidth

        XCTAssertEqual(
            AdaptiveLayout.windowClass(in: CGSize(width: standard - 1, height: 900)),
            .compact
        )
        XCTAssertEqual(
            AdaptiveLayout.windowClass(in: CGSize(width: standard, height: 900)),
            .standard
        )
        XCTAssertEqual(
            AdaptiveLayout.windowClass(in: CGSize(width: expansive - 1, height: 900)),
            .standard
        )
        XCTAssertEqual(
            AdaptiveLayout.windowClass(in: CGSize(width: expansive, height: 900)),
            .expansive
        )
    }
}
