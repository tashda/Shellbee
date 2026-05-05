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
    /// Default false. LQI drift is the dominant event by volume but the
    /// least actionable — it crowds out interviews, real state changes,
    /// availability transitions. Hiding it by default lets the meaningful
    /// rows breathe; the toggle in the filter menu lets diagnostic users
    /// opt back in.
    var showLinkQualityChanges = false

    var hasActiveFilter: Bool {
        selectedLevel != nil || selectedCategory != nil || selectedNamespace != nil
            || !selectedDevices.isEmpty || entryIDFilter != nil || bridgeFilter != nil
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

        // Hide LQI-only state changes by default — the user can opt back
        // in via the Show signal changes toggle in the filter menu.
        if !showLinkQualityChanges {
            entries = entries.filter { !LogRowIconography.isLinkQualityOnly($0) }
        }

        // Coalesce consecutive same-device same-kind entries. The store is
        // newest-first; we walk it and produce synthesized entries with a
        // count when a run of identical rows is found. Bursts of LQI
        // drift, repeated availability flaps, etc. collapse to one row.
        return coalesce(entries)
    }

    /// Walk a newest-first entry list and collapse adjacent duplicates.
    /// "Duplicate" = same category + same device + same coalesce key
    /// (e.g., LQI-only state changes share a key regardless of value).
    private func coalesce(_ entries: [LogEntry]) -> [LogEntry] {
        var result: [LogEntry] = []
        result.reserveCapacity(entries.count)
        for entry in entries {
            if let last = result.last, Self.canCoalesce(last, entry) {
                var merged = last
                merged.coalescedCount += 1
                result[result.count - 1] = merged
            } else {
                result.append(entry)
            }
        }
        return result
    }

    private static func canCoalesce(_ a: LogEntry, _ b: LogEntry) -> Bool {
        guard a.category == b.category else { return false }
        guard a.deviceName == b.deviceName else { return false }
        // Only collapse rows the user is unlikely to want individually:
        // LQI-only drift, availability flaps. Real state changes
        // (brightness, occupancy, temperature) carry distinct values per
        // entry — coalescing them would erase information.
        if LogRowIconography.isLinkQualityOnly(a),
           LogRowIconography.isLinkQualityOnly(b) {
            return true
        }
        if a.category == .availability, b.category == .availability {
            return true
        }
        return false
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
