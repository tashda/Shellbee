import Foundation

// Parses raw Markdown from the Koenkk/zigbee2mqtt.io device pages into a typed AST.
// Handles the common patterns found in Z2M docs: H2 sections, numbered steps,
// option bullet lists, blockquotes, tables, and fenced code blocks.
// Unknown or malformed patterns fall through to paragraph blocks — nothing is lost.
enum DocParser {

    static nonisolated func parse(_ raw: String) -> ParsedDeviceDoc {
        var content = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip YAML frontmatter (--- ... ---)
        if content.hasPrefix("---") {
            let afterOpen = content.dropFirst(3)
            if let closeRange = afterOpen.range(of: "---") {
                content = String(afterOpen[closeRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        var sections: [DocSection] = []
        var currentTitle: String?
        var pendingLines: [String] = []

        func flush() {
            guard let title = currentTitle else { return }
            let blocks = parseBlocks(pendingLines)
            if !blocks.isEmpty {
                sections.append(DocSection(title: title, level: 2, blocks: blocks))
            }
            currentTitle = nil
            pendingLines = []
        }

        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                flush()
                currentTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("# ") {
                continue  // Device title — already known from device.definition
            } else if currentTitle != nil {
                pendingLines.append(line)
            }
        }
        flush()

        return ParsedDeviceDoc(sections: sections)
    }

    // MARK: - Block parsing

    static nonisolated func parseBlocks(_ lines: [String]) -> [DocBlock] {
        var blocks: [DocBlock] = []
        var i = 0

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("<!--") { i += 1; continue }

            // H3 subsection
            if trimmed.hasPrefix("### ") {
                let title = String(trimmed.dropFirst(4))
                var sub: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("### ") {
                    sub.append(lines[i])
                    i += 1
                }
                blocks.append(.subsection(title: title, blocks: parseBlocks(sub)))
                continue
            }

            // Fenced code block
            if trimmed.hasPrefix("```") {
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                i += 1  // closing ```
                if !code.isEmpty { blocks.append(.codeBlock(code.joined(separator: "\n"))) }
                continue
            }

            // Markdown table
            if trimmed.hasPrefix("|") {
                var tableLines: [String] = []
                while i < lines.count, lines[i].contains("|") {
                    tableLines.append(lines[i])
                    i += 1
                }
                if let t = parseTable(tableLines) { blocks.append(.table(t)) }
                continue
            }

            // Blockquote → note callout
            if trimmed.hasPrefix("> ") {
                var parts: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("> ") {
                    parts.append(String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst(2)))
                    i += 1
                }
                blocks.append(.note(parseInline(parts.joined(separator: " "))))
                continue
            }

            // Numbered list (steps)
            if let (num, text) = numberedItem(trimmed) {
                var steps = [StepItem(number: num, spans: parseInline(text))]
                i += 1
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if t.isEmpty { i += 1; continue }  // blank lines allowed between steps
                    guard let (n, s) = numberedItem(t) else { break }
                    steps.append(StepItem(number: n, spans: parseInline(s)))
                    i += 1
                }
                blocks.append(.stepList(steps))
                continue
            }

            // Bullet list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                var items: [[InlineSpan]] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    let pfx: String? = t.hasPrefix("- ") ? "- " : t.hasPrefix("* ") ? "* " : nil
                    guard let p = pfx else { break }
                    items.append(parseInline(String(t.dropFirst(p.count))))
                    i += 1
                }
                if isOptionsList(items) {
                    blocks.append(.optionsList(items.compactMap(makeOption)))
                } else {
                    blocks.append(.bulletList(items))
                }
                continue
            }

