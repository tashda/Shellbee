import Foundation

struct LogMessage: Decodable, Identifiable, Sendable {
    let id: UUID
    let level: String
    let message: String
    let namespace: String?

    init(from decoder: any Decoder) throws {
        id = UUID()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = (try? c.decode(String.self, forKey: .level)) ?? "info"
        message = (try? c.decode(String.self, forKey: .message)) ?? ""
        namespace = try? c.decodeIfPresent(String.self, forKey: .namespace)
    }

    enum CodingKeys: String, CodingKey {
        case level, message, namespace
    }
}

extension LogMessage {
    var levelColor: String {
        switch level {
        case "error": return "red"
        case "warning": return "yellow"
        case "debug": return "secondary"
        default: return "primary"
        }
    }
}
