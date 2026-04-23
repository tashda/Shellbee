import XCTest
@testable import Shellbee

final class NotificationPreferencesTests: XCTestCase, @unchecked Sendable {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "notificationPreferences.enabledCategories")
        UserDefaults.standard.removeObject(forKey: "notificationPreferences.followLogLevelOverride")
    }

    @MainActor
    func testErrorBridgeLevelOnlyEnablesErrors() {
        let prefs = NotificationPreferences()
        XCTAssertTrue(prefs.isEnabled(.operationFailed, bridgeLogLevel: "error"))
        XCTAssertTrue(prefs.isEnabled(.bindFailure, bridgeLogLevel: "error"))
        XCTAssertFalse(prefs.isEnabled(.bindSuccess, bridgeLogLevel: "error"))
        XCTAssertFalse(prefs.isEnabled(.interviewStarted, bridgeLogLevel: "error"))
        XCTAssertFalse(prefs.isEnabled(.deviceLeft, bridgeLogLevel: "error"))
    }

    @MainActor
    func testInfoBridgeLevelEnablesThroughInfo() {
        let prefs = NotificationPreferences()
        XCTAssertTrue(prefs.isEnabled(.bindSuccess, bridgeLogLevel: "info"))
        XCTAssertTrue(prefs.isEnabled(.deviceLeft, bridgeLogLevel: "info"))
        XCTAssertTrue(prefs.isEnabled(.otaUpdateInstalled, bridgeLogLevel: "info"))
        XCTAssertFalse(prefs.isEnabled(.interviewStarted, bridgeLogLevel: "info"))
    }

    @MainActor
    func testDebugBridgeLevelEnablesChattyCategories() {
        let prefs = NotificationPreferences()
        XCTAssertTrue(prefs.isEnabled(.interviewStarted, bridgeLogLevel: "debug"))
    }

    @MainActor
    func testOtaNoUpdateIsAlwaysOffByDefault() {
        let prefs = NotificationPreferences()
        for level in ["error", "warning", "info", "debug"] {
            XCTAssertFalse(
                prefs.isEnabled(.otaNoUpdate, bridgeLogLevel: level),
                "otaNoUpdate should be off by default at level=\(level)"
            )
        }
    }

    @MainActor
    func testManualOverridePersists() {
        let prefs = NotificationPreferences()
        prefs.setEnabled(.otaNoUpdate, enabled: true, bridgeLogLevel: "info")
        XCTAssertTrue(prefs.isEnabled(.otaNoUpdate, bridgeLogLevel: "info"))
        XCTAssertTrue(prefs.hasCustomSelection)

        let prefs2 = NotificationPreferences()
        XCTAssertTrue(prefs2.isEnabled(.otaNoUpdate, bridgeLogLevel: "info"))
    }

    @MainActor
    func testResetClearsCustomSelection() {
        let prefs = NotificationPreferences()
        prefs.setEnabled(.bindSuccess, enabled: false, bridgeLogLevel: "info")
        XCTAssertTrue(prefs.hasCustomSelection)

        prefs.resetToDefaults(bridgeLogLevel: "info")
        XCTAssertFalse(prefs.hasCustomSelection)
        XCTAssertTrue(prefs.isEnabled(.bindSuccess, bridgeLogLevel: "info"))
    }

    @MainActor
    func testUnknownBridgeLevelFallsBackToInfoBaseline() {
        let prefs = NotificationPreferences()
        XCTAssertTrue(prefs.isEnabled(.bindSuccess, bridgeLogLevel: "nonsense"))
        XCTAssertFalse(prefs.isEnabled(.interviewStarted, bridgeLogLevel: "nonsense"))
    }

    @MainActor
    func testNilBridgeLevelFallsBackToInfoBaseline() {
        let prefs = NotificationPreferences()
        XCTAssertTrue(prefs.isEnabled(.bindSuccess, bridgeLogLevel: nil))
        XCTAssertFalse(prefs.isEnabled(.interviewStarted, bridgeLogLevel: nil))
    }
}
