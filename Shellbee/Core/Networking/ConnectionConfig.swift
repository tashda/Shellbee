import Foundation

struct ConnectionConfig: Codable, Sendable, Equatable, Hashable {
    private static let savedConfigKey = "lastSuccessfulConnectionConfig"
    private static let legacySavedConfigKey = "connectionConfig"

    var host: String
    var port: Int
    var useTLS: Bool
    var basePath: String
    var authToken: String?

    static let defaultPort = 8080

    var webSocketURL: URL? {
        var components = URLComponents()
        components.scheme = useTLS ? "wss" : "ws"
        components.host = host
        let defaultPort = useTLS ? 443 : 80
        components.port = port == defaultPort ? nil : port
        let normalizedBase = basePath.hasSuffix("/") ? basePath : "\(basePath)/"
        components.path = "\(normalizedBase)api"
        if let token = authToken, !token.isEmpty {
            components.queryItems = [URLQueryItem(name: "token", value: token)]
        }
        return components.url
    }

    var displayURL: String {
        let scheme = useTLS ? "https" : "http"
        return "\(scheme)://\(host):\(port)\(basePath)"
    }
}

extension ConnectionConfig {
    static func parse(from input: String) -> ConnectionConfig? {
        var s = input.trimmingCharacters(in: .whitespaces)
        if !s.contains("://") { s = "http://\(s)" }
        guard let url = URL(string: s), let host = url.host, !host.isEmpty else { return nil }
        let useTLS = url.scheme == "https" || url.scheme == "wss"
        let port = url.port ?? (useTLS ? 443 : Self.defaultPort)
        let path = url.path.isEmpty ? "/" : url.path
        return ConnectionConfig(host: host, port: port, useTLS: useTLS, basePath: path, authToken: nil)
    }

    static func load() -> ConnectionConfig? {
        guard let data = UserDefaults.standard.data(forKey: Self.savedConfigKey) else { return nil }
        return try? JSONDecoder().decode(ConnectionConfig.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.savedConfigKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: Self.savedConfigKey)
        UserDefaults.standard.removeObject(forKey: Self.legacySavedConfigKey)
    }
}
