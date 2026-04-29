import Foundation

enum DeviceDocNormalizer {
    static nonisolated func normalize(parsed: ParsedDeviceDoc, device: Device) -> NormalizedDeviceDoc {
        // The Z2M device definition is authoritative for connected devices, but catalog
        // browser entries stub this to false. Fall back to detecting OTA support from the
        // canonical "This device supports OTA updates" phrase in the parsed markdown so
        // the hero chip isn't contradicted by the Advanced section below it.
        let definitionSupportsOTA = device.definition?.supportsOTA ?? false
        let supportsOTA = definitionSupportsOTA || detectSupportsOTA(in: parsed.sections)

        let identity = DeviceDocIdentity(
            vendor: device.definition?.vendor ?? device.manufacturer ?? "Unknown Vendor",
            model: device.definition?.model ?? device.modelId ?? "Unknown Model",
            description: device.definition?.description ?? device.description ?? "",
            imageURL: device.imageURL,
            supportsOTA: supportsOTA,
            exposesSummary: exposesSummary(device.definition?.exposes ?? [])
        )

        let capabilities = makeCapabilities(from: device.definition?.exposes ?? [])

        var pairingSourceBlocks: [DocBlock] = []
        var pairingRelatedBlocks: [DocBlock] = []
        var notesSections: [DocSection] = []
        var advancedSections: [DocSection] = []
        var miscSections: [DocSection] = []
        var options: [DocOption] = []

        for section in parsed.sections {
            let normalizedTitle = normalizeTitle(section.title)

            if normalizedTitle == "pairing" {
                pairingSourceBlocks.append(contentsOf: section.blocks)
                continue
            }

            if normalizedTitle == "options" {
                options.append(contentsOf: collectOptions(in: section.blocks))
                let residual = filterOutOptions(from: section.blocks)
                    .filter { !isBoilerplateConfigurationLink($0) }
                if !residual.isEmpty {
                    miscSections.append(DocSection(title: section.title, level: section.level, blocks: residual))
                }
                continue
            }

            if isAdvancedTitle(normalizedTitle) {
                advancedSections.append(section)
                if isPairingAdjacentTitle(normalizedTitle) {
                    pairingRelatedBlocks.append(contentsOf: section.blocks)
                }
                continue
            }

            if normalizedTitle == "notes" {
                let extraction = extractFromNotes(section)
                pairingSourceBlocks.append(contentsOf: extraction.pairingBlocks)
                pairingRelatedBlocks.append(contentsOf: extraction.pairingRelatedBlocks)
                if !extraction.noteBlocks.isEmpty {
                    notesSections.append(DocSection(title: section.title, level: section.level, blocks: extraction.noteBlocks))
                }
                continue
            }

            if normalizedTitle == "exposes" {
                advancedSections.append(section)
                continue
            }

            if isNoteLikeTitle(normalizedTitle) {
                notesSections.append(section)
            } else {
                miscSections.append(section)
            }
        }

        let pairing = makePairingGuide(
            from: pairingSourceBlocks,
            relatedBlocks: pairingRelatedBlocks,
            identity: identity
        )

        let quality: NormalizedDeviceDoc.Quality
        if pairing != nil || !capabilities.isEmpty || !options.isEmpty || !notesSections.isEmpty {
            quality = miscSections.isEmpty ? .fullyNormalized : .partiallyNormalized
        } else {
            quality = .parsedOnly
        }

        return NormalizedDeviceDoc(
            identity: identity,
            pairing: pairing?.hasContent == true ? pairing : nil,
            capabilities: capabilities,
            options: options,
            notesSections: notesSections,
            advancedSections: advancedSections,
            miscSections: miscSections,
            quality: quality
        )
    }

    static nonisolated func normalizeTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static nonisolated func collectOptions(in blocks: [DocBlock]) -> [DocOption] {
        blocks.flatMap { block in
            switch block {
            case .optionsList(let options):
                return options
            case .subsection(_, let subblocks):
                return collectOptions(in: subblocks)
            default:
                return []
            }
        }
    }

