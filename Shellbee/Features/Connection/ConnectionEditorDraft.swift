import Foundation

struct ConnectionEditorDraft {
    var name: String
    var host: String
    var port: String
    var useTLS: Bool
    var basePath: String
    var authToken: String
    var allowInvalidCertificates: Bool

    init(
        name: String = "",
        host: String = "",
        port: String = "8080",
        useTLS: Bool = false,
        basePath: String = "/",
        authToken: String = "",
        allowInvalidCertificates: Bool = false
    ) {
        self.name = name
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.basePath = basePath
        self.authToken = authToken
        self.allowInvalidCertificates = allowInvalidCertificates
    }

    var canConnect: Bool {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty else { return false }
        guard let portNumber = Int(port), portNumber > 0, portNumber <= 65535 else { return false }
        return true
    }
}
