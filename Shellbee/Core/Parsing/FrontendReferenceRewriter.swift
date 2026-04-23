import Foundation

/// Rewrites sections and blocks of Z2M device docs that describe how to do things in
/// the Zigbee2MQTT web frontend, replacing them with Shellbee-native guidance and
/// in-app links (shellbee-doc://) where a matching Shellbee screen exists.
///
/// Runs on ParsedDeviceDoc before DeviceDocNormalizer so normalized groups (Notes,
/// Advanced, Pairing) pick up the rewritten content.
enum FrontendReferenceRewriter {

    // MARK: - Destinations

    private static nonisolated let deviceBindURL = "shellbee-doc://device/bind"
    private static nonisolated let deviceReportingURL = "shellbee-doc://device/reporting"
    private static nonisolated let deviceSettingsURL = "shellbee-doc://device/settings"
    private static nonisolated let deviceInfoURL = "shellbee-doc://device/info"

    // MARK: - Entry point

    static nonisolated func rewrite(_ parsed: ParsedDeviceDoc) -> ParsedDeviceDoc {
        let rewritten = parsed.sections.map(rewriteSection(_:))
        return ParsedDeviceDoc(sections: rewritten)
    }

    // MARK: - Section

    private static nonisolated func rewriteSection(_ section: DocSection) -> DocSection {
        if let wholeSectionReplacement = sectionReplacement(for: section) {
            return DocSection(title: section.title, level: section.level, blocks: wholeSectionReplacement)
        }
        let rewrittenBlocks = section.blocks.map(rewriteBlock(_:))
        return DocSection(title: section.title, level: section.level, blocks: rewrittenBlocks)
    }

    /// When a section is essentially a walkthrough of a Z2M-frontend procedure for a
    /// feature Shellbee has natively, replace the entire body with a single concise
    /// explainer + in-app link.
    private static nonisolated func sectionReplacement(for section: DocSection) -> [DocBlock]? {
        let normalizedTitle = section.title.lowercased()
        let bodyText = aggregatePlainText(section.blocks)

        if normalizedTitle.contains("binding") && mentionsFrontend(bodyText) && bodyText.contains("bind") {
            let spans: [InlineSpan] = [
                .text("In Shellbee, set up bindings from the device menu — tap "),
                .link(label: "Bind", url: deviceBindURL),
                .text(" to choose the source and target for this device.")
            ]
            return [.paragraph(spans)]
        }

        if normalizedTitle.contains("reporting") && mentionsFrontend(bodyText) {
            let spans: [InlineSpan] = [
                .text("In Shellbee, open the device's "),
                .link(label: "Reporting", url: deviceReportingURL),
                .text(" screen to configure attribute reporting intervals.")
            ]
            return [.paragraph(spans)]
        }

        if (normalizedTitle.contains("cluster") || normalizedTitle.contains("exposes tab"))
            && mentionsFrontend(bodyText) {
            let spans: [InlineSpan] = [
                .text("Configuring raw Zigbee clusters is not currently exposed in Shellbee. If you need this, use the Zigbee2MQTT web interface.")
            ]
            return [.paragraph(spans)]
        }

        return nil
    }

    // MARK: - Block

    private static nonisolated func rewriteBlock(_ block: DocBlock) -> DocBlock {
        switch block {
        case .paragraph(let spans):
            return .paragraph(rewriteSpans(spans))
        case .note(let spans):
            return .note(rewriteSpans(spans))
        case .bulletList(let items):
            return .bulletList(items.map(rewriteSpans(_:)))
        case .stepList(let steps):
            let rewrittenSteps = steps.map { StepItem(number: $0.number, spans: rewriteSpans($0.spans)) }
            return .stepList(rewrittenSteps)
        case .subsection(let title, let blocks):
            let innerSection = DocSection(title: title, level: 3, blocks: blocks)
            let rewrittenInner = rewriteSection(innerSection)
            return .subsection(title: title, blocks: rewrittenInner.blocks)
        case .codeBlock, .table, .optionsList:
            return block
        }
    }

    /// Rewrite a single span array (one paragraph, bullet item, or step). If the
    /// plain text matches a known frontend-reference pattern, replace the entire
    /// span array with Shellbee guidance; otherwise leave it untouched.
    private static nonisolated func rewriteSpans(_ spans: [InlineSpan]) -> [InlineSpan] {
        let text = plainText(spans).lowercased()
        guard !text.isEmpty else { return spans }

        if let replacement = matchRule(text: text) {
            return replacement
        }

        // Fallback: if the text mentions the frontend but none of the specific rules
        // matched, swap the word so the user isn't told to use an interface we don't
        // expose. This is a lossy fallback but better than leaving misleading text.
        if mentionsFrontend(text) {
            return swapFrontendWord(spans)
        }

        return spans
    }

    // MARK: - Rule matching

