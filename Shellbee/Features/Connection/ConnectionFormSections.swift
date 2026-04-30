import SwiftUI

struct ConnectionHistorySection: View {
    @Bindable var viewModel: ConnectionViewModel

    var body: some View {
        if !viewModel.history.isEmpty {
            Section("Saved Connections") {
                ForEach(viewModel.history, id: \.self) { config in
                    Button {
                        viewModel.connect(to: config)
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text(config.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(config.displayURL)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if viewModel.matchesCurrentConfig(config) && viewModel.isConnecting {
                                ProgressView()
                                    .controlSize(.small)
                            } else if viewModel.matchesCurrentConfig(config) && viewModel.connectionState.isConnected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteConnection(config)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            viewModel.presentEditor(for: config)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            viewModel.presentEditor(for: config)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            viewModel.deleteConnection(config)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

struct ConnectionDiscoverySection: View {
    @Bindable var viewModel: ConnectionViewModel

    var body: some View {
        Section("Nearby Servers") {
            if viewModel.isScanning {
                LabeledContent("Scanning") {
                    ProgressView()
                }
            } else if viewModel.discoveredHosts.isEmpty {
                Button {
                    viewModel.startDiscovery()
                } label: {
                    Label("Scan for Zigbee2MQTT", systemImage: "magnifyingglass")
                        .foregroundStyle(.primary)
                }
            } else {
                ForEach(viewModel.discoveredHosts, id: \.self) { host in
                    Button {
                        viewModel.presentNewServer(prefilledHost: host)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text(host)
                                    .foregroundStyle(.primary)
                                Text("Discovered on your local network")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    viewModel.startDiscovery()
                } label: {
                    Text("Scan Again")
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

struct ConnectionServerSection: View {
    @Binding var draft: ConnectionEditorDraft

    var body: some View {
        Section {
            SettingsTextField("Name", text: $draft.name, placeholder: "Optional — e.g. Home")

            Picker("Protocol", selection: $draft.useTLS) {
                Text("HTTP").tag(false)
                Text("HTTPS").tag(true)
            }
            .pickerStyle(.automatic)
            .onChange(of: draft.useTLS) { oldValue, newValue in
                guard oldValue != newValue else { return }
                if newValue && draft.port == "8080" {
                    draft.port = "443"
                } else if !newValue && draft.port == "443" {
                    draft.port = "8080"
                }
            }

            SettingsTextField("Host", text: $draft.host, placeholder: "zigbee2mqtt.local")

            SettingsTextField("Port", text: $draft.port, placeholder: draft.useTLS ? "443" : "8080")
                .keyboardType(.numberPad)

            SettingsTextField("Base Path", text: $draft.basePath, placeholder: "/")

            LabeledContent("Token") {
                SecureField("Optional", text: $draft.authToken)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if draft.useTLS {
                Toggle("Allow Self-Signed Certificates", isOn: $draft.allowInvalidCertificates)
            }
        } header: {
            Text("Server")
        } footer: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Shellbee connects to Zigbee2MQTT over WebSocket. Leave Base Path as “/” unless your server is behind a reverse proxy on a subpath.")
                if draft.useTLS && draft.allowInvalidCertificates {
                    Text("Certificate validation is disabled for this server. The connection is encrypted, but anyone on the network path could impersonate the server. Only use on networks you trust.")
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
