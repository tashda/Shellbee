import Foundation

@Observable
final class BridgeLogViewModel {
    var searchText = ""
    var selectedLevel: LogLevel? = nil

    var hasActiveFilter: Bool { selectedLevel != nil }

    func filteredEntries(store: AppStore) -> [LogEntry] {
        var entries = store.rawLogEntries
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            entries = entries.filter {
                $0.message.lowercased().contains(q) || $0.namespace?.lowercased().contains(q) == true
            }
        }
        if let level = selectedLevel {
            entries = entries.filter { $0.level == level }
        }
        return entries
    }
}
