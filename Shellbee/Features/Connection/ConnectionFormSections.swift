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
                                Text(config.host)
                                    .font(.headline)
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
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.xs)
                    }
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
                                .foregroundStyle(.tint)
                        }
                    }
                }

                Button("Scan Again") {
                    viewModel.startDiscovery()
                }
            }
        }
    }
}

struct ConnectionServerSection: View {
    @Binding var draft: ConnectionEditorDraft

    var body: some View {
        Section {
            Picker("Protocol", selection: $draft.useTLS) {
                Text("HTTP").tag(false)
                Text("HTTPS").tag(true)
            }
            .pickerStyle(.automatic)

            SettingsTextField("Host", text: $draft.host, placeholder: "192.168.1.110")

            SettingsTextField("Port", text: $draft.port, placeholder: "8080")
                .keyboardType(.numberPad)

            SettingsTextField("Base Path", text: $draft.basePath, placeholder: "/")

            LabeledContent("Token") {
                SecureField("Optional", text: $draft.authToken)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("Server")
        } footer: {
            Text("Shellbee connects to Zigbee2MQTT over WebSocket. Leave Base Path as “/” unless your server is behind a reverse proxy on a subpath.")
        }
    }
}