    /// Plain table-driven match: keyword set + disqualifier set + replacement spans.
    /// Order matters — more specific rules come first.
    private static nonisolated func matchRule(text: String) -> [InlineSpan]? {
        // "Bind tab" / "Binding tab" in Z2M frontend
        if text.contains("bind") && !text.contains("unbind") && mentionsFrontendOrTab(text) {
            return [
                .text("In Shellbee, open "),
                .link(label: "Bind", url: deviceBindURL),
                .text(" from this device's menu to configure bindings.")
            ]
        }

        // Reporting tab walkthrough
        if text.contains("reporting") && mentionsFrontendOrTab(text) {
            return [
                .text("In Shellbee, open "),
                .link(label: "Reporting", url: deviceReportingURL),
                .text(" from this device's menu to change reporting intervals.")
            ]
        }

        // "click interview" / "initiate a new interview"
        if text.contains("interview") && mentionsFrontendOrTab(text) {
            return [
                .text("In Shellbee, open "),
                .link(label: "the device's Info screen", url: deviceInfoURL),
                .text(" and tap Interview to re-interview the device.")
            ]
        }

        // "Force remove" via frontend
        if text.contains("force remove") {
            return [
                .text("In Shellbee, open "),
                .link(label: "Device Settings", url: deviceSettingsURL),
                .text(" and use Remove (Force) to force-remove this device.")
            ]
        }

        // "remove the device via the frontend"
        if text.contains("remove the device") && mentionsFrontendOrTab(text) {
            return [
                .text("In Shellbee, open "),
                .link(label: "Device Settings", url: deviceSettingsURL),
                .text(" to remove this device.")
            ]
        }

        // "Settings → Tools → Add install code"
        if text.contains("install code") && mentionsFrontendOrTab(text) {
            return [
                .text("In Shellbee, open "),
                .bold("Settings › Tools › Add install code"),
                .text(" to register an install code before pairing.")
            ]
        }

        // "Settings → Advanced"
        if text.contains("settings") && text.contains("advanced") && mentionsFrontendOrTab(text) {
            return [
                .text("In Shellbee, open "),
                .bold("Settings › Advanced"),
                .text(" to change this.")
            ]
        }

        // "navigate to Settings" (generic frontend navigation)
        if text.contains("navigate to") && text.contains("settings") && mentionsFrontendOrTab(text) {
            return [
                .text("In Shellbee, open "),
                .bold("Settings"),
                .text(" and find the matching option.")
            ]
        }

        // "About tab" (reconfigure button etc.)
        if text.contains("about tab") {
            return [
                .text("In Shellbee, open "),
                .link(label: "the device's Info screen", url: deviceInfoURL),
                .text(" and use Reconfigure to reapply reporting and bindings.")
            ]
        }

        // "Exposes tab" toggle
        if text.contains("exposes tab") {
            return [
                .text("In Shellbee, change this on the device's main screen — the device controls are shown there directly.")
            ]
        }

        // Clusters tab — no Shellbee equivalent
        if text.contains("cluster") && mentionsFrontendOrTab(text) {
            return [
                .text("Raw Zigbee cluster configuration is not currently exposed in Shellbee. Use the Zigbee2MQTT web interface if you need this.")
            ]
        }

        return nil
    }

    // MARK: - Word swap fallback

    private static nonisolated func swapFrontendWord(_ spans: [InlineSpan]) -> [InlineSpan] {
        spans.map { span -> InlineSpan in
            switch span {
            case .text(let s): return .text(replaceFrontendWord(s))
            case .bold(let s): return .bold(replaceFrontendWord(s))
            case .italic(let s): return .italic(replaceFrontendWord(s))
            case .boldItalic(let s): return .boldItalic(replaceFrontendWord(s))
            case .code, .link: return span
            }
        }
    }

    private static nonisolated func replaceFrontendWord(_ s: String) -> String {
        var out = s
        let patterns: [(String, String)] = [
            ("Zigbee2MQTT frontend", "Shellbee"),
            ("zigbee2mqtt frontend", "Shellbee"),
            ("Z2M frontend", "Shellbee"),
            ("Z2M web interface", "Shellbee"),
            ("zigbee2mqtt web interface", "Shellbee"),
            ("web interface", "Shellbee"),
            ("the frontend", "Shellbee"),
            ("frontend", "Shellbee")
        ]
        for (pattern, replacement) in patterns {
            out = out.replacingOccurrences(of: pattern, with: replacement)
        }
        return out
    }

    // MARK: - Helpers

    private static nonisolated func mentionsFrontend(_ text: String) -> Bool {
        let t = text.lowercased()
        return t.contains("frontend")
            || t.contains("web interface")
            || t.contains("web ui")
            || t.contains("zigbee2mqtt ui")
            || t.contains("dashboard")
    }

    /// Looser variant: also matches references to named "XYZ tab" or "click/navigate"
    /// verbs that imply frontend navigation. Used by block-level rules.
    private static nonisolated func mentionsFrontendOrTab(_ text: String) -> Bool {
        if mentionsFrontend(text) { return true }
        let t = text.lowercased()
        return t.contains(" tab")
            || t.contains("click on")
            || t.contains("navigate to")
    }

    private static nonisolated func aggregatePlainText(_ blocks: [DocBlock]) -> String {
        blocks.map { block -> String in
            switch block {
            case .paragraph(let spans), .note(let spans):
                return plainText(spans)
            case .bulletList(let items):
                return items.map(plainText(_:)).joined(separator: " ")
            case .stepList(let steps):
                return steps.map { plainText($0.spans) }.joined(separator: " ")
            case .subsection(_, let inner):
                return aggregatePlainText(inner)
            case .codeBlock(let s):
                return s
            case .table, .optionsList:
                return ""
            }
        }.joined(separator: " ").lowercased()
    }

    private static nonisolated func plainText(_ spans: [InlineSpan]) -> String {
        spans.map { span -> String in
            switch span {
            case .text(let s), .bold(let s), .italic(let s), .boldItalic(let s), .code(let s):
                return s
            case .link(let label, _):
                return label
            }
        }.joined()
    }
}
