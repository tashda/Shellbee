import XCTest
@testable import Shellbee

@MainActor
final class DevicePresentationPreferenceTests: XCTestCase {
    func testAllModesRoundTripThroughStoredValues() {
        for mode in DevicePresentationMode.allCases {
            XCTAssertEqual(DevicePresentationMode(rawValue: mode.rawValue), mode)
        }
    }

    func testRegularWidthUsesStoredPresentation() {
        XCTAssertEqual(
            DevicePresentationPreference.effectiveMode(storedValue: "grid", usesRegularWidth: true),
            .grid
        )
        XCTAssertEqual(
            DevicePresentationPreference.effectiveMode(storedValue: "table", usesRegularWidth: true),
            .table
        )
    }

    func testCompactWidthAlwaysUsesListWithoutOverwritingPreference() {
        XCTAssertEqual(
            DevicePresentationPreference.effectiveMode(storedValue: "grid", usesRegularWidth: false),
            .list
        )
    }

    func testUnknownStoredValueFallsBackToList() {
        XCTAssertEqual(
            DevicePresentationPreference.effectiveMode(storedValue: "unknown", usesRegularWidth: true),
            .list
        )
    }
}
