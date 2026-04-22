import Foundation

struct ParsedGuideDoc: Sendable {
    let title: String
    let sourcePath: String
    let parsed: ParsedDeviceDoc
}

struct ParsedDeviceDoc: Sendable {
    let sections: [DocSection]

    var isEmpty: Bool { sections.isEmpty }

    var pairingSection: DocSection? {
        // Check top-level H2 sections first
        if let direct = sections.first(where: { $0.title.caseInsensitiveCompare("Pairing") == .orderedSame }) {
            return direct
        }
        // Many devices nest Pairing as ### under ## Notes — walk one level deep
        for section in sections {
            for block in section.blocks {
                if case .subsection(let title, let blocks) = block,
                   title.caseInsensitiveCompare("Pairing") == .orderedSame {
                    return DocSection(title: "Pairing", level: 3, blocks: blocks)
                }
            }
        }
        return nil
    }

    var hasDocumentation: Bool { !sections.isEmpty }
}

struct DocSection: Sendable, Identifiable {
    let id: UUID
    let title: String
    let level: Int
    var blocks: [DocBlock]

    nonisolated init(title: String, level: Int, blocks: [DocBlock] = []) {
        self.id = UUID()
        self.title = title
        self.level = level
        self.blocks = blocks
    }
}

enum DocBlock: Sendable {
    case paragraph([InlineSpan])
    case stepList([StepItem])
    case bulletList([[InlineSpan]])
    case note([InlineSpan])
    case codeBlock(String)
    case table(DocTable)
    case optionsList([DocOption])
    case subsection(title: String, blocks: [DocBlock])
}

enum InlineSpan: Sendable {
    case text(String)
    case bold(String)
    case italic(String)
    case boldItalic(String)
    case code(String)
    case link(label: String, url: String)
}

struct StepItem: Sendable, Identifiable {
    let id: UUID
    let number: Int
    let spans: [InlineSpan]

    nonisolated init(number: Int, spans: [InlineSpan]) {
        self.id = UUID()
        self.number = number
        self.spans = spans
    }
}

struct DocTable: Sendable {
    let headers: [String]
    let rows: [[String]]
}

struct DocOption: Sendable, Identifiable {
    let id: UUID
    let name: String
    let type: String?
    let description: [InlineSpan]

    nonisolated init(name: String, type: String? = nil, description: [InlineSpan]) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.description = description
    }
}
