import Foundation
import Security

struct ConnectionConfig: Codable, Sendable {
    private static let savedConfigKey = "lastSuccessfulConnectionConfig"
    private static let legacySavedConfigKey = "connectionConfig"

    var host: String
    var port: Int
    var useTLS: Bool
    var basePath: String
    var authToken: String?
    var name: String? = nil

    static let defaultPort = 8080

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return host
    }
}

extension ConnectionConfig: Equatable, Hashable {
    static func == (lhs: ConnectionConfig, rhs: ConnectionConfig) -> Bool {
        lhs.host == rhs.host
            && lhs.port == rhs.port
            && lhs.useTLS == rhs.useTLS
            && lhs.basePath == rhs.basePath
            && lhs.authToken == rhs.authToken
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(host)
        hasher.combine(port)
        hasher.combine(useTLS)
        hasher.combine(basePath)
        hasher.combine(authToken)
    }

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

    var secretLookupKey: String {
        let normalizedBase = basePath.hasSuffix("/") ? basePath : "\(basePath)/"
        return "\(host.lowercased())|\(port)|\(useTLS ? "tls" : "plain")|\(normalizedBase)"
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
        return ConnectionConfig(host: host, port: port, useTLS: useTLS, basePath: path, authToken: nil, name: nil)
    }

    static func load() -> ConnectionConfig? {
        guard let data = UserDefaults.standard.data(forKey: Self.savedConfigKey) else { return nil }

        // Older payloads still decode as PersistedSnapshot because extra JSON keys are ignored.
        if containsLegacyToken(in: data),
           let legacy = try? JSONDecoder().decode(ConnectionConfig.self, from: data) {
            persistToken(for: legacy)
            UserDefaults.standard.set(try? JSONEncoder().encode(legacy.persistedSnapshot), forKey: Self.savedConfigKey)
            return legacy
        }

        if let snapshot = try? JSONDecoder().decode(PersistedSnapshot.self, from: data) {
            return snapshot.connectionConfig
        }

        return nil
    }

    func save() {
        guard let data = try? JSONEncoder().encode(persistedSnapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.savedConfigKey)
        Self.persistToken(for: self)
    }

    static func clear() {
        if let config = load() {
            removeToken(for: config)
        }
        UserDefaults.standard.removeObject(forKey: Self.savedConfigKey)
        UserDefaults.standard.removeObject(forKey: Self.legacySavedConfigKey)
    }

    var persistedSnapshot: PersistedSnapshot {
        PersistedSnapshot(host: host, port: port, useTLS: useTLS, basePath: basePath, name: name)
    }

    static func persistToken(for config: ConnectionConfig) {
        ConnectionTokenKeychain.shared.setToken(config.authToken, for: config.secretLookupKey)
    }

    static func removeToken(for config: ConnectionConfig) {
        ConnectionTokenKeychain.shared.removeToken(for: config.secretLookupKey)
    }

    static func containsLegacyToken(in data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return false
        }

        if let dictionary = object as? [String: Any] {
            return dictionary["authToken"] != nil || dictionary["auth_token"] != nil
        }

        if let dictionaries = object as? [[String: Any]] {
            return dictionaries.contains { $0["authToken"] != nil || $0["auth_token"] != nil }
        }

        return false
    }

    #if DEBUG
    static func clearPersistedSecretsForTests() {
        ConnectionTokenKeychain.shared.removeAllTokensForTests()
    }
    #endif
}

extension ConnectionConfig {
    struct PersistedSnapshot: Codable {
        let host: String
        let port: Int
        let useTLS: Bool
        let basePath: String
        let name: String?

        init(host: String, port: Int, useTLS: Bool, basePath: String, name: String? = nil) {
            self.host = host
            self.port = port
            self.useTLS = useTLS
            self.basePath = basePath
            self.name = name
        }

        var connectionConfig: ConnectionConfig {
            let lookup = ConnectionConfig(
                host: host,
                port: port,
                useTLS: useTLS,
                basePath: basePath,
                authToken: nil,
                name: nil
            )

            return ConnectionConfig(
                host: host,
                port: port,
                useTLS: useTLS,
                basePath: basePath,
                authToken: ConnectionTokenKeychain.shared.token(for: lookup.secretLookupKey),
                name: name
            )
        }
    }
}

private final class ConnectionTokenKeychain {
    static let shared = ConnectionTokenKeychain()

    private let service = "dev.echodb.shellbee.connection-token"
    private let accountPrefix = "z2m:"

    func token(for lookupKey: String) -> String? {
        var query = baseQuery(for: lookupKey)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    func setToken(_ token: String?, for lookupKey: String) {
        guard let token, !token.isEmpty else {
            removeToken(for: lookupKey)
            return
        }

        let data = Data(token.utf8)
        let query = baseQuery(for: lookupKey)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func removeToken(for lookupKey: String) {
        SecItemDelete(baseQuery(for: lookupKey) as CFDictionary)
    }

    #if DEBUG
    func removeAllTokensForTests() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let entries = item as? [[String: Any]] else {
            return
        }

        for entry in entries {
            guard let account = entry[kSecAttrAccount as String] as? String,
                  account.hasPrefix(accountPrefix) else {
                continue
            }

            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(deleteQuery as CFDictionary)
        }
    }
    #endif

    private func baseQuery(for lookupKey: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(accountPrefix)\(lookupKey)",
        ]
    }
}
