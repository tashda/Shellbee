import SwiftUI

struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation
    @State private var query = ""
    @State private var pendingConfirmation: CommandPaletteItem?
    @State private var isSearchPresented = true

    private var model: CommandPaletteModel {
        CommandPaletteModel(
            bridges: environment.registry.orderedSessions.map { session in
                CommandPaletteBridge(
                    id: session.bridgeID,
                    name: session.displayName,
                    isConnected: session.isConnected,
                    isPermitJoinOpen: session.store.bridgeInfo?.permitJoin == true
                )
            },
            devices: environment.allDevices.filter { $0.device.type != .coordinator },
            groups: environment.allGroups
        )
    }

    private var results: [CommandPaletteItem] {
        model.results(matching: query)
    }

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(CommandPaletteCategory.allCases, id: \.self) { category in
                        let commands = results.filter { $0.category == category }
                        if !commands.isEmpty {
                            Section(category.rawValue) {
                                ForEach(commands) { command in
                                    commandRow(command)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Commands")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search commands"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { isSearchPresented = true }
        .alert(
            pendingConfirmation?.title ?? "Confirm Command",
            isPresented: confirmationBinding,
            presenting: pendingConfirmation
        ) { command in
            Button("Run") { execute(command) }
            Button("Cancel", role: .cancel) {}
        } message: { command in
            Text(confirmationMessage(for: command))
        }
    }

    private func commandRow(_ command: CommandPaletteItem) -> some View {
        Button {
            if command.requiresConfirmation {
                pendingConfirmation = command
            } else {
                execute(command)
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: command.systemImage)
                    .foregroundStyle(command.isEnabled ? Color.accentColor : Color.secondary)
                    .frame(width: DesignTokens.Size.settingsIconFrame)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(command.title)
                        .foregroundStyle(command.isEnabled ? Color.primary : Color.secondary)
                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let reason = command.disabledReason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .disabled(!command.isEnabled)
        .accessibilityLabel(command.accessibilityLabel)
        .accessibilityHint(command.requiresConfirmation ? "Requires confirmation" : "")
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingConfirmation != nil },
            set: { if !$0 { pendingConfirmation = nil } }
        )
    }

    private func confirmationMessage(for command: CommandPaletteItem) -> String {
        switch command.action {
        case .checkOTA:
            "This contacts the device over the Zigbee network and may take several seconds."
        case .setPermitJoin(_, true):
            "This opens the selected bridge for pairing for about four minutes."
        case .refreshNetworkMap:
            "Generating a Network Map can keep a busy coordinator occupied for 30–60 seconds."
        default:
            "Run this command?"
        }
    }

    private func execute(_ command: CommandPaletteItem) {
        guard command.isEnabled else { return }
        pendingConfirmation = nil

        switch command.action {
        case .navigate(let section):
            sceneNavigation.selectedTab = section
        case .openDevice(let route):
            sceneNavigation.pendingDeviceNavigation = route
            sceneNavigation.selectedTab = .devices
        case .openGroup(let route):
            sceneNavigation.pendingGroupNavigation = route
            sceneNavigation.selectedTab = .groups
        case .identify(let bridgeID, let friendlyName):
            environment.scope(for: bridgeID).identifyDevice(friendlyName)
        case .checkOTA(let bridgeID, let friendlyName):
            environment.scope(for: bridgeID).checkOTA(for: friendlyName)
        case .setPermitJoin(let bridgeID, let enabled):
            environment.scope(for: bridgeID).setPermitJoin(enabled: enabled)
        case .refreshBridge(let bridgeID):
            Task { await environment.refreshBridgeData(bridgeID: bridgeID) }
        case .openDiagnostics(let bridgeID):
            sceneNavigation.pendingSettingsNavigation = BridgeSettingsRoute(bridgeID: bridgeID)
            sceneNavigation.selectedTab = .settings
        case .openNetworkMap(let bridgeID):
            sceneNavigation.pendingNetworkMapBridgeID = bridgeID
            sceneNavigation.selectedTab = .networkMap
        case .refreshNetworkMap(let bridgeID):
            sceneNavigation.pendingNetworkMapBridgeID = bridgeID
            sceneNavigation.pendingNetworkMapRefreshBridgeID = bridgeID
            sceneNavigation.selectedTab = .networkMap
        }

        dismiss()
    }
}
