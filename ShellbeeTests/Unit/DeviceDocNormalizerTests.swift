import XCTest
@testable import Shellbee

@MainActor
final class DeviceDocNormalizerTests: XCTestCase {
    func testNormalizesNestedPairingFromNotes() {
        let parsed = ParsedDeviceDoc(sections: [
            DocSection(title: "Notes", level: 2, blocks: [
                .subsection(title: "Pairing", blocks: [
                    .paragraph([.text("Press the pair button 4 times in a row.")]),
                    .note([.text("Keep the switch close to the coordinator.")])
                ]),
                .subsection(title: "Battery", blocks: [
                    .paragraph([.text("Uses 1 x CR2032 battery")])
                ])
            ])
        ])

        let normalized = DeviceDocNormalizer.normalize(parsed: parsed, device: DeviceFixture.remote())

        XCTAssertNotNil(normalized.pairing)
        XCTAssertEqual(normalized.pairing?.primarySteps.count, 1)
        XCTAssertFalse(normalized.notesSections.isEmpty)
    }

    func testNormalizesTopLevelPairingAlternatives() {
        let parsed = ParsedDeviceDoc(sections: [
            DocSection(title: "Pairing", level: 2, blocks: [
                .subsection(title: "Power Cycling", blocks: [
                    .paragraph([.text("Turn the bulb off and on six times.")]),
                    .stepList([
                        StepItem(number: 1, spans: [.text("Turn the bulb off and on six times.")]),
                        StepItem(number: 2, spans: [.text("Wait for the bulb to blink.")])
                    ])
                ]),
                .subsection(title: "Touchlink", blocks: [
                    .paragraph([.text("Use Touchlink reset if supported.")])
                ])
            ])
        ])

        let normalized = DeviceDocNormalizer.normalize(parsed: parsed, device: DeviceFixture.light())

        XCTAssertEqual(normalized.pairing?.alternatives.count, 2)
        XCTAssertTrue(normalized.pairing?.summary.isEmpty == false)
    }

    func testCollectsOptionsAndPreservesResidualBlocks() {
        let parsed = ParsedDeviceDoc(sections: [
            DocSection(title: "Options", level: 2, blocks: [
                .paragraph([.text("How to use device type specific configuration.")]),
                .optionsList([
                    DocOption(name: "transition", type: "number", description: [.text("Transition time.")])
                ])
            ])
        ])

        let normalized = DeviceDocNormalizer.normalize(parsed: parsed, device: DeviceFixture.light())

        XCTAssertEqual(normalized.options.map(\.name), ["transition"])
        XCTAssertEqual(normalized.miscSections.count, 1)
    }

    func testGracefullyKeepsUnknownSections() {
        let parsed = ParsedDeviceDoc(sections: [
            DocSection(title: "Very Custom Vendor Notes", level: 2, blocks: [
                .paragraph([.text("Something unusual.")])
            ])
        ])

        let normalized = DeviceDocNormalizer.normalize(parsed: parsed, device: DeviceFixture.sensor())

        XCTAssertEqual(normalized.notesSections.count, 1)
        XCTAssertEqual(normalized.quality, .fullyNormalized)
    }

    func testLocalCorpusParsesAndNormalizesWithoutEmptyScreen() throws {
        let root = URL(fileURLWithPath: "/Users/k/Tools/ReferenceProjects/zigbee2mqtt.io/docs/devices", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw XCTSkip("Local Zigbee2MQTT docs corpus not available")
        }

        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }

        XCTAssertFalse(files.isEmpty)

        for url in files {
            let raw = try String(contentsOf: url, encoding: .utf8)
            let parsed = DocParser.parse(raw)
            let model = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: "/")
            let device = DeviceFixture.light(model: model)
            let normalized = DeviceDocNormalizer.normalize(parsed: parsed, device: device)

            if !parsed.sections.isEmpty {
                let hasRenderedContent =
                    normalized.pairing != nil
                    || !normalized.capabilities.isEmpty
                    || !normalized.options.isEmpty
                    || !normalized.notesSections.isEmpty
                    || !normalized.additionalSections.isEmpty
                XCTAssertTrue(hasRenderedContent, "Expected content for \(url.lastPathComponent)")
            }
        }
    }
}
