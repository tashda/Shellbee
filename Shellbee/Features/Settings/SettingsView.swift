import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled: Bool = false
    @State private var showingRestartAlert = false
    @State private var showingDisconnectConfirmation = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            Form {
                if environment.store.bridgeInfo?.restartRequired == true {
                    restartRequiredNotice
                }

                connectionSection
                bridgeConfigSection
                loggingSection
                integrationsSection
                networkSection
                toolsSection
                applicationSection

                if developerModeEnabled {
                    developerSection
                }

                if environment.connectionState.isConnected || environment.hasBeenConnected {
                    dangerSection
                }
            }
            .navigationTitle("Settings")
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
            .sheet(isPresented: $showOnboarding) {
                OnboardingView()
                    .environment(environment)
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
            Picker(selection: logLevelBinding) {
                ForEach(BridgeSettings.LogLevel.allCases, id: \.self) { level in
                    Text(level.label).tag(level)
                }
            } label: {
                settingsLabel(title: "Logging Level", systemImage: "slider.horizontal.below.square.filled.and.square", color: .gray)
            }
            NavigationLink { LogsView() } label: {
                settingsLabel(title: "Logs", systemImage: "list.bullet.rectangle.portrait", color: .indigo)
            }
            NavigationLink { LogOutputView() } label: {
                settingsLabel(title: "Log Output", systemImage: "doc.text.magnifyingglass", color: Color(.systemGray2))
            }
        } header: {
            Text("Logging")
        }
    }

    private var logLevelBinding: Binding<BridgeSettings.LogLevel> {
        Binding(
            get: {
                BridgeSettings.LogLevel(rawValue: environment.store.bridgeInfo?.logLevel ?? "info") ?? .info
            },
            set: { newValue in
                guard newValue.rawValue != environment.store.bridgeInfo?.logLevel else { return }
                environment.sendBridgeOptions(["advanced": .object(["log_level": .string(newValue.rawValue)])])
            }
        )
    }

    private var toolsSection: some View {
        Section {
            NavigationLink { DocBrowserView() } label: {
                settingsLabel(title: "Device Library", systemImage: "books.vertical.fill", color: .orange)
            }
            NavigationLink { TouchlinkView() } label: {
                settingsLabel(title: "Touchlink", systemImage: "dot.radiowaves.left.and.right", color: .teal)
            }
            NavigationLink { BackupView() } label: {
                settingsLabel(title: "Backup", systemImage: "arrow.down.doc.fill", color: .indigo)
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
            NavigationLink { AppLiveActivitiesView() } label: {
                settingsLabel(title: "Live Activities", systemImage: "rectangle.inset.filled.and.person.filled", color: .pink)
            }
            NavigationLink { AppNotificationSettingsView() } label: {
                settingsLabel(title: "Notifications", systemImage: "bell.badge.fill", color: .red)
            }
            NavigationLink { AppPerformanceView() } label: {
                settingsLabel(title: "Bulk OTA", systemImage: "arrow.down.circle.dotted", color: .blue)
            }
            Button {
                showOnboarding = true
            } label: {
                settingsLabel(title: "Show Welcome Wizard", systemImage: "sparkles", color: .yellow)
            }
            NavigationLink { AboutView() } label: {
                settingsLabel(title: "About", systemImage: "info.circle.fill", color: Color(.systemGray2))
            }
        } header: {
            Text("Application")
        }
    }

    private var developerSection: some View {
        Section {
            NavigationLink { DeveloperSettingsView() } label: {
                settingsLabel(title: "Developer", systemImage: "hammer.fill", color: .purple)
            }
        } header: {
            Text("Developer")
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

#Preview {
    SettingsView().environment(AppEnvironment())
}
