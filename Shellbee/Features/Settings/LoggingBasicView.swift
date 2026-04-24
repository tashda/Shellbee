import SwiftUI

struct LoggingBasicView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    let highlight: SettingsHighlight?

    init(highlight: SettingsHighlight? = nil) {
        self.highlight = highlight
    }

    @State private var logLevel: BridgeSettings.LogLevel = .info
    @State private var logRotation: Bool = true
    @State private var logDirectoriesToKeep: Int = 10

    @State private var showingDiscardAlert = false
    @State private var logLevelHighlighted = false

    private var hasChanges: Bool {
        guard let info = environment.store.bridgeInfo else { return false }
        let advanced = info.config?.advanced
        return logLevel.rawValue != info.logLevel
            || logRotation != (advanced?.logRotation ?? true)
            || logDirectoriesToKeep != (advanced?.logDirectoriesToKeep ?? 10)
    }

    var body: some View {
        Form {
            Section {
                Picker("Log Level", selection: $logLevel) {
                    ForEach(BridgeSettings.LogLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .listRowBackground(
                    logLevelHighlighted
                        ? Color.accentColor.opacity(0.25)
                        : Color(.secondarySystemGroupedBackground)
                )
            } footer: {
                Text("Controls how verbose the bridge logs are.")
            }

            Section {
                Toggle("Log Rotation", isOn: $logRotation)
                InlineIntField("Directories to Keep", value: $logDirectoriesToKeep, range: 5...1000)
            } header: {
                Text("Log Files")
            } footer: {
                Text("Log rotation deletes old log directories automatically. Adjust how many to keep on disk.")
            }
        }
        .navigationTitle("Basic")
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
        .reloadOnBridgeInfo(info: environment.store.bridgeInfo, hasChanges: hasChanges, load: loadFromStore)
        .task {
            guard highlight == .logLevel else { return }
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeInOut(duration: 0.25)) { logLevelHighlighted = true }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 0.6)) { logLevelHighlighted = false }
        }
    }

    private func loadFromStore() {
        guard let info = environment.store.bridgeInfo else { return }
        logLevel = BridgeSettings.LogLevel(rawValue: info.logLevel) ?? .info
        let advanced = info.config?.advanced
        logRotation = advanced?.logRotation ?? true
        logDirectoriesToKeep = advanced?.logDirectoriesToKeep ?? 10
    }

    private func applyChanges() {
        guard let info = environment.store.bridgeInfo else { return }
        let advanced = info.config?.advanced
        var changes: [String: JSONValue] = [:]

        if logLevel.rawValue != info.logLevel {
            changes["log_level"] = .string(logLevel.rawValue)
        }
        if logRotation != (advanced?.logRotation ?? true) {
            changes["log_rotation"] = .bool(logRotation)
        }
        if logDirectoriesToKeep != (advanced?.logDirectoriesToKeep ?? 10) {
            changes["log_directories_to_keep"] = .int(logDirectoriesToKeep)
        }

        guard !changes.isEmpty else { return }
        environment.sendBridgeOptions(["advanced": .object(changes)])
    }
}

#Preview {
    NavigationStack {
        LoggingBasicView().environment(AppEnvironment())
    }
}
