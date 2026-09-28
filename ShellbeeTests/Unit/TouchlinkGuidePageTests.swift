import XCTest
@testable import Shellbee

@MainActor
final class TouchlinkGuidePageTests: XCTestCase {
    func testSubsectionsFoldIntoTheirSection() {
        let sections = [
            DocSection(title: "Touchlink", level: 1, blocks: [.paragraph([.text("Intro")])]),
            DocSection(title: "Support", level: 2, blocks: []),
            DocSection(title: "Coordinator", level: 3, blocks: [.paragraph([.text("TI")])]),
            DocSection(title: "Factory reset device", level: 2, blocks: [.paragraph([.text("Reset")])]),
            DocSection(title: "Serial number (Philips Hue only)", level: 4, blocks: [.paragraph([.text("Hue")])])
        ]
        let pages = TouchlinkGuidePage.pages(from: sections)

        XCTAssertEqual(pages.map { $0.title }, ["About Touchlink", "Support", "Factory reset device"])
        XCTAssertEqual(pages.first?.summary, "Intro")
        XCTAssertEqual(pages[2].blocks.count, 2)
    }

    func testCoordinatorSupport() {
        XCTAssertEqual(TouchlinkSupport(coordinatorType: "zStack3x0"), .full)
        XCTAssertEqual(TouchlinkSupport(coordinatorType: "EmberZNet"), .partial)
        XCTAssertEqual(TouchlinkSupport(coordinatorType: "deCONZ"), TouchlinkSupport.none)
        XCTAssertNil(TouchlinkSupport(coordinatorType: nil))
    }
}

extension TouchlinkGuidePageTests {
    func testParserOverviewBecomesAbout() {
        let sections = [
            DocSection(title: "Overview", level: 2, blocks: [.paragraph([.text("Intro")])]),
            DocSection(title: "Scan", level: 2, blocks: [.paragraph([.text("Scan")])])
        ]
        XCTAssertEqual(TouchlinkGuidePage.pages(from: sections).map { $0.title }, ["About Touchlink", "Scan"])
    }
}