            // H4+ headings — fold into a subsection so the infinite-loop fallthrough can't occur
            if trimmed.first == "#" {
                let title = trimmed.drop(while: { $0 == "#" }).drop(while: { $0 == " " })
                var sub: [String] = []
                i += 1
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if t.first == "#" { break }
                    sub.append(lines[i])
                    i += 1
                }
                let subBlocks = parseBlocks(sub)
                if !subBlocks.isEmpty {
                    blocks.append(.subsection(title: String(title), blocks: subBlocks))
                }
                continue
            }

            // Paragraph — accumulate until a structural marker
            var paraLines: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("#") || t.hasPrefix("```") || t.hasPrefix(">") ||
                   t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("|") || t.hasPrefix("<!--") { break }
                if numberedItem(t) != nil { break }
                paraLines.append(t)
                i += 1
            }
            let spans = parseInline(paraLines.joined(separator: " "))
            if !spans.isEmpty { blocks.append(.paragraph(spans)) }
            // Safety: if nothing was consumed (e.g. an unrecognised line pattern), advance to prevent
            // an infinite loop on whatever caused the fallthrough.
            else if paraLines.isEmpty { i += 1 }
        }

        return blocks
    }

    // MARK: - Inline parsing

    static nonisolated func parseInline(_ text: String) -> [InlineSpan] {
        var spans: [InlineSpan] = []
        var buffer = ""
        var i = text.startIndex

        func flush() { if !buffer.isEmpty { spans.append(.text(buffer)); buffer = "" } }
        func advance(_ n: Int) -> String.Index {
            text.index(i, offsetBy: n, limitedBy: text.endIndex) ?? text.endIndex
        }

        while i < text.endIndex {
            // Order matters: *** before ** before *
            if text[i...].hasPrefix("***") {
                let s = advance(3)
                if let end = text[s...].range(of: "***") {
                    flush(); spans.append(.boldItalic(String(text[s..<end.lowerBound]))); i = end.upperBound; continue
                }
            }
            if text[i...].hasPrefix("**") {
                let s = advance(2)
                if let end = text[s...].range(of: "**") {
                    flush(); spans.append(.bold(String(text[s..<end.lowerBound]))); i = end.upperBound; continue
                }
            }
            if text[i] == "*", !text[i...].hasPrefix("**") {
                let s = text.index(after: i)
                if s < text.endIndex, let end = text[s...].range(of: "*") {
                    flush(); spans.append(.italic(String(text[s..<end.lowerBound]))); i = end.upperBound; continue
                }
            }
            if text[i] == "`" {
                let s = text.index(after: i)
                if s < text.endIndex, let end = text[s...].range(of: "`") {
                    flush(); spans.append(.code(String(text[s..<end.lowerBound]))); i = end.upperBound; continue
                }
            }
            if text[i] == "[" {
                let ls = text.index(after: i)
                if let le = text[ls...].range(of: "]("), let ue = text[le.upperBound...].range(of: ")") {
                    flush()
                    spans.append(.link(label: String(text[ls..<le.lowerBound]), url: String(text[le.upperBound..<ue.lowerBound])))
                    i = ue.upperBound
                    continue
                }
            }
            buffer.append(text[i])
            i = text.index(after: i)
        }
        flush()
        return spans
    }

    // MARK: - Helpers

    private static nonisolated func numberedItem(_ trimmed: String) -> (Int, String)? {
        var j = trimmed.startIndex
        var digits = ""
        while j < trimmed.endIndex, trimmed[j].isNumber { digits.append(trimmed[j]); j = trimmed.index(after: j) }
        guard !digits.isEmpty, j < trimmed.endIndex, trimmed[j] == "." || trimmed[j] == ")" else { return nil }
        let afterSep = trimmed.index(after: j)
        guard afterSep < trimmed.endIndex, trimmed[afterSep] == " " else { return nil }
        return (Int(digits) ?? 0, String(trimmed[trimmed.index(after: afterSep)...]))
    }

    private static nonisolated func parseTable(_ lines: [String]) -> DocTable? {
        var rows: [[String]] = []
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            let isRule = t.replacingOccurrences(of: "|", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces).isEmpty
            guard !isRule else { continue }
            let cells = t.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !cells.isEmpty { rows.append(cells) }
        }
        guard rows.count >= 1 else { return nil }
        return DocTable(headers: rows[0], rows: Array(rows.dropFirst()))
    }

    // Heuristic: if ≥50% of items start with a backtick-code span, it's an options list
    private static nonisolated func isOptionsList(_ items: [[InlineSpan]]) -> Bool {
        guard !items.isEmpty else { return false }
        let codeLeads = items.filter { if case .code = $0.first { return true }; return false }.count
        return Double(codeLeads) / Double(items.count) >= 0.5
    }

    private static nonisolated func makeOption(_ spans: [InlineSpan]) -> DocOption? {
        guard case .code(let name) = spans.first else { return nil }
        var desc = Array(spans.dropFirst())
        if case .text(let t) = desc.first {
            let s = t.trimmingCharacters(in: .whitespaces)
            let clean = s.hasPrefix(":") ? String(s.dropFirst(1)).trimmingCharacters(in: .whitespaces) : s
            if clean.isEmpty { desc.removeFirst() } else { desc[0] = .text(clean) }
        }
        let allText = desc.compactMap { if case .text(let t) = $0 { return t }; return nil }.joined()
        return DocOption(name: name, type: detectType(allText), description: desc)
    }

    private static nonisolated func detectType(_ text: String) -> String? {
        let l = text.lowercased()
        if l.contains("true` or `false") || l.contains("must be `true") { return "boolean" }
        if l.contains("must be a number") || l.contains("value is a number") { return "number" }
        if l.contains("one of") && l.contains("enum") { return "enum" }
        if l.contains("must be a string") { return "string" }
        return nil
    }
}
