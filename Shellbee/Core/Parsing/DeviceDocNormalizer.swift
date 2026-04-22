import Foundation

struct DeviceDocumentation: Sendable {
    let sourcePath: String
    let parsed: ParsedDeviceDoc
    let normalized: NormalizedDeviceDoc
}

struct NormalizedDeviceDoc: Sendable {
    let identity: DeviceDocIdentity
    let pairing: DevicePairingGuide?
    let capabilities: [DeviceDocCapability]
    let options: [DocOption]
    let notesSections: [DocSection]
    let advancedSections: [DocSection]
    let miscSections: [DocSection]
    let quality: Quality

    enum Quality: Sendable, Equatable {
        case fullyNormalized
        case partiallyNormalized
        case parsedOnly
    }

    var additionalSections: [DocSection] { advancedSections + miscSections }
    var hasSemanticContent: Bool {
        pairing != nil || !capabilities.isEmpty || !options.isEmpty || !notesSections.isEmpty
    }
}

struct DeviceDocIdentity: Sendable {
    let vendor: String
    let model: String
    let description: String
    let imageURL: URL?
    let supportsOTA: Bool
    let exposesSummary: String?
}

struct DevicePairingGuide: Sendable {
    let summary: [InlineSpan]
    let prerequisites: [[InlineSpan]]
    let primarySteps: [StepItem]
    let alternatives: [DevicePairingMethod]
    let successCues: [[InlineSpan]]
    let troubleshooting: [[InlineSpan]]
    let additionalNotes: [DocBlock]

    nonisolated var hasContent: Bool {
        !summary.isEmpty
            || !prerequisites.isEmpty
            || !primarySteps.isEmpty
            || !alternatives.isEmpty
            || !successCues.isEmpty
            || !troubleshooting.isEmpty
            || !additionalNotes.isEmpty
    }
}

struct DevicePairingMethod: Sendable, Identifiable {
    let id: UUID
    let title: String
    let summary: [InlineSpan]
    let steps: [StepItem]
    let notes: [DocBlock]
    /// True when this alternative is purely a reference to the Touchlink guide with no
    /// device-specific steps. The UI replaces the generic card with an in-app Touchlink button.
    let isTouchlinkReset: Bool
    /// True when this alternative describes a Philips Hue serial-number factory reset.
    /// The UI replaces the raw Z2M content with an in-app Philips Hue Reset action.
    let isPhilipsHueSerialReset: Bool

    nonisolated init(title: String, summary: [InlineSpan] = [], steps: [StepItem] = [], notes: [DocBlock] = [], isTouchlinkReset: Bool = false, isPhilipsHueSerialReset: Bool = false) {
        self.id = UUID()
        self.title = title
        self.summary = summary
        self.steps = steps
        self.notes = notes
        self.isTouchlinkReset = isTouchlinkReset
        self.isPhilipsHueSerialReset = isPhilipsHueSerialReset
    }
}

struct DeviceDocCapability: Sendable, Identifiable {
    let id: UUID
    let title: String
    let subtitle: String?
    let summary: String
    let kind: String
    let unit: String?
    let isReadable: Bool
    let isWritable: Bool
    let detailChips: [String]

    nonisolated init(
        title: String,
        subtitle: String? = nil,
        summary: String,
        kind: String,
        unit: String? = nil,
        isReadable: Bool,
        isWritable: Bool,
        detailChips: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.kind = kind
        self.unit = unit
        self.isReadable = isReadable
        self.isWritable = isWritable
        self.detailChips = detailChips
    }
}

