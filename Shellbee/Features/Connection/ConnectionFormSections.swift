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
            // Render any servers found so far first — discovery streams hits
            // as it goes, so a match should appear the moment the probe
            // resolves rather than at the end of the /24 sweep.
            ForEach(viewModel.discoveredEndpoints, id: \.self) { endpoint in
                Button {
                    viewModel.presentNewServer(prefilledHost: endpoint.host, prefilledPort: endpoint.port)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("\(endpoint.host):\(String(endpoint.port))")
                                .foregroundStyle(.primary)
                            Text(endpoint.subtitle)
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

            // Scanning indicator stays alongside results so the user knows
            // the sweep is still running even after the first match arrives.
            if viewModel.isScanning {
                LabeledContent("Scanning") {
                    ProgressView()
                }
            } else {
                Button {
                    viewModel.startDiscovery()
                } label: {
                    Label(
                        viewModel.discoveredEndpoints.isEmpty ? "Scan for Zigbee2MQTT" : "Scan Again",
                        systemImage: "magnifyingglass"
                    )
                    .foregroundStyle(.primary)
                }
            }
        }
    }
}

struct ConnectionServerSection: View {
    @Binding var draft: ConnectionEditorDraft
    var focusedField: FocusState<ConnectionEditorView.Field?>.Binding

    var body: some View {
        Section {
            LabeledContent("Name") {
                TextField("Optional — e.g. Home", text: $draft.name)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused(focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField.wrappedValue = .host }
            }

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

            LabeledContent("Host") {
                TextField("zigbee2mqtt.local", text: $draft.host)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused(focusedField, equals: .host)
                    .submitLabel(.next)
                    .onSubmit { focusedField.wrappedValue = .port }
            }

            LabeledContent("Port") {
                TextField(draft.useTLS ? "443" : "8080", text: $draft.port)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numberPad)
                    .focused(focusedField, equals: .port)
            }

            LabeledContent("Base Path") {
                TextField("/", text: $draft.basePath)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused(focusedField, equals: .basePath)
                    .submitLabel(.next)
                    .onSubmit { focusedField.wrappedValue = .authToken }
            }

            LabeledContent("Token") {
                SecureField("Optional", text: $draft.authToken)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused(focusedField, equals: .authToken)
                    .submitLabel(.done)
                    .onSubmit { focusedField.wrappedValue = nil }
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

        Section {
            Toggle("Auto-Connect on Launch", isOn: $draft.autoConnect)
        } footer: {
            Text("When on, Shellbee connects to this bridge automatically every time the app opens. Multiple bridges can be set to auto-connect.")
        }

        Section {
            BridgeColorPicker(selection: $draft.bridgeColor, usesAutoColor: $draft.usesAutoBridgeColor)
        } header: {
            Text("Color")
        } footer: {
            Text("Picks the bridge color used in Logs, Devices, Groups, and other multi-bridge views.")
        }
    }
}

/// Form-row bridge-color picker. Nil means auto color.
private struct BridgeColorPicker: View {
    @Binding var selection: Color?
    @Binding var usesAutoColor: Bool

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            ColorPicker("Bridge Color", selection: binding, supportsOpacity: false)
                .onChange(of: selection) { _, newValue in
                    if newValue != nil { usesAutoColor = false }
                }

            Button {
                usesAutoColor = true
                selection = DesignTokens.Bridge.suggestedAvailableColor()
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(usesAutoColor ? .primary : .secondary)
                    .frame(width: DesignTokens.Size.settingsIconFrame, height: DesignTokens.Size.settingsIconFrame)
                    .glassEffectIfAvailable(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Automatic color")
            .accessibilityValue(usesAutoColor ? "On" : "Off")
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var binding: Binding<Color> {
        Binding(
            get: { selection ?? DesignTokens.Bridge.suggestedAvailableColor() },
            set: {
                selection = $0
                usesAutoColor = false
            }
        )
    }
}
