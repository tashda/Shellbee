import XCTest
@testable import Shellbee

@MainActor
final class DocLibraryFiltersTests: XCTestCase {
    private let colorBulb = DocLibraryFiltersTests.entry("color", ["light", "light.brightness", "light.color_temp", "light.color_xy", "effect"])
    private let whiteBulb = DocLibraryFiltersTests.entry("white", ["light", "light.brightness", "light.color_temp"])
    private let dimmable = DocLibraryFiltersTests.entry("dim", ["light", "light.brightness", "battery"])

    func testLightFeaturesTellBulbsApart() {
        XCTAssertEqual(matching(.color), ["color"])
        XCTAssertEqual(matching(.whiteSpectrum), ["color", "white"])
        XCTAssertEqual(matching(.dimmableOnly), ["dim"])
        XCTAssertEqual(matching(.effects), ["color"])
    }

    func testFiltersCombine() {
        var filters = DocLibraryFilters()
        filters.features = [.whiteSpectrum]
        filters.power = .mains
        XCTAssertEqual([colorBulb, whiteBulb, dimmable].filter { filters.matches($0, owned: [:]) }.map { $0.docKey }, ["color", "white"])

        filters = DocLibraryFilters(inNetworkOnly: true)
        XCTAssertEqual([colorBulb, whiteBulb].filter { filters.matches($0, owned: [whiteBulb.ownershipKey: 1]) }.map { $0.docKey }, ["white"])
    }

    func testTypeAndManufacturerNarrow() {
        let plug = DocBrowserEntry(docKey: "plug", imageKey: nil, model: "plug", vendor: "IKEA", description: "plug", exposes: ["switch", "power"])
        let bulb = DocBrowserEntry(docKey: "bulb", imageKey: nil, model: "bulb", vendor: "IKEA", description: "bulb", exposes: ["light"])
        let hue = DocBrowserEntry(docKey: "hue", imageKey: nil, model: "hue", vendor: "Philips", description: "hue", exposes: ["light"])
        let all = [plug, bulb, hue]

        var filters = DocLibraryFilters(type: .type(.light))
        XCTAssertEqual(all.filter { filters.matches($0, owned: [:]) }.map { $0.docKey }, ["bulb", "hue"])

        filters.vendor = "IKEA"
        XCTAssertEqual(all.filter { filters.matches($0, owned: [:]) }.map { $0.docKey }, ["bulb"])
        XCTAssertTrue(filters.isActive)

        let other = DocBrowserEntry(docKey: "x", imageKey: nil, model: "x", vendor: "IKEA", description: "x", exposes: [])
        XCTAssertTrue(DocLibraryFilters(type: .other).matches(other, owned: [:]))
        XCTAssertFalse(DocLibraryFilters(type: .other).matches(plug, owned: [:]))
    }

    private func matching(_ feature: DocLibraryFeature) -> [String] {
        [colorBulb, whiteBulb, dimmable].filter { feature.matches($0) }.map { $0.docKey }
    }

    private nonisolated static func entry(_ key: String, _ exposes: [String]) -> DocBrowserEntry {
        DocBrowserEntry(docKey: key, imageKey: nil, model: key, vendor: "Test", description: key, exposes: exposes)
    }
}