enum DeviceDocNormalizer {
    static nonisolated func normalize(parsed: ParsedDeviceDoc, device: Device) -> NormalizedDeviceDoc {
        let identity = DeviceDocIdentity(
            vendor: device.definition?.vendor ?? device.manufacturer ?? "Unknown Vendor",
            model: device.definition?.model ?? device.modelId ?? "Unknown Model",
            description: device.definition?.description ?? device.description ?? "",
            imageURL: device.imageURL,
            supportsOTA: device.definition?.supportsOTA ?? false,
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

    private static nonisolated func normalizeTitle(_ title: String) -> String {
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

    private static nonisolated func extractFromNotes(_ section: DocSection) -> (pairingBlocks: [DocBlock], pairingRelatedBlocks: [DocBlock], noteBlocks: [DocBlock]) {
        var pairingBlocks: [DocBlock] = []
        var pairingRelatedBlocks: [DocBlock] = []
        var noteBlocks: [DocBlock] = []

        for block in section.blocks {
            switch block {
            case .subsection(let title, let blocks):
                let normalizedTitle = normalizeTitle(title)
                if normalizedTitle == "pairing" {
                    pairingBlocks.append(contentsOf: blocks)
                } else if isPairingAdjacentTitle(normalizedTitle) {
                    pairingRelatedBlocks.append(.subsection(title: title, blocks: blocks))
                } else {
                    noteBlocks.append(.subsection(title: title, blocks: blocks))
                }
            default:
                noteBlocks.append(block)
            }
        }

        return (pairingBlocks, pairingRelatedBlocks, noteBlocks)
    }

    private static nonisolated func makePairingGuide(
        from pairingBlocks: [DocBlock],
        relatedBlocks: [DocBlock],
        identity: DeviceDocIdentity
    ) -> DevicePairingGuide? {
        // Only count steps that came from real step-list blocks, not paragraph fallback.
        // Paragraph fallback produces step text identical to the summary, which would show twice.
        let primarySteps = collectStepItems(from: pairingBlocks, paragraphFallback: false)
        let summary = firstParagraph(in: pairingBlocks) ?? defaultPairingSummary(identity: identity, hasSteps: !primarySteps.isEmpty)
        let summaryText = plainText(summary)

        // Exclude summary so it doesn't also appear in Before You Start / Success / Troubleshooting
        let paragraphs = collectParagraphSpans(from: pairingBlocks + relatedBlocks)
            .filter { plainText($0) != summaryText }

        let prerequisites = unique(paragraphs.filter { matchesAny($0, keywords: prerequisiteKeywords) })
        let successCues = unique(paragraphs.filter { matchesAny($0, keywords: successKeywords) })
        let troubleshooting = unique(paragraphs.filter { matchesAny($0, keywords: troubleshootingKeywords) })

        // Track every plain-text span already shown in a named section so additionalNotes never repeats them
        var usedTexts = Set<String>([summaryText])
        for spans in prerequisites + successCues + troubleshooting {
            usedTexts.insert(plainText(spans))
        }

        let alternatives = collectSubsections(from: pairingBlocks)
            .filter { normalizeTitle($0.title) != "pairing" }
            .map { subsection in
                let altSummary = firstParagraph(in: subsection.blocks) ?? []
                let altSummaryText = plainText(altSummary)
                let altSteps = collectStepItems(from: subsection.blocks, paragraphFallback: false)
                let altNotes = subsection.blocks.filter { block in
                    guard !isPureStepList(block) else { return false }
                    if case .paragraph(let spans) = block { return plainText(spans) != altSummaryText }
                    return true
                }
                let normalizedSubtitle = normalizeTitle(subsection.title)
                // A subsection is a pure Touchlink reference when its title mentions Touchlink and it
                // contains no device-specific steps or notes — just a link to the Touchlink guide.
                let isTouchlinkReset = normalizedSubtitle.contains("touchlink")
                    && altSteps.isEmpty
                    && altNotes.isEmpty
                // A subsection describes a Philips Hue serial-number reset when it mentions
                // "touchlink" and "serial". The Z2M docs include raw JSON and frontend references
                // for this flow which the app replaces with the in-app Philips Hue Reset action.
                let isPhilipsHueSerialReset = normalizedSubtitle.contains("touchlink")
                    && normalizedSubtitle.contains("serial")
                return DevicePairingMethod(
                    title: subsection.title,
                    summary: altSummary,
                    steps: altSteps,
                    notes: altNotes,
                    isTouchlinkReset: isTouchlinkReset,
                    isPhilipsHueSerialReset: isPhilipsHueSerialReset
                )
            }
            .filter { !$0.summary.isEmpty || !$0.steps.isEmpty || !$0.notes.isEmpty || $0.isTouchlinkReset || $0.isPhilipsHueSerialReset }

        // Subsection titles promoted to Alternatives — skip them in additionalNotes
        let alternativeTitles = Set(alternatives.map { normalizeTitle($0.title) })

        let additionalNotes = (pairingBlocks + relatedBlocks).filter { block in
            switch block {
            case .paragraph(let spans), .note(let spans):
                return !usedTexts.contains(plainText(spans))
            case .stepList:
                return false
            case .subsection(let title, _):
                return !alternativeTitles.contains(normalizeTitle(title))
            default:
                return true
            }
        }

        let guide = DevicePairingGuide(
            summary: summary,
            prerequisites: prerequisites,
            primarySteps: primarySteps,
            alternatives: alternatives,
            successCues: successCues,
            troubleshooting: troubleshooting,
            additionalNotes: additionalNotes
        )

        return guide.hasContent ? guide : nil
    }

    private static nonisolated func collectSubsections(from blocks: [DocBlock]) -> [(title: String, blocks: [DocBlock])] {
        blocks.compactMap { block in
            if case .subsection(let title, let blocks) = block {
                return (title, blocks)
            }
            return nil
        }
    }

    private static nonisolated func isPureStepList(_ block: DocBlock) -> Bool {
        if case .stepList = block { return true }
        return false
    }

    private static nonisolated func collectStepItems(from blocks: [DocBlock], paragraphFallback: Bool = true) -> [StepItem] {
        var result: [StepItem] = []
        var autoNumber = 1

        for block in blocks {
            switch block {
            case .stepList(let steps):
                result.append(contentsOf: steps)
                autoNumber = max(autoNumber, (steps.last?.number ?? 0) + 1)
            case .paragraph(let spans) where paragraphFallback && result.isEmpty:
                result.append(StepItem(number: autoNumber, spans: spans))
                autoNumber += 1
            case .subsection(_, let subblocks) where result.isEmpty:
                let nested = collectStepItems(from: subblocks, paragraphFallback: paragraphFallback)
                if !nested.isEmpty {
                    result.append(contentsOf: nested)
                    autoNumber = max(autoNumber, (nested.last?.number ?? 0) + 1)
                }
            default:
                break
            }
        }

        return result
    }

    private static nonisolated func firstParagraph(in blocks: [DocBlock]) -> [InlineSpan]? {
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

    private static nonisolated func collectParagraphSpans(from blocks: [DocBlock]) -> [[InlineSpan]] {
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

    private static nonisolated func unique(_ items: [[InlineSpan]]) -> [[InlineSpan]] {
        var seen = Set<String>()
        return items.filter { spans in
            let key = plainText(spans)
            guard !key.isEmpty, seen.insert(key).inserted else { return false }
            return true
        }
    }

    private static nonisolated func plainText(_ spans: [InlineSpan]) -> String {
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

    private static nonisolated func matchesAny(_ spans: [InlineSpan], keywords: [String]) -> Bool {
        let text = plainText(spans)
        return keywords.contains { text.contains($0) }
    }

    private static nonisolated func defaultPairingSummary(identity: DeviceDocIdentity, hasSteps: Bool) -> [InlineSpan] {
        if hasSteps {
            return [.text("Follow the steps below to pair the \(identity.model) with Zigbee2MQTT.")]
        } else {
            return [.text("Pairing guidance for the \(identity.model) is limited. Review the notes below for device-specific instructions.")]
        }
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

    private static nonisolated func isPairingAdjacentTitle(_ title: String) -> Bool {
        title.contains("troubleshooting")
            || title.contains("factory reset")
            || title.contains("install code")
            || title.contains("touchlink")
            || title.contains("bluetooth")
            || title.contains("power cycling")
            || title.contains("pair")
    }

    private static nonisolated let prerequisiteKeywords = [
        "coordinator", "adapter", "wake", "awake", "close to", "battery", "install code",
        "permit join", "bridge", "factory reset"
    ]
    private static nonisolated let successKeywords = [
        "when connected", "turns off", "flash", "flashes", "blink", "blinks", "pulsate",
        "joined", "success", "light turns", "beep"
    ]
    private static nonisolated let troubleshootingKeywords = [
        "troubleshooting", "issue", "doesn't", "didn't", "retry", "remove the device",
        "join it again", "re-pair", "not work", "work around"
    ]
}
