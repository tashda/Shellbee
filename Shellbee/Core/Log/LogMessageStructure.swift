import Foundation

/// Structured rendering shape for log messages whose raw text encodes
/// distinct fields (e.g. Z2M's `Failed to ping ...` warnings carry a
/// device id, attempt counter, ZCL command, options blob, and a nested
/// failure reason). LogDetailView renders this as labelled rows under
/// the existing message section, falling back to raw text when no
/// parser matches.
nonisolated struct LogMessageStructure: Sendable {
    let summary: String
    let fields: [Field]
    /// Optional grouped sub-rows rendered under their own header (e.g.
    /// the request `options` map on a ping failure).
    let groups: [Group]

    struct Field: Identifiable, Sendable {
        let id: UUID = UUID()
        let label: String
        let value: String
    }

    struct Group: Identifiable, Sendable {
        let id: UUID = UUID()
        let title: String
        let fields: [Field]
    }

    init(summary: String, fields: [Field] = [], groups: [Group] = []) {
        self.summary = summary
        self.fields = fields
        self.groups = groups
    }
}

/// Tiny parser registry — each entry inspects an entry's message and
/// returns a `LogMessageStructure` if it recognizes the shape. Add new
/// shapes by appending a parser; LogDetailView falls back to its raw
/// rendering when none match.
nonisolated enum LogMessageParser {
    typealias Parse = @Sendable (_ message: String) -> LogMessageStructure?

    static let parsers: [Parse] = [
        parsePingFailure
    ]

    static func structure(for message: String) -> LogMessageStructure? {
        for parser in parsers {
            if let result = parser(message) { return result }
        }
        return nil
    }

    // MARK: - Ping failure
    //
    // Z2M emits warnings of the form:
    //   Failed to ping '<friendly>' (attempt <n>/<m>, ZCL command <ieee>/<ep> <call>,
    //   <options-json>) failed (<reason>)
    //
    // We pull each piece out by hand rather than with one giant regex so a
    // shape-shift in any field degrades to "no match" (and the raw fallback)
    // instead of producing a wrong-looking parse.
    @Sendable private static func parsePingFailure(_ message: String) -> LogMessageStructure? {
        let trimmed = stripNamespace(message)
        guard trimmed.hasPrefix("Failed to ping ") else { return nil }

        // Device name in single quotes after the prefix.
        guard let nameRange = trimmed.range(of: "'([^']+)'", options: .regularExpression) else {
            return nil
        }
        let device = String(trimmed[nameRange]).trimmingCharacters(in: ["'"])

        // Top-level args inside the first paren after the device name.
        let afterName = trimmed[nameRange.upperBound...]
        guard let openParen = afterName.firstIndex(of: "(") else { return nil }
        let argsStart = afterName.index(after: openParen)
        guard let closeParen = matchingCloseParen(in: afterName, openIndexAfter: openParen) else {
            return nil
        }
        let args = String(afterName[argsStart..<closeParen])

        // Tail after the args paren — typically " failed (<reason>)".
        let tail = String(afterName[afterName.index(after: closeParen)...])

        var fields: [LogMessageStructure.Field] = []

        if let attempt = match(args, pattern: #"attempt\s+(\d+\s*/\s*\d+)"#) {
            fields.append(.init(label: "Attempt", value: attempt))
        }

        if let zcl = match(args, pattern: #"ZCL command\s+([^,]+?)(?=,\s*\{|$)"#) {
            fields.append(.init(label: "ZCL Command", value: zcl.trimmingCharacters(in: .whitespaces)))
        }

        if let reason = match(tail, pattern: #"\(([^)]+?)\.?\)"#) {
            fields.append(.init(label: "Reason", value: reason))
        }

        // Options JSON object — anything between the first `{` and its
        // matching `}` inside args. JSONSerialization for safety.
        var groups: [LogMessageStructure.Group] = []
        if let jsonStart = args.firstIndex(of: "{"),
           let jsonEnd = matchingCloseBrace(in: args, openIndex: jsonStart) {
            let json = String(args[jsonStart...jsonEnd])
            if let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let optionFields = dict.keys.sorted().map { key -> LogMessageStructure.Field in
                    let value = dict[key].map { stringify($0) } ?? ""
                    return .init(label: key, value: value)
                }
                if !optionFields.isEmpty {
                    groups.append(.init(title: "Options", fields: optionFields))
                }
            }
        }

        return LogMessageStructure(
            summary: "Failed to ping '\(device)'",
            fields: fields,
            groups: groups
        )
    }

    // MARK: - helpers

    private static func stripNamespace(_ text: String) -> String {
        guard text.hasPrefix("z2m:") else { return text }
        if let sp = text.range(of: " ") {
            return String(text[sp.upperBound...])
        }
        return text
    }

    private static func match(_ text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, range: range), m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    /// Find the index of the `)` that pairs with the `(` immediately preceding
    /// `openIndexAfter`. Returns nil if the parens are unbalanced.
    private static func matchingCloseParen(in text: Substring, openIndexAfter open: Substring.Index) -> Substring.Index? {
        var depth = 1
        var i = text.index(after: open)
        while i < text.endIndex {
            switch text[i] {
            case "(": depth += 1
            case ")":
                depth -= 1
                if depth == 0 { return i }
            default: break
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func matchingCloseBrace(in text: String, openIndex: String.Index) -> String.Index? {
        var depth = 0
        var i = openIndex
        while i < text.endIndex {
            switch text[i] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return i }
            default: break
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func stringify(_ value: Any) -> String {
        switch value {
        case let b as Bool:    return b ? "true" : "false"
        case let n as NSNumber:
            // Bool comes through as NSNumber; the `as Bool` cast above wins
            // for true booleans, so anything reaching here is numeric.
            return n.stringValue
        case let s as String:  return s
        case let arr as [Any]: return arr.map { stringify($0) }.joined(separator: ", ")
        default:               return String(describing: value)
        }
    }
}
