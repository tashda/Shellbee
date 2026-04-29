import Foundation

extension DeviceDocNormalizer {
    static nonisolated func extractFromNotes(_ section: DocSection) -> (pairingBlocks: [DocBlock], pairingRelatedBlocks: [DocBlock], noteBlocks: [DocBlock]) {
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

    static nonisolated func makePairingGuide(
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

    private static nonisolated func defaultPairingSummary(identity: DeviceDocIdentity, hasSteps: Bool) -> [InlineSpan] {
        if hasSteps {
            return [.text("Follow the steps below to pair the \(identity.model) with Zigbee2MQTT.")]
        } else {
            return [.text("Pairing guidance for the \(identity.model) is limited. Review the notes below for device-specific instructions.")]
        }
    }

    static nonisolated let prerequisiteKeywords = [
        "coordinator", "adapter", "wake", "awake", "close to", "battery", "install code",
        "permit join", "bridge", "factory reset"
    ]
    static nonisolated let successKeywords = [
        "when connected", "turns off", "flash", "flashes", "blink", "blinks", "pulsate",
        "joined", "success", "light turns", "beep"
    ]
    static nonisolated let troubleshootingKeywords = [
        "troubleshooting", "issue", "doesn't", "didn't", "retry", "remove the device",
        "join it again", "re-pair", "not work", "work around"
    ]
}
