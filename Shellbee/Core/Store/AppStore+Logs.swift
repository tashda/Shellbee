import Foundation

extension AppStore {
    func clearLogs() {
        logEntries = []
        rawLogEntries = []
    }

    func insertLogEntry(_ entry: LogEntry) {
        logEntries.insert(entry, at: 0)
        if logEntries.count > Self.logLimit {
            logEntries = Array(logEntries.prefix(Self.logLimit))
        }
    }

    func insertRawLogEntry(_ entry: LogEntry) {
        rawLogEntries.insert(entry, at: 0)
        if rawLogEntries.count > Self.logLimit {
            rawLogEntries = Array(rawLogEntries.prefix(Self.logLimit))
        }
    }
}
