import Foundation

/// Reads the "Exposes" section that z2m's docgen writes for every device
/// page, so Device Library entries (which have no device definition) get
/// the same capability rows as paired devices.
///
/// Docgen writes one `### Label (type[, <x> endpoint])` block per expose,
/// with fixed sentences for the property, access, range, unit and values.
/// Composite exposes (`### Light`, `### Switch`, `### Cover` …) have no type
/// in the heading and list their features as bullets or payload examples.
/// Anything that doesn't match these shapes is skipped.
enum DeviceDocExposesParser {
    static nonisolated func exposes(from section: DocSection) -> [Expose] {
        section.blocks.flatMap { block -> [Expose] in
            guard case .subsection(let title, let blocks) = block else { return [] }
            return exposes(title: title, blocks: blocks)
        }
    }

    // MARK: - One heading

    private static nonisolated func exposes(title: String, blocks: [DocBlock]) -> [Expose] {
        let heading = Heading(title)
        let paragraphs = blocks.compactMap { block -> String? in
            if case .paragraph(let spans) = block { return markdown(spans) }
            return nil
        }
        let text = paragraphs.joined(separator: " ")

        if let type = heading.type {
            guard let property = firstMatch(#"on the `([^`]+)` property"#, in: text)
                ?? firstMatch(#"payload `\{"([^"]+)":"#, in: text)
            else { return [] }
            return [expose(
                type: type,
                label: heading.label,
                property: property,
                endpoint: heading.endpoint,
                description: description(from: paragraphs.first),
                text: text
            )]
        }

        // Composite heading: features come from bullets (Light) or from the
        // payload sentences (Switch, Cover).
        let bullets = blocks.flatMap { block -> [String] in
            switch block {
            case .bulletList(let items): items.map(markdown)
            case .optionsList(let options): options.map { "`\($0.name)`: " + markdown($0.description) }
            default: []
            }
        }
        if !bullets.isEmpty {
            return bullets.compactMap { bullet in
                // Payload examples under a feature ("`{"color": …}`") aren't features.
                guard let property = firstMatch(#"^`([a-z0-9_]+)`"#, in: bullet) else { return nil }
                let type = property == "state" ? "binary" : bullet.contains("number between") ? "numeric" : "composite"
                return expose(
                    type: type,
                    label: humanised(property),
                    property: property,
                    endpoint: heading.endpoint,
                    description: nil,
                    text: bullet
                )
            }
        }
        return payloadExposes(in: text, endpoint: heading.endpoint)
    }

    /// "Switch" and "Cover" blocks describe `state` and `position` in prose.
    private static nonisolated func payloadExposes(in text: String, endpoint: String?) -> [Expose] {
        var result: [Expose] = []
        if let property = firstMatch(#"under the `([^`]+)` property"#, in: text) {
            let values = allMatches(#"`([A-Z_]+)`"#, in: firstMatch(#"\(value is ([^)]+)\)"#, in: text) ?? "")
            result.append(Expose(
                type: "enum", name: property, label: humanised(property), description: nil,
                access: accessBits(readable: true, writable: text.contains("To control"), gettable: text.contains("To read the current")),
                property: property, endpoint: endpoint, features: nil, options: nil, unit: nil,
                valueMin: nil, valueMax: nil, valueStep: nil, values: values.isEmpty ? nil : values,
                valueOn: nil, valueOff: nil, presets: nil
            ))
        }
        let pattern = #"payload `\{"([^"]+)": VALUE\}` where `VALUE` is a number between `(-?[\d.]+)` and `(-?[\d.]+)`"#
        for match in groups(pattern, in: text) where match.count == 3 {
            result.append(Expose(
                type: "numeric", name: match[0], label: humanised(match[0]), description: nil,
                access: accessBits(readable: true, writable: true, gettable: false),
                property: match[0], endpoint: endpoint, features: nil, options: nil, unit: nil,
                valueMin: Double(match[1]), valueMax: Double(match[2]), valueStep: nil, values: nil,
                valueOn: nil, valueOff: nil, presets: nil
            ))
        }
        return result
    }

    private static nonisolated func expose(
        type: String,
        label: String,
        property: String,
        endpoint: String?,
        description: String?,
        text: String
    ) -> Expose {
        let values: [String]? = {
            if let list = firstMatch(#"(?:possible values are|allowed values): (.+?)(?:\.$|\. |$)"#, in: text) {
                let items = allMatches(#"`([^`]+)`"#, in: list)
                return items.isEmpty ? nil : items
            }
            return nil
        }()
        let min = firstMatch(#"minimal value is `(-?[\d.]+)`"#, in: text)
            ?? firstMatch(#"number between `(-?[\d.]+)`"#, in: text)
        let max = firstMatch(#"maximum value is `(-?[\d.]+)`"#, in: text)
            ?? firstMatch(#"number between `-?[\d.]+` and `(-?[\d.]+)`"#, in: text)
        let readable = text.contains("published state") || text.contains("To read")
        let writable = text.contains("To write") || text.contains("To control") || text.contains("Can be set by publishing")
        let gettable = text.contains("To read")
        return Expose(
            type: type, name: property, label: label, description: description,
            access: accessBits(readable: readable, writable: writable, gettable: gettable),
            property: property, endpoint: endpoint, features: nil, options: nil,
            unit: firstMatch(#"unit of this value is `([^`]+)`"#, in: text),
            valueMin: min.flatMap(Double.init), valueMax: max.flatMap(Double.init), valueStep: nil,
            values: type == "enum" ? values : type == "binary" ? binaryValues(in: text) : nil,
            valueOn: nil, valueOff: nil, presets: nil
        )
    }

    // MARK: - Heading

    private struct Heading {
        let label: String
        let type: String?
        let endpoint: String?

        nonisolated init(_ title: String) {
            let trimmed = title.trimmingCharacters(in: .whitespaces)
            guard let open = trimmed.lastIndex(of: "("), trimmed.hasSuffix(")") else {
                label = trimmed
                type = nil
                endpoint = nil
                return
            }
            label = trimmed[..<open].trimmingCharacters(in: .whitespaces)
            let parts = trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            let known: Set<String> = ["numeric", "binary", "enum", "text", "list", "composite"]
            type = parts.first.flatMap { known.contains($0) ? $0 : nil }
            endpoint = parts.first { $0.hasSuffix(" endpoint") }.map { String($0.dropLast(" endpoint".count)) }
        }
    }

    // MARK: - Text helpers

    /// The first sentence, when it describes the expose rather than one of
    /// docgen's fixed access sentences.
    private static nonisolated func description(from paragraph: String?) -> String? {
        guard let paragraph else { return nil }
        let fixed = ["Value can be found", "Value will", "It's not possible", "To read", "To write", "Can be set", "The possible", "The minimal", "The unit", "If value equals"]
        // A sentence ends at a full stop followed by a capital, so "e.g. make"
        // stays inside it.
        let sentence = firstMatch(#"^(.+?\.)(?=\s+[A-Z`]|$)"#, in: paragraph) ?? paragraph
        guard case let first = sentence.trimmingCharacters(in: .whitespaces),
              !first.isEmpty,
              !fixed.contains(where: { first.hasPrefix($0) })
        else { return nil }
        return first.hasSuffix(".") ? first : first + "."
    }

    /// "If value equals `true` occupancy is ON, if `false` OFF" → [true, false].
    private static nonisolated func binaryValues(in text: String) -> [String]? {
        guard let match = groups(#"value equals `([^`]+)`.*?if `([^`]+)`"#, in: text).first, match.count == 2 else { return nil }
        return match
    }

    private static nonisolated func accessBits(readable: Bool, writable: Bool, gettable: Bool) -> Int {
        (readable ? 1 : 0) | (writable ? 2 : 0) | (gettable ? 4 : 0)
    }

    /// "color_temp" → "Color temp", the way z2m builds labels, with the few
    /// labels z2m spells out itself.
    static nonisolated func humanised(_ key: String) -> String {
        switch key {
        case "color_xy": return "Color (X/Y)"
        case "color_hs": return "Color (HS)"
        default: break
        }
        let words = key.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// Spans back to markdown, keeping code in backticks for matching.
    private static nonisolated func markdown(_ spans: [InlineSpan]) -> String {
        spans.map { span in
            switch span {
            case .text(let text), .bold(let text), .italic(let text), .boldItalic(let text): text
            case .code(let code): "`\(code)`"
            case .link(let label, _): label
            }
        }
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static nonisolated func firstMatch(_ pattern: String, in text: String) -> String? {
        groups(pattern, in: text).first?.first
    }

    private static nonisolated func allMatches(_ pattern: String, in text: String) -> [String] {
        groups(pattern, in: text).compactMap(\.first)
    }

    private static nonisolated func groups(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match in
            (1..<match.numberOfRanges).compactMap { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) }
            }
        }
    }
}
