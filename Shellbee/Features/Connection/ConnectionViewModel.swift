import Foundation
import SwiftUI

@Observable
final class ConnectionViewModel {
    var isEditorPresented = false
    var name = ""
    var host = ""
    var port = "8080"
    var useTLS = false
    var basePath = "/"
    var authToken = ""
    var allowInvalidCertificates = false
    var autoConnect = false
    var bridgeColor: Color?
    var usesAutoBridgeColor = true

    var discoveredEndpoints: [DiscoveredEndpoint] {
        Array(environment.discovery.discoveredEndpoints)
            .sorted { lhs, rhs in
                if lhs.host != rhs.host { return lhs.host < rhs.host }
                return lhs.port < rhs.port
            }
    }

    @MainActor
    var isScanning: Bool {
        environment.discovery.isScanning
    }

    var history: [ConnectionConfig] {
        environment.history.connections
    }

    var displayURL: String {
        buildConfig().displayURL
    }

    var editorTitle: String {
        editingConnection == nil ? "Add Server" : "Edit Server"
    }

    var canSaveDraft: Bool {
        validate(showErrors: false)
    }

    var errorMessage: String? {
        get { environment.registry.primary?.controller.errorMessage }
        set {
            if newValue == nil, let bridgeID = environment.registry.primaryBridgeID {
                environment.clearErrorMessage(bridgeID: bridgeID)
            }
        }
    }

    var connectionState: ConnectionSessionController.State {
        environment.registry.primary?.controller.connectionState ?? .idle
    }

    var isConnecting: Bool {
        switch connectionState {
        case .connecting, .reconnecting:
            return true
        default:
            return false
        }
    }

    private let environment: AppEnvironment
    private var editingConnection: ConnectionConfig?

    init(environment: AppEnvironment) {
        self.environment = environment
        if let config = environment.registry.primary?.config {
            apply(config)
        }
    }

    func startDiscovery() {
        Task { @MainActor in
            environment.discovery.start()
            try? await Task.sleep(for: .seconds(DesignTokens.Duration.discoveryScanWindow))
            environment.discovery.stop()
        }
    }

    func stopDiscovery() {
        Task { @MainActor in
            environment.discovery.stop()
        }
    }

    func deleteConnection(_ config: ConnectionConfig) {
        environment.history.remove(config)
    }

    func connect(to config: ConnectionConfig) {
        apply(config)
        environment.connect(config: config)
    }

    func presentNewServer(prefilledHost: String? = nil, prefilledPort: UInt16? = nil) {
        editingConnection = nil
        name = ""
        host = prefilledHost ?? ""
        port = prefilledPort.map(String.init) ?? "8080"
        useTLS = false
        basePath = "/"
        authToken = ""
        allowInvalidCertificates = false
        autoConnect = true
        bridgeColor = nil
        usesAutoBridgeColor = true
        isEditorPresented = true
    }

    func presentEditor(for config: ConnectionConfig) {
        editingConnection = config
        apply(config)
        isEditorPresented = true
    }

    func makeEditorDraft() -> ConnectionEditorDraft {
        ConnectionEditorDraft(
            name: name,
            host: host,
            port: port,
            useTLS: useTLS,
            basePath: basePath,
            authToken: authToken,
            allowInvalidCertificates: allowInvalidCertificates,
            autoConnect: autoConnect,
            bridgeColor: bridgeColor,
            usesAutoBridgeColor: usesAutoBridgeColor
        )
    }

    @discardableResult
    func saveServer() -> Bool {
        guard validate(showErrors: true) else { return false }
        let config = buildConfig()

        if let editingConnection {
            environment.history.replace(editingConnection, with: config)
            // Keep any live bridge session in sync so Settings rows reflect
            // edited metadata immediately (without requiring navigation).
            if let session = environment.registry.session(for: editingConnection.id) {
                session.config = config
                session.controller.connectionConfig = config
            }
        } else {
            environment.history.add(config)
        }
        environment.history.setAutoConnect(config, autoConnect)
        let selectedColor = usesAutoBridgeColor ? nil : bridgeColor
        DesignTokens.Bridge.setCustomColor(selectedColor, for: config.id)

        editingConnection = config
        return true
    }

    @discardableResult
    func connectDraft() -> Bool {
        guard saveServer() else { return false }
        environment.connect(config: buildConfig())
        return true
    }

    @discardableResult
    func connect(using draft: ConnectionEditorDraft) -> Bool {
        applyDraft(draft)
        return connectDraft()
    }

    /// Save the current draft to the saved-bridges list without connecting.
    /// Used by the "Add Bridge" flow in `SavedBridgesView` so registering an
    /// additional bridge doesn't disrupt the active session.
    @discardableResult
    func save(using draft: ConnectionEditorDraft) -> Bool {
        applyDraft(draft)
        return saveServer()
    }

    private func applyDraft(_ draft: ConnectionEditorDraft) {
        name = draft.name
        host = draft.host
        port = draft.port
        useTLS = draft.useTLS
        basePath = draft.basePath
        authToken = draft.authToken
        allowInvalidCertificates = draft.useTLS ? draft.allowInvalidCertificates : false
        autoConnect = draft.autoConnect
        bridgeColor = draft.bridgeColor
        usesAutoBridgeColor = draft.usesAutoBridgeColor
    }

    func cancel() async {
        guard let bridgeID = environment.registry.primaryBridgeID else { return }
        await environment.cancelConnection(bridgeID: bridgeID)
    }

    func matchesCurrentConfig(_ config: ConnectionConfig) -> Bool {
        environment.registry.primary?.config == config
    }

    func buildConfig() -> ConnectionConfig {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        return ConnectionConfig(
            id: editingConnection?.id ?? UUID(),
            host: host.trimmingCharacters(in: .whitespaces),
            port: Int(port) ?? ConnectionConfig.defaultPort,
            useTLS: useTLS,
            basePath: basePath.isEmpty ? "/" : basePath,
            authToken: authToken.isEmpty ? nil : authToken,
            name: trimmedName.isEmpty ? nil : trimmedName,
            allowInvalidCertificates: useTLS ? allowInvalidCertificates : false
        )
    }

    private func validate(showErrors: Bool) -> Bool {
        guard !host.trimmingCharacters(in: .whitespaces).isEmpty else {
            if showErrors {
                errorMessage = "Please enter a host address."
            }
            return false
        }

        guard let portNum = Int(port), portNum > 0, portNum <= 65535 else {
            if showErrors {
                errorMessage = "Port must be a number between 1 and 65535."
            }
            return false
        }

        if showErrors {
            errorMessage = nil
        }
        return true
    }

    private func apply(_ config: ConnectionConfig) {
        name = config.name ?? ""
        host = config.host
        port = String(config.port)
        useTLS = config.useTLS
        basePath = config.basePath
        authToken = config.authToken ?? ""
        allowInvalidCertificates = config.allowInvalidCertificates
        autoConnect = environment.history.isAutoConnect(config)
        if let hex = DesignTokens.Bridge.customColorHex(for: config.id),
           let color = DesignTokens.Bridge.colorFromHex(hex) {
            bridgeColor = color
            usesAutoBridgeColor = false
        } else {
            bridgeColor = nil
            usesAutoBridgeColor = true
        }
    }
}
