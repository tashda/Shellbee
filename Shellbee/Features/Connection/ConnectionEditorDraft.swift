import Foundation
import SwiftUI

struct ConnectionEditorDraft: Equatable {
    var name: String
    var host: String
    var port: String
    var useTLS: Bool
    var basePath: String
    var authToken: String
    var allowInvalidCertificates: Bool
    /// When true, the app reconnects to this bridge automatically on every
    /// launch. Multi-bridge: every flagged bridge is connected concurrently
    /// at startup. Persisted in `ConnectionHistory.autoConnectIDs`.
    var autoConnect: Bool
    /// User-chosen custom bridge color. Nil means auto color.
    var bridgeColor: Color?
    /// True when this draft should follow automatic bridge-color selection.
    var usesAutoBridgeColor: Bool

    init(
        name: String = "",
        host: String = "",
        port: String = "8080",
        useTLS: Bool = false,
        basePath: String = "/",
        authToken: String = "",
        allowInvalidCertificates: Bool = false,
        autoConnect: Bool = false,
        bridgeColor: Color? = nil,
        usesAutoBridgeColor: Bool = true
    ) {
        self.name = name
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.basePath = basePath
        self.authToken = authToken
        self.allowInvalidCertificates = allowInvalidCertificates
        self.autoConnect = autoConnect
        self.bridgeColor = bridgeColor
        self.usesAutoBridgeColor = usesAutoBridgeColor
    }

    var canConnect: Bool {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty else { return false }
        guard let portNumber = Int(port), portNumber > 0, portNumber <= 65535 else { return false }
        return true
    }

    func normalizedForComparison() -> ConnectionEditorDraft {
        var copy = self
        copy.name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.host = copy.host.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.port = copy.port.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.basePath = copy.basePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.basePath.isEmpty {
            copy.basePath = "/"
        }
        copy.authToken = copy.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if let color = copy.bridgeColor, DesignTokens.Bridge.hexString(for: color) == nil {
            copy.bridgeColor = nil
        }
        if copy.bridgeColor == nil {
            copy.usesAutoBridgeColor = true
        }
        return copy
    }
}

extension ConnectionEditorDraft {
    static func == (lhs: ConnectionEditorDraft, rhs: ConnectionEditorDraft) -> Bool {
        lhs.name == rhs.name &&
        lhs.host == rhs.host &&
        lhs.port == rhs.port &&
        lhs.useTLS == rhs.useTLS &&
        lhs.basePath == rhs.basePath &&
        lhs.authToken == rhs.authToken &&
        lhs.allowInvalidCertificates == rhs.allowInvalidCertificates &&
        lhs.autoConnect == rhs.autoConnect &&
        lhs.bridgeColor.map { DesignTokens.Bridge.hexString(for: $0) } ==
        rhs.bridgeColor.map { DesignTokens.Bridge.hexString(for: $0) } &&
        lhs.usesAutoBridgeColor == rhs.usesAutoBridgeColor
    }
}
