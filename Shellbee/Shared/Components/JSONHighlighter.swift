import SwiftUI

/// Lightweight JSON syntax highlighting via regex over a pretty-printed
/// source string. Used by the MQTT Inspector to color message payloads, but
/// generic enough to drop into any view that surfaces JSON to the user.
enum JSONHighlighter {
    static func attributed(_ source: String) -> AttributedString {
        var out = AttributedString(source)
        out.font = .caption.monospaced()
        out.foregroundColor = .secondary

        // Keys: "<word>" : → blue
        if let regex = try? Regex<(Substring, Substring)>("\"([^\"\\\\]+)\"\\s*:") {
            for match in source.matches(of: regex) {
                let r = match.range
                if let lower = AttributedString.Index(r.lowerBound, within: out),
                   let upper = AttributedString.Index(r.upperBound, within: out) {
                    out[lower..<upper].foregroundColor = .blue
                }
            }
        }

        // String values: : "..." or array element strings → green
        if let regex = try? Regex<(Substring, Substring)>(":\\s*(\"[^\"\\\\]*\")") {
            for match in source.matches(of: regex) {
                let inner = match.output.1
                let r = inner.startIndex..<inner.endIndex
                if let lower = AttributedString.Index(r.lowerBound, within: out),
                   let upper = AttributedString.Index(r.upperBound, within: out) {
                    out[lower..<upper].foregroundColor = .green
                }
            }
        }

        // Numbers: ints / floats → orange
        if let regex = try? Regex<(Substring, Substring)>("(?<![\\w-])(-?\\d+(?:\\.\\d+)?)") {
            for match in source.matches(of: regex) {
                let inner = match.output.1
                let r = inner.startIndex..<inner.endIndex
                if let lower = AttributedString.Index(r.lowerBound, within: out),
                   let upper = AttributedString.Index(r.upperBound, within: out) {
                    out[lower..<upper].foregroundColor = .orange
                }
            }
        }

        // Booleans / null → purple
        for word in ["true", "false", "null"] {
            if let regex = try? Regex<Substring>("\\b\(word)\\b") {
                for match in source.matches(of: regex) {
                    let r = match.range
                    if let lower = AttributedString.Index(r.lowerBound, within: out),
                       let upper = AttributedString.Index(r.upperBound, within: out) {
                        out[lower..<upper].foregroundColor = .purple
                    }
                }
            }
        }

        return out
    }
}
