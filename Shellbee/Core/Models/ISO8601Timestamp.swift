import Foundation

/// A fast parser for the RFC 3339 timestamps z2m sends as `last_seen`
/// (`2026-09-29T00:31:12.345+02:00`, `…Z`, with or without fractional
/// seconds). `ISO8601DateFormatter` takes tens of microseconds per string,
/// which adds up when Home reads every device's last-seen on each redraw.
nonisolated enum ISO8601Timestamp {
    static func date(from string: String) -> Date? {
        var utf8 = string.utf8[...]
        guard let year = digits(&utf8, 4), take(&utf8, "-"),
              let month = digits(&utf8, 2), take(&utf8, "-"),
              let day = digits(&utf8, 2), take(&utf8, "T") || take(&utf8, " "),
              let hour = digits(&utf8, 2), take(&utf8, ":"),
              let minute = digits(&utf8, 2), take(&utf8, ":"),
              let second = digits(&utf8, 2),
              (1...12).contains(month), (1...31).contains(day),
              hour < 24, minute < 60, second < 61
        else { return nil }

        var fraction = 0.0
        if take(&utf8, ".") {
            var scale = 0.1
            var sawDigit = false
            while let byte = utf8.first, byte >= 48, byte <= 57 {
                fraction += Double(byte - 48) * scale
                scale /= 10
                sawDigit = true
                utf8.removeFirst()
            }
            guard sawDigit else { return nil }
        }

        var offset = 0
        if take(&utf8, "Z") || take(&utf8, "z") {
            offset = 0
        } else if let sign = utf8.first, sign == UInt8(ascii: "+") || sign == UInt8(ascii: "-") {
            utf8.removeFirst()
            guard let hours = digits(&utf8, 2) else { return nil }
            _ = take(&utf8, ":")
            guard let minutes = digits(&utf8, 2) else { return nil }
            offset = (hours * 3600 + minutes * 60) * (sign == UInt8(ascii: "-") ? -1 : 1)
        } else {
            return nil
        }
        guard utf8.isEmpty else { return nil }

        let seconds = daysFromCivil(year: year, month: month, day: day) * 86_400
            + hour * 3600 + minute * 60 + second - offset
        return Date(timeIntervalSince1970: Double(seconds) + fraction)
    }

    private static func digits(_ utf8: inout Substring.UTF8View, _ count: Int) -> Int? {
        var value = 0
        for _ in 0..<count {
            guard let byte = utf8.first, byte >= 48, byte <= 57 else { return nil }
            value = value * 10 + Int(byte - 48)
            utf8.removeFirst()
        }
        return value
    }

    private static func take(_ utf8: inout Substring.UTF8View, _ character: Unicode.Scalar) -> Bool {
        guard utf8.first == UInt8(ascii: character) else { return false }
        utf8.removeFirst()
        return true
    }

    /// Days since 1970-01-01 in the proleptic Gregorian calendar
    /// (Howard Hinnant's `days_from_civil`).
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
