import Foundation

/// Coarse time buckets used as section headers in the Activity Log. Mirrors
/// the chunking Mail and Messages use so the eye can group at a glance:
/// fresh stuff at the top, then "earlier today", then yesterday, then dated
/// rows for older entries. Entries are assumed to be sorted newest-first by
/// the caller — `sectioned(_:)` collapses consecutive equal buckets in one
/// pass without re-sorting.
enum LogTimeBucket: Hashable {
    case justNow
    case earlierToday
    case yesterday
    case onDay(Date)

    static func bucket(for date: Date, now: Date = .now, calendar: Calendar = .current) -> LogTimeBucket {
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return .justNow }
        if calendar.isDate(date, inSameDayAs: now) { return .earlierToday }
        if calendar.isDateInYesterday(date) { return .yesterday }
        let startOfDay = calendar.startOfDay(for: date)
        return .onDay(startOfDay)
    }

    /// Section header text. Older buckets format as a date so the user can
    /// orient long-running logs without doing day-counting in their head.
    var headerTitle: String {
        switch self {
        case .justNow: return "Just now"
        case .earlierToday: return "Earlier today"
        case .yesterday: return "Yesterday"
        case .onDay(let date):
            let calendar = Calendar.current
            let now = Date()
            // Drop the year for entries less than ~6 months old — the date
            // alone is enough orientation. Older entries get the full
            // year so a year-old log doesn't look like it happened this
            // week.
            if let months = calendar.dateComponents([.month], from: date, to: now).month, months < 6 {
                return date.formatted(.dateTime.month(.abbreviated).day())
            }
            return date.formatted(.dateTime.month(.abbreviated).day().year())
        }
    }
}

extension LogTimeBucket {
    /// Group an already-newest-first sequence into contiguous buckets. Each
    /// bucket appears at most once in the result because all entries that
    /// fall in the same bucket are guaranteed to be consecutive in a
    /// time-sorted sequence.
    static func sectioned<T>(
        _ entries: [T],
        date: (T) -> Date,
        now: Date = .now
    ) -> [(bucket: LogTimeBucket, items: [T])] {
        var result: [(LogTimeBucket, [T])] = []
        for entry in entries {
            let bucket = bucket(for: date(entry), now: now)
            if let last = result.last, last.0 == bucket {
                result[result.count - 1].1.append(entry)
            } else {
                result.append((bucket, [entry]))
            }
        }
        return result
    }
}
