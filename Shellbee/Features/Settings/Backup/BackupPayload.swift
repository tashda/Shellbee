import Foundation

/// Decoding + integrity checks for the zip payload returned by Z2M's
/// `bridge/response/backup`. Pulled out of `BackupView` so it's unit-testable
/// without spinning up SwiftUI state.
nonisolated enum BackupPayload {

    enum Failure: LocalizedError {
        case invalidBase64
        case empty
        case notAZipFile

        var errorDescription: String? {
            switch self {
            case .invalidBase64: return "Backup data was not valid base64."
            case .empty: return "Backup file was empty."
            case .notAZipFile: return "Backup file is not a valid zip archive."
            }
        }
    }

    /// First four bytes of every zip local file header.
    static let zipMagic: [UInt8] = [0x50, 0x4B, 0x03, 0x04]

    /// Decode tolerantly — `.ignoreUnknownCharacters` so embedded whitespace or
    /// newlines from upstream serialisers don't cause a silent decode failure.
    static func decode(base64: String) throws -> Data {
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            throw Failure.invalidBase64
        }
        guard !data.isEmpty else { throw Failure.empty }
        return data
    }

    /// Confirm the file we just wrote is a real zip — not zero bytes and not
    /// some HTML error page or truncated payload that base64-decoded cleanly.
    static func verifyZip(at url: URL) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs[.size] as? Int) ?? 0
        guard size >= zipMagic.count else { throw Failure.empty }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let head = try handle.read(upToCount: zipMagic.count) ?? Data()
        guard Array(head) == zipMagic else { throw Failure.notAZipFile }
    }
}