    /// True when the block is the generic "How to use device type specific configuration"
    /// link that almost every Z2M device page emits under its Options section.
    /// It's a link to the Z2M configuration guide with no device-specific content.
    private static nonisolated func isBoilerplateConfigurationLink(_ block: DocBlock) -> Bool {
        let spans: [InlineSpan]
        switch block {
        case .paragraph(let s), .note(let s): spans = s
        default: return false
        }
        let text = plainText(spans)
        if text.contains("device type specific configuration") { return true }
        let hasOnlyLink = spans.allSatisfy { span in
            if case .link = span { return true }
            if case .text(let t) = span, t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            return false
        }
        let targetsConfigGuide = spans.contains { span in
            if case .link(_, let url) = span {
                return url.contains("devices-groups.md") || url.contains("specific-device-options")
            }
            return false
        }
        return hasOnlyLink && targetsConfigGuide
    }

    private static nonisolated func filterOutOptions(from blocks: [DocBlock]) -> [DocBlock] {
        blocks.compactMap { block in
            switch block {
            case .optionsList:
                return nil
            case .subsection(let title, let subblocks):
                let filtered = filterOutOptions(from: subblocks)
                return filtered.isEmpty ? nil : .subsection(title: title, blocks: filtered)
            default:
                return block
            }
        }
    }

    static nonisolated func firstParagraph(in blocks: [DocBlock]) -> [InlineSpan]? {
        for block in blocks {
            switch block {
            case .paragraph(let spans):
                return spans
            case .subsection(_, let subblocks):
                if let spans = firstParagraph(in: subblocks) {
                    return spans
                }
            default:
                continue
            }
        }
        return nil
    }

    static nonisolated func collectParagraphSpans(from blocks: [DocBlock]) -> [[InlineSpan]] {
        var result: [[InlineSpan]] = []
        for block in blocks {
            switch block {
            case .paragraph(let spans):
                result.append(spans)
            case .note(let spans):
                result.append(spans)
            case .subsection(_, let subblocks):
                result.append(contentsOf: collectParagraphSpans(from: subblocks))
            default:
                break
            }
        }
        return result
    }

    static nonisolated func unique(_ items: [[InlineSpan]]) -> [[InlineSpan]] {
        var seen = Set<String>()
        return items.filter { spans in
            let key = plainText(spans)
            guard !key.isEmpty, seen.insert(key).inserted else { return false }
            return true
        }
    }

    static nonisolated func plainText(_ spans: [InlineSpan]) -> String {
        spans.map { span in
            switch span {
            case .text(let text), .bold(let text), .italic(let text), .boldItalic(let text), .code(let text):
                return text
            case .link(let label, _):
                return label
            }
        }
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    }

    static nonisolated func matchesAny(_ spans: [InlineSpan], keywords: [String]) -> Bool {
        let text = plainText(spans)
        return keywords.contains { text.contains($0) }
    }

    private static nonisolated func makeCapabilities(from exposes: [Expose]) -> [DeviceDocCapability] {
        exposes.flattened.map { expose in
            let title = expose.label ?? expose.name ?? expose.property ?? expose.type.capitalized
            let subtitle = expose.property ?? expose.name
            let detailChips = capabilityChips(for: expose)
            return DeviceDocCapability(
                title: title,
                subtitle: subtitle == title ? nil : subtitle,
                summary: capabilitySummary(for: expose),
                kind: expose.type,
                unit: expose.unit,
                isReadable: expose.isReadable,
                isWritable: expose.isWritable,
                detailChips: detailChips
            )
        }
    }

