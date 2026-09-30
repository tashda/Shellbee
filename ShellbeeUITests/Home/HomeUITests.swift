import XCTest

final class HomeUITests: ShellbeeUITestCase {

    override func setUp() {
        super.setUp()
        app.tapHomeTab()
        app.navigationBars["Home"].assertExists(timeout: 10)
    }

    // MARK: - Bridge

    /// Each connected bridge is one row reading "Connected · Zigbee2MQTT <version>".
    func testBridgeRowShowsConnectedBridge() {
        bridgeRow.assertExists(timeout: 10)
    }

    /// The bridge's own figures live in the info sheet, not on Home.
    func testBridgeRowOpensBridgeInfo() {
        bridgeRow.tapWhenReady(timeout: 10)
        app.staticTexts["Connection"].firstMatch.assertExists(timeout: 5)
        app.buttons["Done"].firstMatch.tapWhenReady()
        XCTAssertTrue(app.staticTexts["Connection"].waitForNonExistence(timeout: 5))
    }

    // MARK: - Needs attention

    /// The fixtures always have low batteries, so the section must be there,
    /// and its row opens Devices already filtered.
    func testNeedsAttentionOpensFilteredDevices() {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Low battery"))
            .firstMatch
            .tapWhenReady(timeout: 10)
        app.navigationBars["Devices"].assertExists(timeout: 5)
        app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "clear-filters", "Clear Filters"))
            .firstMatch
            .assertExists(timeout: 5)
    }

    // MARK: - Cards

    /// Vendors and Activity are opt-in; the default Home has neither.
    func testOptInCardsAreOffByDefault() {
        app.staticTexts["Network"].firstMatch.assertExists(timeout: 10)
        for _ in 0..<5 { app.swipeUp() }
        XCTAssertFalse(app.buttons["See all"].exists, "The Activity card is on by default")
        XCTAssertFalse(app.staticTexts["Vendors"].exists, "The Vendors card is on by default")
    }

    // MARK: - Permit Join

    /// A real round trip: Open Network sends bridge/request/permit_join, the
    /// mock bridge answers and reports the network open with a countdown,
    /// and Close Network closes it again.
    func testPermitJoinOpensAndClosesTheNetwork() {
        permitJoinButton.tapWhenReady(timeout: 5)
        app.buttons["Open Network"].firstMatch.tapWhenReady(timeout: 5)
        app.staticTexts["Network is open"].firstMatch.assertExists(timeout: 10)

        app.buttons["Close Network"].firstMatch.tapWhenReady(timeout: 5)
        app.buttons["Open Network"].firstMatch.assertExists(timeout: 10)
    }

    func testPermitJoinSheetOffersDurationAndTarget() {
        permitJoinButton.tapWhenReady(timeout: 5)
        app.staticTexts["Open the network"].firstMatch.assertExists(timeout: 5)
        for picker in ["Duration", "Via"] {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", picker))
                .firstMatch
                .assertExists(timeout: 5)
        }
    }

    func testPermitJoinSheetDismisses() {
        permitJoinButton.tapWhenReady(timeout: 5)
        let openNetwork = app.buttons["Open Network"].firstMatch
        openNetwork.assertExists(timeout: 5)
        for _ in 0..<3 where openNetwork.exists {
            app.swipeDown(velocity: .fast)
            _ = openNetwork.waitForNonExistence(timeout: 1)
        }
        XCTAssertFalse(openNetwork.exists, "The Permit Join sheet did not dismiss")
    }

    // MARK: - Helpers

    private var bridgeRow: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Connected · Zigbee2MQTT")).firstMatch
    }

    private var permitJoinButton: XCUIElement {
        app.buttons["Start Permit Join"].firstMatch
    }
}
