import Foundation

/// One minute of raw log lines, drawn as a single card in the Log feed.
struct RawLogBlock: Identifiable, Hashable {
    /// Start of the minute.
    let minute: Date
    /// Newest first. Never empty.
    let lines: [BridgeBoundLogEntry]

    var id: Date { minute }

    /// Splits newest-first entries into minute blocks, newest first.
    static func blocks(from entries: [BridgeBoundLogEntry], calendar: Calendar = .current) -> [RawLogBlock] {
        var blocks: [RawLogBlock] = []
        var current: [BridgeBoundLogEntry] = []
        var currentMinute: Date?

        for item in entries {
            let minute = calendar.dateInterval(of: .minute, for: item.entry.timestamp)?.start ?? item.entry.timestamp
            if minute != currentMinute, let start = currentMinute, !current.isEmpty {
                blocks.append(RawLogBlock(minute: start, lines: current))
                current = []
            }
            currentMinute = minute
            current.append(item)
        }
        if let start = currentMinute, !current.isEmpty {
            blocks.append(RawLogBlock(minute: start, lines: current))
        }
        return blocks
    }
}
