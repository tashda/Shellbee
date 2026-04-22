import Foundation

struct PendingCrash: Codable, Identifiable {
    let id: UUID
    let capturedAt: Date
    let summary: String
    let eventID: String?

    init(id: UUID = UUID(), capturedAt: Date = Date(), summary: String, eventID: String?) {
        self.id = id
        self.capturedAt = capturedAt
        self.summary = summary
        self.eventID = eventID
    }
}

enum PendingCrashStore {
    private static let fileName = "pending-crash.json"

    private static var fileURL: URL? {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = dir.appendingPathComponent("CrashReporting", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(fileName)
    }

    static func save(_ crash: PendingCrash) {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(crash)
            try data.write(to: url, options: .atomic)
        } catch {
            // Swallow — this path is best-effort and must never itself crash.
        }
    }

    static func load() -> PendingCrash? {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(PendingCrash.self, from: $0) }
    }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
