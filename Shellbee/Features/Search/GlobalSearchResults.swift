import Foundation

/// A connected bridge as global search sees it.
struct GlobalSearchBridge: Hashable, Identifiable {
    let id: UUID
    let name: String
    let version: String?
    let isConnected: Bool
}

/// Matches of a query against every searchable source, ranked per category.
struct GlobalSearchResults {
    var devices: [BridgeBoundDevice] = []
    var groups: [BridgeBoundGroup] = []
    var bridges: [GlobalSearchBridge] = []
    var activity: [BridgeBoundLogEntry] = []
    var logs: [BridgeBoundLogEntry] = []
    var docs: [DocBrowserEntry] = []

    /// Log volumes can be large; keep result lists scannable.
    static let logLimit = 200

    init() {}

    init(
        query: String,
        devices: [BridgeBoundDevice],
        groups: [BridgeBoundGroup],
        bridges: [GlobalSearchBridge],
        activity: [BridgeBoundLogEntry],
        logs: [BridgeBoundLogEntry],
        docs: [DocBrowserEntry]
    ) {
        let tokens = Self.tokens(in: query)
        guard !tokens.isEmpty else { return }

        self.devices = Self.ranked(devices, tokens: tokens) { item in
            let device = item.device
            return (device.friendlyName, [
                device.definition?.vendor, device.definition?.model, device.definition?.description,
                device.description, device.modelId, device.manufacturer, device.ieeeAddress, item.bridgeName
            ])
        }
        self.groups = Self.ranked(groups, tokens: tokens) { item in
            (item.group.friendlyName, [item.group.description, "#\(item.group.id)", item.bridgeName]
                + item.group.scenes.map(\.name))
        }
        self.bridges = Self.ranked(bridges, tokens: tokens) { bridge in
            (bridge.name, [bridge.version])
        }
        self.activity = Self.chronological(activity, tokens: tokens) { item in
            [item.entry.summaryTitle, item.entry.summarySubtitle, item.entry.deviceName,
             item.entry.category.label, item.entry.message, item.bridgeName]
        }
        self.logs = Self.chronological(logs, tokens: tokens) { item in
            [item.entry.message, item.entry.namespace, item.entry.level.label, item.bridgeName]
        }
        self.docs = Self.ranked(docs, tokens: tokens) { entry in
            (entry.model, [entry.vendor, entry.description])
        }
    }

    var isEmpty: Bool { totalCount == 0 }

    var totalCount: Int {
        GlobalSearchScope.categories.reduce(0) { $0 + count(for: $1) }
    }

    func count(for scope: GlobalSearchScope) -> Int {
        switch scope {
        case .all: totalCount
        case .devices: devices.count
        case .groups: groups.count
        case .bridges: bridges.count
        case .activity: activity.count
        case .logs: logs.count
        case .docs: docs.count
        }
    }

    // MARK: - Matching

    static func tokens(in query: String) -> [String] {
        query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    /// Every token must appear somewhere in the combined fields, so
    /// "hue bedroom" finds "Bedroom Hue" and "kitchen ikea" finds an IKEA
    /// bulb named Kitchen.
    static func matches(_ tokens: [String], in fields: [String?]) -> Bool {
        let haystack = fields.compactMap { $0 }.joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return tokens.allSatisfy { haystack.contains($0) }
    }

    /// Filters by all tokens, then ranks by how well the primary title
    /// matches: exact, prefix, word prefix, anywhere, then other fields.
    private static func ranked<T>(
        _ items: [T],
        tokens: [String],
        fields: (T) -> (title: String, other: [String?])
    ) -> [T] {
        let query = tokens.joined(separator: " ")
        return items
            .compactMap { item -> (T, Int, String)? in
                let (title, other) = fields(item)
                guard matches(tokens, in: [title] + other) else { return nil }
                let folded = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                return (item, titleRank(folded, query: query, tokens: tokens), folded)
            }
            .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.2 < $1.2 }
            .map(\.0)
    }

    private static func titleRank(_ title: String, query: String, tokens: [String]) -> Int {
        if title == query { return 0 }
        if title.hasPrefix(query) { return 1 }
        let words = title.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if tokens.allSatisfy({ token in words.contains { $0.hasPrefix(token) } }) { return 2 }
        if tokens.allSatisfy({ title.contains($0) }) { return 3 }
        return 4
    }

    /// Log-style sources keep their newest-first order; relevance ranking
    /// would scramble the timeline.
    private static func chronological(
        _ items: [BridgeBoundLogEntry],
        tokens: [String],
        fields: (BridgeBoundLogEntry) -> [String?]
    ) -> [BridgeBoundLogEntry] {
        var result: [BridgeBoundLogEntry] = []
        for item in items where matches(tokens, in: fields(item)) {
            result.append(item)
            if result.count == logLimit { break }
        }
        return result
    }
}
