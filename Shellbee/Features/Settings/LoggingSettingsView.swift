import SwiftUI

struct LoggingSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

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
        let adv = environment.store.bridgeInfo?.config?.advanced
        let stored = Set(adv?.logOutput ?? ["console", "file"])
        let current = currentLogOutput
        return current != stored
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
        .navigationBarBackButtonHidden(hasChanges)
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
        .alert("Discard Unsaved Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard Changes", role: .destructive) { loadFromStore(); dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: { Text("Any modifications you have made will be lost.") }
        .task { loadFromStore() }
    }

    private func loadFromStore() {
        let adv = environment.store.bridgeInfo?.config?.advanced
        let outputs = Set(adv?.logOutput ?? ["console", "file"])
        logOutputConsole = outputs.contains("console")
        logOutputFile = outputs.contains("file")
        logOutputSyslog = outputs.contains("syslog")
        logDirectory = adv?.logDirectory ?? ""
        logFile = adv?.logFile ?? "log.log"
        logConsoleJson = adv?.logConsoleJson ?? false
        logSymlinkCurrent = adv?.logSymlinkCurrent ?? false
        logDebugNamespaceIgnore = adv?.logDebugNamespaceIgnore ?? ""
    }

    private func applyChanges() {
        var advanced: [String: JSONValue] = [
            "log_output": .array(currentLogOutput.sorted().map { .string($0) }),
            "log_file": .string(logFile),
            "log_console_json": .bool(logConsoleJson),
            "log_symlink_current": .bool(logSymlinkCurrent)
        ]
        if !logDirectory.isEmpty { advanced["log_directory"] = .string(logDirectory) }
        if !logDebugNamespaceIgnore.isEmpty { advanced["log_debug_namespace_ignore"] = .string(logDebugNamespaceIgnore) }
        environment.send(topic: Z2MTopics.Request.options, payload: .object(["advanced": .object(advanced)]))
    }
}

#Preview {
    NavigationStack {
        LoggingSettingsView().environment(AppEnvironment())
    }
}
