import SwiftUI

struct FrontendSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var enabled: Bool = true
    @State private var port: Int = 8080
    @State private var host: String = "0.0.0.0"
    @State private var url: String = ""
    @State private var baseUrl: String = "/"
    @State private var authToken: String = ""
    @State private var package: String = ""
    @State private var sslCert: String = ""
    @State private var sslKey: String = ""
    @State private var disableUiServing: Bool = false

    @State private var showingDiscardAlert = false

    private let packageOptions = [("", "Default"), ("zigbee2mqtt-frontend", "zigbee2mqtt-frontend"), ("zigbee2mqtt-windfront", "Windfront")]

    private var hasChanges: Bool {
        guard let frontend = environment.store.bridgeInfo?.config?.frontend else { return false }
        return enabled != (frontend.enabled ?? true)
            || port != (frontend.port ?? 8080)
            || host != (frontend.host ?? "0.0.0.0")
            || url != (frontend.url ?? "")
            || baseUrl != (frontend.baseUrl ?? "/")
            || disableUiServing != (frontend.disableUiServing ?? false)
            || package != (frontend.package ?? "")
            || !sslCert.isEmpty || !sslKey.isEmpty || !authToken.isEmpty
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable Web UI", isOn: $enabled)
                Toggle("Serve API Only", isOn: $disableUiServing)
            } footer: {
                Text("The built-in web interface lets you manage your Zigbee network from a browser. Serve API Only keeps the API running without delivering the interface files — useful when hosting the frontend separately.")
            }

            if enabled {
                Section {
                    LabeledContent("Port") {
                        TextField("8080", value: $port, format: .number.grouping(.never))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    SettingsTextField("Host", text: $host, placeholder: "0.0.0.0")
                    SettingsTextField("External URL", text: $url, placeholder: "Optional")
                    SettingsTextField("Base URL", text: $baseUrl, placeholder: "/")
                } header: { Text("Server") } footer: {
                    Text("Host 0.0.0.0 accepts connections from all interfaces. Set External URL if behind a reverse proxy. Base URL is the prefix path.")
                }

                Section {
                    LabeledContent("Package") {
                        Picker("Package", selection: $package) {
                            ForEach(packageOptions, id: \.0) { opt in
                                Text(opt.1).tag(opt.0)
                            }
                        }
                        .labelsHidden()
                    }
                } header: { Text("Interface Package") } footer: {
                    Text("Choose which frontend package to serve. Default uses the bundled package.")
                }

                Section {
                    LabeledContent("Auth Token") {
                        SecureField("Optional", text: $authToken)
                            .multilineTextAlignment(.trailing)
                    }
                } header: { Text("Authentication") } footer: {
                    Text("Set an auth token to require authentication. Leave empty to keep the current token unchanged.")
                }

                Section {
                    SettingsTextField("SSL Certificate Path", text: $sslCert, placeholder: "Optional — /path/to/cert.pem")
                    SettingsTextField("SSL Key Path", text: $sslKey, placeholder: "Optional — /path/to/key.pem")
                } header: { Text("SSL / TLS") } footer: {
                    Text("Provide paths to SSL certificate and key files to enable HTTPS on the frontend. Leave empty for HTTP.")
                }
            }
        }
        .navigationTitle("Web Interface")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingDiscardAlert = true }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") { applyChanges() }
                    .disabled(!hasChanges)
            }
        }
        .discardChangesAlert(hasChanges: hasChanges, isPresented: $showingDiscardAlert) { loadFromStore(); dismiss() }
        .task { loadFromStore() }
    }

    private func loadFromStore() {
        if let frontend = environment.store.bridgeInfo?.config?.frontend {
            enabled = frontend.enabled ?? true
            port = frontend.port ?? 8080
            host = frontend.host ?? "0.0.0.0"
            url = frontend.url ?? ""
            baseUrl = frontend.baseUrl ?? "/"
            disableUiServing = frontend.disableUiServing ?? false
            package = frontend.package ?? ""
        }
        authToken = ""; sslCert = ""; sslKey = ""
    }

    private func applyChanges() {
        var frontend: [String: JSONValue] = [
            "enabled": .bool(enabled),
            "port": .int(port),
            "host": .string(host),
            "base_url": .string(baseUrl),
            "disable_ui_serving": .bool(disableUiServing)
        ]
        if !url.isEmpty { frontend["url"] = .string(url) }
        if !package.isEmpty { frontend["package"] = .string(package) }
        if !authToken.isEmpty { frontend["auth_token"] = .string(authToken) }
        if !sslCert.isEmpty { frontend["ssl_cert"] = .string(sslCert) }
        if !sslKey.isEmpty { frontend["ssl_key"] = .string(sslKey) }
        environment.send(topic: Z2MTopics.Request.options, payload: .object(["frontend": .object(frontend)]))
        authToken = ""; sslCert = ""; sslKey = ""
    }
}

#Preview {
    NavigationStack {
        FrontendSettingsView().environment(AppEnvironment())
    }
}
