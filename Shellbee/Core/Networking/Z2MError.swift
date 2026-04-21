import Foundation

enum Z2MError: LocalizedError {
    case invalidURL
    case notConnected
    case timeout
    case decodingFailed(String)
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL. Check host and port."
        case .notConnected: return "Not connected to Zigbee2MQTT."
        case .timeout: return "Connection timed out. Check that the server is reachable."
        case .decodingFailed(let msg): return "Decoding error: \(msg)"
        case .requestFailed(let msg): return msg
        }
    }
}

extension Z2MError {
    static func interpret(_ error: Error) -> String {
        if let z2m = error as? Z2MError { return z2m.localizedDescription }
        if let url = error as? URLError {
            switch url.code {
            case .secureConnectionFailed, .serverCertificateUntrusted,
                 .clientCertificateRejected, .clientCertificateRequired:
                return "TLS/SSL error. For local servers try disabling 'Use secure connection'."
            case .cannotConnectToHost:
                return "Cannot connect to host. Check address and port."
            case .timedOut:
                return "Connection timed out. Check that the server is running."
            case .notConnectedToInternet, .networkConnectionLost:
                return "No network connection."
            default:
                break
            }
        }
        let msg = error.localizedDescription
        if msg.localizedCaseInsensitiveContains("TLS") || msg.localizedCaseInsensitiveContains("SSL")
            || msg.localizedCaseInsensitiveContains("protocol version") {
            return "TLS/SSL error. For local servers try disabling 'Use secure connection'."
        }
        return msg
    }
}
