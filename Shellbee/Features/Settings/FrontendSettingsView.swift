import SwiftUI

struct FrontendSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let bridgeID: UUID
    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    @State private var enabled: Bool = true
    @State private var port: Int = 8080
    @State private var host: String = ""
    @State private var url: String = ""
    @State private var baseUrl: String = ""
    @State private var authToken: String = ""
    @State private var sslCert: String = ""
    @State private var sslKey: String = ""
    @State private var disableUiServing: Bool = false
    @State private var packageOverride: String = ""

    @State private var showingDiscardAlert = false
    @State private var showingApplyConfirm = false

    private var hasChanges: Bool {
        let frontend = scope.bridgeInfo?.config?.frontend
        return enabled != (frontend?.enabled ?? true)
            || port != (frontend?.port ?? 8080)
            || host != (frontend?.host ?? "")
            || url != (frontend?.url ?? "")
            || baseUrl != (frontend?.baseUrl ?? "")
            || authToken != ""
            || sslCert != (frontend?.sslCert ?? "")
            || sslKey != (frontend?.sslKey ?? "")
            || disableUiServing != (frontend?.disableUiServing ?? false)
            || packageOverride != (frontend?.package ?? "")
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $enabled)
                InlineIntField("Port", value: $port, range: 1...65535)
                SettingsTextField("Host", text: $host, placeholder: "0.0.0.0")
            } header: {
                Text("Frontend Server")
            } footer: {
                Text("Disabling the frontend turns off Zigbee2MQTT's own web UI. Shellbee connects over MQTT/WebSocket directly and is unaffected, but you'll lose the browser-based interface.")
            }

            Section {
                SettingsTextField("External URL", text: $url, placeholder: "e.g. https://z2m.example.com")
                SettingsTextField("Base URL Path", text: $baseUrl, placeholder: "/")
            } header: {
                Text("URLs")
            } footer: {
                Text("External URL overrides the address advertised to browsers, useful behind a reverse proxy. Base URL Path serves the frontend from a subpath instead of the root.")
            }

            Section {
                LabeledContent("Auth Token") {
                    SecureField("Optional", text: $authToken)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Authentication")
            } footer: {
                Text("When set, the web frontend requires this token to connect. Leave empty for no authentication.")
            }

            Section {
                SettingsTextField("SSL Certificate", text: $sslCert, placeholder: "Absolute path")
                SettingsTextField("SSL Key", text: $sslKey, placeholder: "Absolute path")
            } header: {
                Text("SSL / TLS")
            }

            Section {
                Toggle("Disable UI File Serving", isOn: $disableUiServing)
                SettingsTextField("Package Override", text: $packageOverride, placeholder: "Optional")
            } header: {
                Text("Advanced")
            } footer: {
                Text("Disable UI File Serving keeps the API reachable while turning off the static web UI. Package Override points the frontend at an alternate npm package.")
            }
        }
        .navigationTitle("Frontend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingDiscardAlert = true }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") { showingApplyConfirm = true }
                    .disabled(!hasChanges)
            }
        }
        .discardChangesAlert(hasChanges: hasChanges, isPresented: $showingDiscardAlert) { loadFromStore(); dismiss() }
        .alert("Apply Frontend Settings?", isPresented: $showingApplyConfirm) {
            Button("Apply", role: .destructive) { applyChanges() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Changing frontend settings requires a bridge restart and may change how you reach the Zigbee2MQTT web UI.")
        }
        .reloadOnBridgeInfo(info: scope.bridgeInfo, hasChanges: hasChanges, load: loadFromStore)
    }

    private func loadFromStore() {
        let frontend = scope.bridgeInfo?.config?.frontend
        enabled = frontend?.enabled ?? true
        port = frontend?.port ?? 8080
        host = frontend?.host ?? ""
        url = frontend?.url ?? ""
        baseUrl = frontend?.baseUrl ?? ""
        authToken = ""
        sslCert = frontend?.sslCert ?? ""
        sslKey = frontend?.sslKey ?? ""
        disableUiServing = frontend?.disableUiServing ?? false
        packageOverride = frontend?.package ?? ""
    }

    private func applyChanges() {
        var frontend: [String: JSONValue] = [
            "enabled": .bool(enabled),
            "port": .int(port),
            "disable_ui_serving": .bool(disableUiServing)
        ]
        if !host.isEmpty { frontend["host"] = .string(host) }
        if !url.isEmpty { frontend["url"] = .string(url) }
        if !baseUrl.isEmpty { frontend["base_url"] = .string(baseUrl) }
        if !authToken.isEmpty { frontend["auth_token"] = .string(authToken) }
        if !sslCert.isEmpty { frontend["ssl_cert"] = .string(sslCert) }
        if !sslKey.isEmpty { frontend["ssl_key"] = .string(sslKey) }
        if !packageOverride.isEmpty { frontend["package"] = .string(packageOverride) }
        scope.sendOptions(["frontend": .object(frontend)])
        authToken = ""
    }
}

#Preview {
    NavigationStack {
        FrontendSettingsView(bridgeID: UUID()).environment(AppEnvironment())
    }
    .configuredTopScrollEdgeEffect()
}
