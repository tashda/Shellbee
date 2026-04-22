import XCTest
@testable import Shellbee

final class JSONValueTests: XCTestCase {

    // MARK: - Decoding

    @MainActor

    func testDecodeNull() throws {
        let v = try decode("null")
        XCTAssertEqual(v, .null)
    }

    @MainActor

    func testDecodeBoolTrue() throws {
        let v = try decode("true")
        XCTAssertEqual(v, .bool(true))
    }

    @MainActor

    func testDecodeBoolFalse() throws {
        let v = try decode("false")
        XCTAssertEqual(v, .bool(false))
    }

    @MainActor

    func testDecodeInt() throws {
        let v = try decode("42")
        XCTAssertEqual(v, .int(42))
    }

    @MainActor

    func testDecodeNegativeInt() throws {
        let v = try decode("-7")
        XCTAssertEqual(v, .int(-7))
    }

    @MainActor

    func testDecodeDouble() throws {
        let v = try decode("3.14")
        XCTAssertEqual(v, .double(3.14))
    }

    @MainActor

    func testDecodeString() throws {
        let v = try decode(#""hello""#)
        XCTAssertEqual(v, .string("hello"))
    }

    @MainActor

    func testDecodeEmptyString() throws {
        let v = try decode(#""""#)
        XCTAssertEqual(v, .string(""))
    }

    @MainActor

    func testDecodeArray() throws {
        let v = try decode("[1,2,3]")
        XCTAssertEqual(v, .array([.int(1), .int(2), .int(3)]))
    }

    @MainActor

    func testDecodeEmptyArray() throws {
        let v = try decode("[]")
        XCTAssertEqual(v, .array([]))
    }

    @MainActor

    func testDecodeObject() throws {
        let v = try decode(#"{"a":1}"#)
        XCTAssertEqual(v, .object(["a": .int(1)]))
    }

    @MainActor

    func testDecodeNestedObject() throws {
        let v = try decode(#"{"x":{"y":true}}"#)
        XCTAssertEqual(v, .object(["x": .object(["y": .bool(true)])]))
    }

    // MARK: - Round-trip

    @MainActor

    func testRoundTripObject() throws {
        let original = JSONValue.object(["name": .string("test"), "value": .int(42), "flag": .bool(true)])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    @MainActor

    func testRoundTripNestedArray() throws {
        let original = JSONValue.array([.int(1), .object(["k": .string("v")]), .null])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Accessors

    @MainActor

    func testStringValue() {
        XCTAssertEqual(JSONValue.string("hello").stringValue, "hello")
        XCTAssertNil(JSONValue.int(1).stringValue)
    }

    @MainActor

    func testBoolValue() {
        XCTAssertEqual(JSONValue.bool(true).boolValue, true)
        XCTAssertNil(JSONValue.string("true").boolValue)
    }

    @MainActor

    func testIntValue() {
        XCTAssertEqual(JSONValue.int(99).intValue, 99)
        XCTAssertNil(JSONValue.double(1.5).intValue)
    }

    @MainActor

    func testObjectValue() {
        let obj = JSONValue.object(["k": .string("v")])
        XCTAssertNotNil(obj.object)
        XCTAssertNil(JSONValue.string("x").object)
    }

    @MainActor

    func testArrayValue() {
        XCTAssertNotNil(JSONValue.array([.int(1)]).array)
        XCTAssertNil(JSONValue.null.array)
    }

    @MainActor

    func testNumberValueFromInt() {
        XCTAssertEqual(JSONValue.int(5).numberValue, 5.0)
    }

    @MainActor

    func testNumberValueFromDouble() {
        XCTAssertEqual(JSONValue.double(2.5).numberValue, 2.5)
    }

    @MainActor

    func testNumberValueFromString() {
        XCTAssertNil(JSONValue.string("5").numberValue)
    }

    // MARK: - stringified

    @MainActor

    func testStringifiedNull() {
        XCTAssertEqual(JSONValue.null.stringified, "None")
    }

    @MainActor

    func testStringifiedBoolOn() {
        XCTAssertEqual(JSONValue.bool(true).stringified, "On")
    }

    @MainActor

    func testStringifiedBoolOff() {
        XCTAssertEqual(JSONValue.bool(false).stringified, "Off")
    }

    @MainActor

    func testStringifiedInt() {
        XCTAssertEqual(JSONValue.int(42).stringified, "42")
    }

    @MainActor

    func testStringifiedString() {
        XCTAssertEqual(JSONValue.string("hello").stringified, "hello")
    }

    // MARK: - value(at:)

    @MainActor

    func testValueAtEmptyPath() {
        let v = JSONValue.string("x")
        XCTAssertEqual(v.value(at: []), v)
    }

    @MainActor

    func testValueAtSingleKey() {
        let v = JSONValue.object(["a": .int(1)])
        XCTAssertEqual(v.value(at: ["a"]), .int(1))
    }

    @MainActor

    func testValueAtNestedPath() {
        let v = JSONValue.object(["x": .object(["y": .string("deep")])])
        XCTAssertEqual(v.value(at: ["x", "y"]), .string("deep"))
    }

    @MainActor

    func testValueAtMissingKey() {
        let v = JSONValue.object(["a": .int(1)])
        XCTAssertNil(v.value(at: ["z"]))
    }

    @MainActor

    func testValueAtPathOnNonObject() {
        XCTAssertNil(JSONValue.int(1).value(at: ["a"]))
    }

    // MARK: - Helpers

    @MainActor
    private func decode(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }
}
