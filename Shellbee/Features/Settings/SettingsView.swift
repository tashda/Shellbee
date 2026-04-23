import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showingRestartAlert = false
    @State private var showingDisconnectConfirmation = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                if environment.store.bridgeInfo?.restartRequired == true {
                    restartRequiredNotice
                }

                connectionSection
                toolsSection
                bridgeConfigSection
                loggingSection
                integrationsSection
                networkSection
                applicationSection

                if environment.connectionState.isConnected || environment.hasBeenConnected {
                    dangerSection
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .logs(let entryIDs):
                    LogsView(initialEntryFilter: entryIDs.isEmpty ? nil : Set(entryIDs))
                }
            }
            .onChange(of: environment.pendingLogEntryIDs) { _, newValue in
                guard let ids = newValue else { return }
                environment.pendingLogEntryIDs = nil
                pushLogsResettingPath(ids)
            }
            .onAppear {
                if let ids = environment.pendingLogEntryIDs {
                    environment.pendingLogEntryIDs = nil
                    pushLogsResettingPath(ids)
                }
            }
            .alert("Restart Zigbee2MQTT?", isPresented: $showingRestartAlert) {
                Button("Restart", role: .destructive) { environment.restartBridge() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Zigbee2MQTT will restart. The app will reconnect automatically.")
            }
            .alert("Disconnect from Server?", isPresented: $showingDisconnectConfirmation) {
                Button("Disconnect", role: .destructive) {
                    Task { await environment.disconnect() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The app returns to the setup screen. Your server address is remembered.")
            }
        }
    }

    private var connectionSection: some View {
        Section {
            NavigationLink { ServerDetailView() } label: {
                settingsLabel(title: "Server", systemImage: "wifi", color: serverIconColor)
                    .badge(environment.connectionConfig?.displayName ?? "Not configured")
            }
        } header: {
            Text("Connection")
        }
    }

    private var serverIconColor: Color {
        switch environment.connectionState {
        case .connected: .green
        case .connecting, .reconnecting: .orange
        default: Color(.systemGray3)
        }
    }

    private var bridgeConfigSection: some View {
        Section {
            NavigationLink { MainSettingsView() } label: {
                settingsLabel(title: "General", systemImage: "slider.horizontal.3", color: .purple)
            }
            NavigationLink { MQTTSettingsView() } label: {
                settingsLabel(title: "MQTT", systemImage: "point.3.connected.trianglepath.dotted", color: .blue)
            }
            NavigationLink { SerialSettingsView() } label: {
                settingsLabel(title: "Adapter", systemImage: "cable.connector", color: .brown)
            }
        } header: {
            Text("Bridge Configuration")
        }
    }

    private var loggingSection: some View {
        Section {
            NavigationLink { LoggingSettingsView() } label: {
                settingsLabel(title: "Logging Details", systemImage: "doc.text.magnifyingglass", color: .gray)
            }
        } header: {
            Text("Logging")
        }
    }

    private var toolsSection: some View {
        Section {
            NavigationLink { DocBrowserView() } label: {
                settingsLabel(title: "Device Library", systemImage: "books.vertical.fill", color: .orange)
            }
            NavigationLink { LogsView() } label: {
                settingsLabel(title: "Logs", systemImage: "list.bullet.rectangle.portrait", color: .indigo)
            }
            NavigationLink { TouchlinkView() } label: {
                settingsLabel(title: "Touchlink", systemImage: "dot.radiowaves.left.and.right", color: .teal)
            }
        } header: {
            Text("Tools")
        }
    }

    private var integrationsSection: some View {
        Section {
            NavigationLink { HomeAssistantSettingsView() } label: {
                settingsLabel(title: "Home Assistant", systemImage: "house.fill", color: .orange)
            }
            NavigationLink { AvailabilitySettingsView() } label: {
                settingsLabel(title: "Availability", systemImage: "antenna.radiowaves.left.and.right", color: .green)
            }
            NavigationLink { OTASettingsView() } label: {
                settingsLabel(title: "OTA Updates", systemImage: "arrow.down.circle.fill", color: .indigo)
            }
            NavigationLink { HealthSettingsView() } label: {
                settingsLabel(title: "Health Checks", systemImage: "waveform.path.ecg", color: .pink)
            }
        } header: {
            Text("Integrations & Features")
        }
    }

    private var networkSection: some View {
        Section {
            NavigationLink { NetworkSettingsView() } label: {
                settingsLabel(title: "Network & Hardware", systemImage: "network", color: .red)
            }
            NavigationLink { NetworkAccessSettingsView() } label: {
                settingsLabel(title: "Device Filtering", systemImage: "lock.shield.fill", color: .cyan)
            }
        } header: {
            Text("Network")
        }
    }

    private var applicationSection: some View {
        Section {
            NavigationLink { AppGeneralView() } label: {
                settingsLabel(title: "General", systemImage: "gearshape.fill", color: .gray)
            }
            NavigationLink { AppPerformanceView() } label: {
                settingsLabel(title: "Performance", systemImage: "speedometer", color: .blue)
            }
            NavigationLink { AboutView() } label: {
                settingsLabel(title: "About", systemImage: "info.circle.fill", color: Color(.systemGray2))
            }
        } header: {
            Text("Application")
        }
    }

    private var dangerSection: some View {
        Section {
            if environment.connectionState.isConnected {
                Button("Restart Zigbee2MQTT", role: .destructive) {
                    showingRestartAlert = true
                }
            }
            Button("Disconnect", role: .destructive) {
                showingDisconnectConfirmation = true
            }
        }
    }

    // Pop to root, then push on the next runloop. Replacing and appending in
    // the same pass produced a blank push that immediately popped back to
    // Settings when the stack already contained a NavigationLink push.
    private func pushLogsResettingPath(_ ids: [UUID]) {
        if !path.isEmpty {
            path.removeLast(path.count)
        }
        Task { @MainActor in
            path.append(SettingsDestination.logs(entryIDs: ids))
        }
    }

    private func settingsLabel(title: String, systemImage: String, color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: DesignTokens.Size.settingsIconFrame, height: DesignTokens.Size.settingsIconFrame)
                .background(color, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous))
        }
    }

    private var restartRequiredNotice: some View {
        Section {
            Button { showingRestartAlert = true } label: {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: DesignTokens.Size.restartIconFrame, height: DesignTokens.Size.restartIconFrame)
                        .background(.red, in: Circle())
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Restart Required")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("New configuration is ready to be applied.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            .buttonStyle(.plain)
        }
    }
}

enum SettingsDestination: Hashable {
    case logs(entryIDs: [UUID])
}

#Preview {
    SettingsView().environment(AppEnvironment())
}
