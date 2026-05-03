import SwiftUI

struct LogOutputView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let bridgeID: UUID
    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    @State private var logRotation: Bool = true
    @State private var logDirectoriesToKeep: Int = 10
    @State private var logOutputConsole: Bool = true
    @State private var logOutputFile: Bool = true
    @State private var logOutputSyslog: Bool = false
    @State private var logDirectory: String = ""
    @State private var logFile: String = "log.log"
    @State private var logConsoleJson: Bool = false
    @State private var logSymlinkCurrent: Bool = false
    @State private var logDebugNamespaceIgnore: String = ""

    @State private var showingDiscardAlert = false

    private var hasChanges: Bool {
        let adv = scope.bridgeInfo?.config?.advanced
        let stored = Set(adv?.logOutput ?? ["console", "file"])
        return currentLogOutput != stored
            || logRotation != (adv?.logRotation ?? true)
            || logDirectoriesToKeep != (adv?.logDirectoriesToKeep ?? 10)
            || logDirectory != (adv?.logDirectory ?? "")
            || logFile != (adv?.logFile ?? "log.log")
            || logConsoleJson != (adv?.logConsoleJson ?? false)
            || logSymlinkCurrent != (adv?.logSymlinkCurrent ?? false)
            || logDebugNamespaceIgnore != (adv?.logDebugNamespaceIgnore ?? "")
    }

    private var currentLogOutput: Set<String> {
        var set = Set<String>()
        if logOutputConsole { set.insert("console") }
        if logOutputFile { set.insert("file") }
        if logOutputSyslog { set.insert("syslog") }
        return set
    }

    var body: some View {
        Form {
            Section {
                Toggle("Console", isOn: $logOutputConsole)
                Toggle("File", isOn: $logOutputFile)
                Toggle("Syslog", isOn: $logOutputSyslog)
            } header: {
                Text("Log Outputs")
            } footer: {
                Text("Choose where log messages are written. Console logs to stdout, File saves logs to disk, and Syslog sends them to the system logging daemon.")
            }

            if logOutputFile {
                Section {
                    SettingsTextField("Directory", text: $logDirectory, placeholder: "data/log (default)")
                    SettingsTextField("Filename", text: $logFile, placeholder: "log.log")
                    Toggle("Create 'current' Shortcut", isOn: $logSymlinkCurrent)
                } header: {
                    Text("File Settings")
                } footer: {
                    Text("Creates a 'current' symlink in the log directory pointing to the most recent log folder.")
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

            Section {
                Toggle("Format Console Logs as JSON", isOn: $logConsoleJson)
            } footer: {
                Text("When enabled, console output is formatted as JSON instead of plain text. Useful for log aggregation pipelines.")
            }

            Section {
                LabeledContent("Suppression Pattern") {
                    TextField("e.g. \\bz-stack\\b", text: $logDebugNamespaceIgnore)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.caption.monospaced())
                }
            } header: {
                Text("Debug Filter")
            } footer: {
                Text("Regular expression to suppress debug messages from matching namespaces. Leave empty to log all namespaces.")
            }
        }
        .navigationTitle("Log Output")
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
        .reloadOnBridgeInfo(info: scope.bridgeInfo, hasChanges: hasChanges, load: loadFromStore)
    }

    private func loadFromStore() {
        let adv = scope.bridgeInfo?.config?.advanced
        let outputs = Set(adv?.logOutput ?? ["console", "file"])
        logOutputConsole = outputs.contains("console")
        logOutputFile = outputs.contains("file")
        logOutputSyslog = outputs.contains("syslog")
        logRotation = adv?.logRotation ?? true
        logDirectoriesToKeep = adv?.logDirectoriesToKeep ?? 10
        logDirectory = adv?.logDirectory ?? ""
        logFile = adv?.logFile ?? "log.log"
        logConsoleJson = adv?.logConsoleJson ?? false
        logSymlinkCurrent = adv?.logSymlinkCurrent ?? false
        logDebugNamespaceIgnore = adv?.logDebugNamespaceIgnore ?? ""
    }

    private func applyChanges() {
        var advanced: [String: JSONValue] = [
            "log_output": .array(currentLogOutput.sorted().map { .string($0) }),
            "log_rotation": .bool(logRotation),
            "log_directories_to_keep": .int(logDirectoriesToKeep),
            "log_file": .string(logFile),
            "log_console_json": .bool(logConsoleJson),
            "log_symlink_current": .bool(logSymlinkCurrent)
        ]
        if !logDirectory.isEmpty { advanced["log_directory"] = .string(logDirectory) }
        if !logDebugNamespaceIgnore.isEmpty { advanced["log_debug_namespace_ignore"] = .string(logDebugNamespaceIgnore) }
        scope.sendOptions(["advanced": .object(advanced)])
    }
}

#Preview {
    NavigationStack {
        LogOutputView(bridgeID: UUID()).environment(AppEnvironment())
    }
}