    private static nonisolated func capabilitySummary(for expose: Expose) -> String {
        if let description = expose.description, !description.isEmpty {
            return description
        }

        var parts: [String] = []
        if let values = expose.values, !values.isEmpty {
            parts.append("Possible values: \(values.joined(separator: ", "))")
        }
        if let min = expose.valueMin, let max = expose.valueMax {
            let range = "\(formatNumber(min)) to \(formatNumber(max))"
            if let unit = expose.unit, !unit.isEmpty {
                parts.append("Range \(range) \(unit)")
            } else {
                parts.append("Range \(range)")
            }
        } else if let unit = expose.unit, !unit.isEmpty {
            parts.append("Reports in \(unit)")
        }

        let access: String
        switch (expose.isReadable, expose.isWritable) {
        case (true, true): access = "Readable and writable."
        case (true, false): access = "Read-only."
        case (false, true): access = "Write-only."
        default: access = "State only."
        }
        parts.append(access)

        return parts.joined(separator: ". ")
    }

    private static nonisolated func capabilityChips(for expose: Expose) -> [String] {
        var chips: [String] = []
        if let endpoint = expose.endpoint, !endpoint.isEmpty { chips.append(endpoint.uppercased()) }
        if let values = expose.values, !values.isEmpty, values.count <= 3 { chips.append(values.joined(separator: " / ")) }
        if let step = expose.valueStep { chips.append("Step \(formatNumber(step))") }
        return orderedUnique(chips)
    }

    private static nonisolated func orderedUnique(_ items: [String]) -> [String] {
        var seen: Set<String> = []
        return items.filter { seen.insert($0).inserted }
    }

    private static nonisolated func formatNumber(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }

    private static nonisolated func exposesSummary(_ exposes: [Expose]) -> String? {
        let labels = exposes.flattened
            .map { $0.label ?? $0.name ?? $0.type.capitalized }
            .filter { !$0.isEmpty }
        guard !labels.isEmpty else { return nil }
        return Array(labels.prefix(5)).joined(separator: ", ")
    }

    /// Detects OTA support from the canonical Z2M doc phrasing. Z2M device pages emit
    /// "This device supports OTA updates" for OTA-capable devices; absence of an OTA
    /// section (or a negation) means unsupported.
    private static nonisolated func detectSupportsOTA(in sections: [DocSection]) -> Bool {
        for section in sections {
            let lowercasedTitle = section.title.lowercased()
            guard lowercasedTitle.contains("ota") else { continue }
            let body = aggregateText(section.blocks).lowercased()
            if body.contains("does not support ota") || body.contains("no ota") {
                return false
            }
            if body.contains("supports ota") {
                return true
            }
        }
        return false
    }

    private static nonisolated func aggregateText(_ blocks: [DocBlock]) -> String {
        blocks.map { block -> String in
            switch block {
            case .paragraph(let spans), .note(let spans):
                return plainText(spans)
            case .bulletList(let items):
                return items.map(plainText).joined(separator: " ")
            case .stepList(let steps):
                return steps.map { plainText($0.spans) }.joined(separator: " ")
            case .subsection(_, let inner):
                return aggregateText(inner)
            case .codeBlock(let s):
                return s
            case .table, .optionsList:
                return ""
            }
        }.joined(separator: " ")
    }

    private static nonisolated func isAdvancedTitle(_ title: String) -> Bool {
        title.contains("ota")
            || title.contains("binding")
            || title.contains("power-on behavior")
            || title.contains("firmware")
            || title.contains("issue")
            || title.contains("warning")
            || title.contains("related")
            || title.contains("transition")
    }

    private static nonisolated func isNoteLikeTitle(_ title: String) -> Bool {
        title.contains("note")
            || title.contains("troubleshooting")
            || title.contains("warning")
    }

    static nonisolated func isPairingAdjacentTitle(_ title: String) -> Bool {
        title.contains("troubleshooting")
            || title.contains("factory reset")
            || title.contains("install code")
            || title.contains("touchlink")
            || title.contains("bluetooth")
            || title.contains("power cycling")
            || title.contains("pair")
    }

}
