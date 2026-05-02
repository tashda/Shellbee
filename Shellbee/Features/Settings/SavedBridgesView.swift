import SwiftUI

struct SavedBridgesView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ConnectionViewModel?
    @State private var renameTarget: ConnectionConfig?
    @State private var renameDraft: String = ""
    @State private var showRemoveConfirmation: ConnectionConfig?

    var body: some View {
        Form {
            if environment.history.connections.isEmpty {
                emptyStateSection
            } else {
                bridgesSection
            }
        }
        .navigationTitle("Saved Bridges")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentEditor()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Bridge")
            }
        }
        .sheet(item: editorBinding) { vm in
            NavigationStack {
                ConnectionEditorView(viewModel: vm, mode: .save)
            }
        }
        .alert("Rename Bridge", isPresented: renameAlertBinding, presenting: renameTarget) { config in
            TextField("Name", text: $renameDraft)
                .textInputAutocapitalization(.words)
            Button("Save") {
                let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                environment.history.rename(config, to: trimmed.isEmpty ? nil : trimmed)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Choose a friendly name. Leave blank to use the host.")
        }
        .alert("Remove Bridge?", isPresented: removeAlertBinding, presenting: showRemoveConfirmation) { config in
            Button("Remove", role: .destructive) {
                environment.history.remove(config)
            }
            Button("Cancel", role: .cancel) {}
        } message: { config in
            Text("\(config.displayName) will be removed from your saved bridges. Its auth token is deleted from the keychain.")
        }
    }

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
                Text("No saved bridges yet")
                    .font(.headline)
                Text("Add a bridge to switch between Zigbee2MQTT instances without re-entering the connection details each time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    presentEditor()
                } label: {
                    Label("Add Bridge", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, DesignTokens.Spacing.xs)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.lg)
        }
    }

    private var bridgesSection: some View {
        Section {
            ForEach(sortedBridges) { config in
                row(for: config)
            }
        } footer: {
            Text("Tap a bridge to connect. The default bridge auto-connects on launch.")
        }
    }

    private var sortedBridges: [ConnectionConfig] {
        let connections = environment.history.connections
        guard let defaultID = environment.history.defaultBridgeID else { return connections }
        var copy = connections
        if let idx = copy.firstIndex(where: { $0.id == defaultID }) {
            let entry = copy.remove(at: idx)
            copy.insert(entry, at: 0)
        }
        return copy
    }

    private func row(for config: ConnectionConfig) -> some View {
        let isActive = environment.connectionConfig?.id == config.id
        let isDefault = environment.history.defaultBridgeID == config.id

        return Button {
            connect(to: config)
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: isActive ? "wifi.circle.fill" : "wifi.circle")
                    .font(.title2)
                    .foregroundStyle(isActive ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text(config.displayName)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if isDefault {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .accessibilityLabel("Default")
                        }
                    }
                    Text(config.displayURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isActive {
                    Text("Active")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showRemoveConfirmation = config
            } label: {
                Label("Remove", systemImage: "trash")
            }
            Button {
                renameDraft = config.name ?? ""
                renameTarget = config
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                let current = environment.history.defaultBridgeID
                environment.history.setDefault(current == config.id ? nil : config)
            } label: {
                if isDefault {
                    Label("Unset Default", systemImage: "star.slash")
                } else {
                    Label("Set Default", systemImage: "star")
                }
            }
            .tint(.yellow)
        }
    }

    private func presentEditor() {
        let vm = ConnectionViewModel(environment: environment)
        vm.presentNewServer()
        viewModel = vm
    }

    private func connect(to config: ConnectionConfig) {
        guard environment.connectionConfig?.id != config.id else { return }
        environment.connect(config: config)
    }

    private var editorBinding: Binding<ConnectionViewModel?> {
        Binding(
            get: { viewModel?.isEditorPresented == true ? viewModel : nil },
            set: { if $0 == nil { viewModel = nil } }
        )
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    private var removeAlertBinding: Binding<Bool> {
        Binding(
            get: { showRemoveConfirmation != nil },
            set: { if !$0 { showRemoveConfirmation = nil } }
        )
    }
}

extension ConnectionViewModel: Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

#Preview {
    NavigationStack {
        SavedBridgesView()
            .environment(AppEnvironment())
    }
}
