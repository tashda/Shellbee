import Foundation

@Observable
final class LogsViewModel {
    var searchText = ""
    var selectedLevel: LogLevel? = nil
    var selectedCategory: LogCategory? = nil
    var selectedNamespace: String? = nil
    var selectedDevices: Set<String> = []
    var entryIDFilter: Set<UUID>? = nil
    /// Multi-bridge: when set, the merged log list filters to this bridge.
    /// Ignored in single-bridge mode.
    var bridgeFilter: UUID? = nil

    var hasActiveFilter: Bool {
        selectedLevel != nil || selectedCategory != nil || selectedNamespace != nil || !selectedDevices.isEmpty || entryIDFilter != nil || bridgeFilter != nil
    }

    func filteredEntries(store: AppStore) -> [LogEntry] {
        var entries = store.logEntries

        if let ids = entryIDFilter {
            entries = entries.filter { ids.contains($0.id) }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            entries = entries.filter { entry in
                entry.message.lowercased().contains(q)
                    || entry.deviceName?.lowercased().contains(q) == true
            }
        }

        if let level = selectedLevel {
            entries = entries.filter { $0.level == level }
        }

        if let category = selectedCategory {
            entries = entries.filter { $0.category == category }
        }

        if let ns = selectedNamespace {
            entries = entries.filter { $0.namespace == ns }
        }

        if !selectedDevices.isEmpty {
            entries = entries.filter { entry in
                guard let name = entry.deviceName else { return false }
                return selectedDevices.contains(name)
            }
        }

        return entries
    }

    func availableNamespaces(store: AppStore) -> [String] {
        Set(store.logEntries.compactMap { $0.namespace }).sorted()
    }

    func availableDevices(store: AppStore) -> [String] {
        Set(store.logEntries.compactMap { $0.deviceName }).sorted()
    }

    func clearAllFilters() {
        selectedLevel = nil
        selectedCategory = nil
        selectedNamespace = nil
        selectedDevices = []
        entryIDFilter = nil
        bridgeFilter = nil
        searchText = ""
    }
}
