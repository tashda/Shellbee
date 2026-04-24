import XCTest
@testable import Shellbee

/// Locks in the exact wire shape of `bridge/request/options` so we can rule
/// out the Swift side when debugging "Invalid payload" errors from z2m.
final class BridgeOptionsPayloadTests: XCTestCase {

    @MainActor
    func testElapsedToggleProducesOptionsWrappedAdvancedPayload() throws {
        let payload: JSONValue = .object([
            "options": .object([
                "advanced": .object(["elapsed": .bool(true)])
            ])
        ])
        let envelope = Z2MOutboundEnvelope(topic: "bridge/request/options", payload: payload)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertEqual(
            json,
            #"{"payload":{"options":{"advanced":{"elapsed":true}}},"topic":"bridge\/request\/options"}"#
        )
    }

    @MainActor
    func testRoundTripMatchesZ2MHandlerExpectations() throws {
        // z2m's bridgeOptions handler requires `typeof message.options === "object"`.
        // Decode our own wire format the same way z2m would to prove the shape.
        let payload: JSONValue = .object([
            "options": .object([
                "advanced": .object(["last_seen": .string("ISO_8601_local")])
            ])
        ])
        let envelope = Z2MOutboundEnvelope(topic: "bridge/request/options", payload: payload)
        let data = try JSONEncoder().encode(envelope)

        struct WireEnvelope: Decodable {
            let topic: String
            let payload: [String: JSONValue]
        }
        let decoded = try JSONDecoder().decode(WireEnvelope.self, from: data)

        XCTAssertEqual(decoded.topic, "bridge/request/options")
        guard case .object(let inner)? = decoded.payload["options"] else {
            XCTFail("payload.options must be an object — z2m will reject otherwise")
            return
        }
        guard case .object(let advanced)? = inner["advanced"] else {
            XCTFail("payload.options.advanced must be an object")
            return
        }
        XCTAssertEqual(advanced["last_seen"], .string("ISO_8601_local"))
    }
}
