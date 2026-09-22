import SwiftUI
import XCTest
@testable import Shellbee

@MainActor
final class LightDisplayColorTests: XCTestCase {
    func testXYResolvesToItsHue() {
        let red = rgb(LightDisplayColor.resolve(state: ["color": .object(["x": .double(0.68), "y": .double(0.31)])]))
        XCTAssertGreaterThan(red.r, red.g)
        XCTAssertGreaterThan(red.r, red.b)
    }

    func testHueSaturationScalesAgree() {
        let percent = rgb(LightDisplayColor.resolve(state: ["color": .object(["hue": .int(240), "saturation": .int(100)])]))
        let zigbee = rgb(LightDisplayColor.resolve(state: ["color": .object(["h": .int(240), "s": .int(254)])]))
        let tuya = rgb(LightDisplayColor.resolve(state: ["color": .object(["h": .int(240), "s": .int(1_000)])]))
        let enhanced = rgb(LightDisplayColor.resolve(state: ["color": .object(["hue": .int(43_690), "saturation": .int(100)])]))
        for color in [percent, zigbee, tuya, enhanced] {
            XCTAssertEqual(color.b, 1, accuracy: 0.02)
            XCTAssertEqual(color.r, 0, accuracy: 0.02)
        }
    }

    func testHueWithoutSaturationIsFullySaturated() {
        let color = rgb(LightDisplayColor.resolve(state: ["color": .object(["hue": .int(120)])]))
        XCTAssertEqual(color.g, 1, accuracy: 0.02)
        XCTAssertEqual(color.r, 0, accuracy: 0.02)
    }

    func testRGBBytesAndFractionsAgree() {
        let bytes = rgb(LightDisplayColor.resolve(state: ["color": .object(["r": .int(255), "g": .int(0), "b": .int(0)])]))
        let fractions = rgb(LightDisplayColor.resolve(state: ["color": .object(["r": .double(1), "g": .double(0), "b": .double(0)])]))
        XCTAssertEqual(bytes.r, fractions.r, accuracy: 0.01)
        XCTAssertEqual(bytes.g, fractions.g, accuracy: 0.01)
    }

    func testHexInEveryShape() {
        for value: JSONValue in [.string("#ff0000"), .string("FF0000"), .string("#f00"), .object(["hex": .string("#ff0000")])] {
            let color = rgb(LightDisplayColor.color(property: "color", value: value))
            XCTAssertEqual(color.r, 1, accuracy: 0.01)
            XCTAssertEqual(color.g, 0, accuracy: 0.01)
        }
    }

    func testColourTemperatureInMiredsOrKelvin() {
        let mireds = rgb(LightDisplayColor.color(property: "color_temp", value: .int(370)))
        let kelvin = rgb(LightDisplayColor.color(property: "color_temp", value: .int(2_703)))
        XCTAssertEqual(mireds.r, kelvin.r, accuracy: 0.01)
        XCTAssertEqual(mireds.b, kelvin.b, accuracy: 0.01)
        XCTAssertGreaterThan(mireds.r, mireds.b, "2700 K should read warm")
    }

    func testColorModeDecidesBetweenReportedFormats() {
        let state: [String: JSONValue] = [
            "color": .object(["x": .double(0.68), "y": .double(0.31), "hue": .int(240), "saturation": .int(100)]),
            "color_temp": .int(153)
        ]
        var hs = state
        hs["color_mode"] = .string("hs")
        XCTAssertGreaterThan(rgb(LightDisplayColor.resolve(state: hs)).b, 0.9)

        var temp = state
        temp["color_mode"] = .string("color_temp")
        let cool = rgb(LightDisplayColor.resolve(state: temp))
        XCTAssertGreaterThan(cool.b, 0.9, "153 mired is cool white")
    }

    func testStateWithoutColourIsNil() {
        XCTAssertNil(LightDisplayColor.resolve(state: ["state": .string("ON"), "brightness": .int(200)]))
    }

    private func rgb(_ color: Color?, file: StaticString = #filePath, line: UInt = #line) -> (r: Double, g: Double, b: Double) {
        guard let color else {
            XCTFail("Expected a colour", file: file, line: line)
            return (0, 0, 0)
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}
