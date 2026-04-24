import XCTest
@testable import Shellbee

@MainActor
final class DeviceDocNormalizerTests: XCTestCase {
    // Behavior: a Notes section containing a nested "Pairing" subsection
    // should promote that subsection's content into the pairing guide,
    // while the unrelated "Battery" subsection stays in notesSections.
    //
    // The single paragraph becomes the pairing summary. Paragraphs are
    // deliberately NOT counted as primarySteps — the normalizer only
    // counts real stepList blocks there, to avoid showing the same text
    // twice (as summary AND as an imitation step). A real step-list in
    // the same subsection would populate primarySteps.
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

        XCTAssertNotNil(normalized.pairing, "Pairing subsection should be promoted to a guide")
        XCTAssertFalse(normalized.pairing?.summary.isEmpty == true,
                       "Pairing summary should be the paragraph text")
        XCTAssertTrue(normalized.pairing?.primarySteps.isEmpty == true,
                      "Paragraph alone should not count as a step — only real stepLists do")
        XCTAssertFalse(normalized.notesSections.isEmpty,
                       "Battery subsection should remain in notesSections")
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

    // Behavior: an Options section collects every DocOption into
    // `options`. Any residual non-option blocks that are NOT the z2m
    // boilerplate "device type specific configuration" link survive as a
    // misc section. The boilerplate sentence itself is filtered out so
    // the app doesn't show the upstream docs' stock preamble.
    func testCollectsOptionsAndPreservesResidualBlocks() {
        let parsed = ParsedDeviceDoc(sections: [
            DocSection(title: "Options", level: 2, blocks: [
                .paragraph([.text("Configure transition behaviour by adjusting the values below.")]),
                .optionsList([
                    DocOption(name: "transition", type: "number", description: [.text("Transition time.")])
                ])
            ])
        ])

        let normalized = DeviceDocNormalizer.normalize(parsed: parsed, device: DeviceFixture.light())

        XCTAssertEqual(normalized.options.map(\.name), ["transition"])
        XCTAssertEqual(normalized.miscSections.count, 1,
                       "Non-boilerplate residual paragraphs should remain as a misc section")
    }

    // Behavior: the z2m "device type specific configuration" link is a
    // stock upstream boilerplate. It should be stripped from Options'
    // residual blocks so miscSections stays empty when that is the only
    // non-option content.
    func testOptionsBoilerplateIsStripped() {
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
        XCTAssertTrue(normalized.miscSections.isEmpty,
                      "The stock z2m boilerplate paragraph should be filtered out")
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

    // Behavior: for a diverse set of real upstream z2m device docs —
    // lights, sensors, switches, covers, remotes, locks — the parser +
    // normalizer chain must always produce SOME renderable content
    // (pairing guide, capabilities, options, or note sections). A device
    // with parsed sections but no renderable output would show an empty
    // screen in the Doc Browser.
    //
    // The samples are kept inline instead of reading from the reference
    // corpus on disk: the iOS simulator cannot access `/Users/…` on the
    // host, so a path-based test always skipped in CI.
    func testDiverseCuratedDocsParseAndNormalize() {
        for sample in Self.curatedDocSamples {
            let parsed = DocParser.parse(sample.markdown)
            let device = DeviceFixture.light(model: sample.model)
            let normalized = DeviceDocNormalizer.normalize(parsed: parsed, device: device)

            XCTAssertFalse(parsed.sections.isEmpty,
                           "Parser produced no sections for \(sample.model)")

            let hasRenderedContent =
                normalized.pairing != nil
                || !normalized.capabilities.isEmpty
                || !normalized.options.isEmpty
                || !normalized.notesSections.isEmpty
                || !normalized.additionalSections.isEmpty
            XCTAssertTrue(hasRenderedContent,
                          "Normalizer produced no renderable content for \(sample.model)")
        }
    }

    private struct DocSample {
        let model: String
        let markdown: String
    }

    // Curated slices of real z2m device docs — one per major category.
    private static let curatedDocSamples: [DocSample] = [
        DocSample(model: "LED1545G12", markdown: """
        # IKEA LED1545G12

        ## Notes

        ### Pairing
        Factory reset the light bulb.
        After resetting the bulb will automatically connect.

        While pairing, keep the bulb close to the coordinator (adapter).

        ## OTA updates
        This device supports OTA updates.

        ## Options
        *[How to use device type specific configuration](../guide/configuration/devices-groups.md#specific-device-options)*

        * `transition`: Controls the transition time. The value must be a number with a minimum value of `0`
        """),
        DocSample(model: "WSDCGQ11LM", markdown: """
        # Aqara WSDCGQ11LM

        ## Notes

        ### Battery Type
        Uses a CR2032 battery

        ### Pairing
        Press and hold the reset button on the device for +- 5 seconds.
        After this, the device will automatically join.

        ### Troubleshooting: device stops sending messages
        Since Xiaomi devices do not fully comply to the Zigbee standard, it sometimes happens that they disconnect.

        ## Options
        * `temperature_calibration`: Calibrates the temperature value. The value must be a number.
        """),
        DocSample(model: "E1926", markdown: """
        # IKEA E1926

        ## Notes

        ### Pairing
        Press both buttons on the blind for 5 seconds until a white light turns on.
        The device is now awake and ready to pair for 2 minutes.

        ### End Position
        The roller blind maximum extension can be set by moving the blind to the desired position.

        ## OTA updates
        This device supports OTA updates.

        ## Options
        * `invert_cover`: Inverts the cover position. The value must be `true` or `false`
        """),
        DocSample(model: "TS011F_1", markdown: """
        # Tuya TS011F_1

        ## Options
        * `state_action`: State actions will also be published as 'action' when true. The value must be `true` or `false`

        ## Exposes

        ### Switch
        The current state of this switch is in the published state under the `state` property.
        """),
        DocSample(model: "E1743", markdown: """
        # IKEA E1743

        ## Notes

        ### Pairing
        Press the pair button 4 times in a row with about 1 second delay between the presses.
        A red light will now start blinking.

        ### Battery replacement
        Uses a CR2032 battery.

        ## OTA updates
        This device supports OTA updates.
        """),
        DocSample(model: "BE468", markdown: """
        # Schlage BE468

        ## Notes

        ### Pairing
        Tap "Schlage" button 4 times within 6 seconds to enter pairing mode.

        ### Adding user codes
        Send a JSON message to `zigbee2mqtt/FRIENDLY_NAME/set/pin_code` with the payload `{"user": 0, "pin_code": 1234}`.
        """),
    ]
}
