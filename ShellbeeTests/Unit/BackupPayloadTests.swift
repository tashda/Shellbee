import XCTest
@testable import Shellbee

final class BackupPayloadTests: XCTestCase {

    private static let zipBytes: [UInt8] = [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00]

    func testDecodeAcceptsCleanBase64() throws {
        let base64 = Data(Self.zipBytes).base64EncodedString()
        let decoded = try BackupPayload.decode(base64: base64)
        XCTAssertEqual(Array(decoded), Self.zipBytes)
    }

    func testDecodeAcceptsBase64WithEmbeddedNewlinesAndWhitespace() throws {
        // Some MQTT/WS serializers wrap long base64 strings at column boundaries.
        // Default Data(base64Encoded:) options would reject this.
        let raw = Data(Self.zipBytes).base64EncodedString()
        let chunked = raw.enumerated()
            .map { index, char in (index > 0 && index % 4 == 0) ? "\n\(char)" : "\(char)" }
            .joined()
        let withSpaces = "  \(chunked)\t\n"
        let decoded = try BackupPayload.decode(base64: withSpaces)
        XCTAssertEqual(Array(decoded), Self.zipBytes)
    }

    func testDecodeRejectsInvalidBase64() {
        XCTAssertThrowsError(try BackupPayload.decode(base64: "!!!not-base64!!!")) { error in
            XCTAssertEqual(error as? BackupPayload.Failure, .invalidBase64)
        }
    }

    func testDecodeRejectsEmptyPayload() {
        XCTAssertThrowsError(try BackupPayload.decode(base64: "")) { error in
            XCTAssertEqual(error as? BackupPayload.Failure, .empty)
        }
    }

    func testVerifyZipAcceptsFileWithZipMagic() throws {
        let url = try writeTempFile(bytes: Self.zipBytes)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNoThrow(try BackupPayload.verifyZip(at: url))
    }

    func testVerifyZipRejectsWrongMagicBytes() throws {
        let url = try writeTempFile(bytes: [0x3C, 0x68, 0x74, 0x6D, 0x6C, 0x3E]) // "<html>"
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try BackupPayload.verifyZip(at: url)) { error in
            XCTAssertEqual(error as? BackupPayload.Failure, .notAZipFile)
        }
    }

    func testVerifyZipRejectsTooSmallFile() throws {
        let url = try writeTempFile(bytes: [0x50, 0x4B]) // truncated
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try BackupPayload.verifyZip(at: url)) { error in
            XCTAssertEqual(error as? BackupPayload.Failure, .empty)
        }
    }

    private func writeTempFile(bytes: [UInt8]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-test-\(UUID().uuidString).zip")
        try Data(bytes).write(to: url)
        return url
    }
}
