import Foundation

extension AppStore {
    func clearLogs() {
        logEntries = []
        rawLogEntries = []
        logNamespaces = []
        rawLogNamespaces = []
    }

    func insertLogEntry(_ entry: LogEntry) {
        if let namespace = entry.namespace, !logNamespaces.contains(namespace) {
            logNamespaces.insert(namespace)
        }
        logEntries.insert(entry, at: 0)
        if logEntries.count > Self.logLimit {
            logEntries = Array(logEntries.prefix(Self.logLimit))
        }
    }

    func insertRawLogEntry(_ entry: LogEntry) {
        if let namespace = entry.namespace, !rawLogNamespaces.contains(namespace) {
            rawLogNamespaces.insert(namespace)
        }
        rawLogEntries.insert(entry, at: 0)
        if rawLogEntries.count > Self.logLimit {
            rawLogEntries = Array(rawLogEntries.prefix(Self.logLimit))
        }
    }
}
