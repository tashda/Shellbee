import SwiftUI

/// z2m's Touchlink guide laid out like a Documentation page: what Touchlink
/// is and whether this coordinator supports it, the Philips Hue serial
/// reset, then each part of the guide as a row that opens a reading page.
struct TouchlinkGuideView: View {
    private static let sourcePath = "guide/usage/touchlink.md"

    @Environment(AppEnvironment.self) private var environment

    /// The bridge whose network Touchlink actions run on. `nil` when opened
    /// from documentation without a bridge; actions are hidden then.
    let bridgeID: UUID?

    @State private var guide: ParsedGuideDoc?
    @State private var isLoading = false
    @State private var loadError: DeviceDocError?
    @State private var showHueResetSheet = false

    private var scope: BridgeScope? {
        bridgeID.map { environment.scope(for: $0) }
    }

    var body: some View {
        List {
            SwiftUI.Group {
                if let guide {
                    let pages = TouchlinkGuidePage.pages(from: guide.parsed.sections)
                    Section {
                        header(summary: pages.first?.summary)
                    }
                    if bridgeID != nil {
                        Section {
                            Button {
                                showHueResetSheet = true
                            } label: {
                                Label("Reset by Serial Number", systemImage: "wrench.and.screwdriver")
                            }
                        } footer: {
                            Text("Factory resets Philips Hue devices without scanning, using the 6-character serial printed on the device.")
                        }
                    }
                    Section("Guide") {
                        ForEach(pages) { page in
                            NavigationLink {
                                DocReadingView(title: page.title, blocks: page.blocks, sourcePath: guide.sourcePath)
                            } label: {
                                Label {
                                    Text(page.title)
                                } icon: {
                                    if DocNote.isWarning(page.blocks) {
                                        DocNoteSymbol(isWarning: true)
                                    } else {
                                        Image(systemName: page.systemImage).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    DocSourceSection(sourcePath: guide.sourcePath)
                }
            }
            .shellbeeThemedRows()
        }
        .listStyle(.insetGrouped)
        .shellbeeThemedCanvas()
        .overlay { stateOverlay }
        .navigationTitle("Touchlink Guide")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHueResetSheet) {
            PhilipsHueResetSheet(
                extendedPanId: scope?.bridgeInfo?.network?.extendedPanID?.stringValue ?? ""
            ) { panId, serials in
                philipsHueReset(extendedPanId: panId, serialNumbers: serials)
            }
        }
        .task { await loadGuide() }
    }

    private func header(summary: String?) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ShellbeeSymbol.custom("touchlink").image
                    .font(.title)
                    .foregroundStyle(.tint)
                    .frame(width: DesignTokens.Size.deviceRowImage)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Touchlink")
                        .font(.headline)
                    if let summary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Divider()
            StatStrip(items: stats)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    /// Range and scan time from z2m's guide, and whether this coordinator
    /// can do Touchlink at all.
    private var stats: [StatStripItem] {
        var items = [
            StatStripItem(value: "10 cm–1 m", caption: "Range"),
            StatStripItem(value: "Up to 1 min", caption: "Scan")
        ]
        if let support = TouchlinkSupport(coordinatorType: scope?.bridgeInfo?.coordinator.type) {
            items.append(StatStripItem(value: support.title, caption: "Coordinator",
                                       valueColor: support.needsAttention ? .orange : nil))
        }
        return items
    }

    @ViewBuilder
    private var stateOverlay: some View {
        if isLoading && guide == nil {
            ProgressView("Loading Touchlink guide")
        } else if let loadError, guide == nil {
            ContentUnavailableView(
                "Guide Unavailable",
                systemImage: "wifi.exclamationmark",
                description: Text(loadError.localizedDescription)
            )
        }
    }

    private func philipsHueReset(extendedPanId: String, serialNumbers: [String]) {
        var params: [String: JSONValue] = [
            "serial_numbers": .array(serialNumbers.map { .string($0) })
        ]
        if !extendedPanId.isEmpty {
            params["extended_pan_id"] = .string(extendedPanId)
        }
        scope?.send(
            topic: Z2MTopics.Request.action,
            payload: .object([
                "action": .string("philips_hue_factory_reset"),
                "params": .object(params)
            ])
        )
    }

    private func loadGuide() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let version = scope?.bridgeInfo?.version ?? "master"
            guide = try await GuideDocService.shared.guide(at: Self.sourcePath, z2mVersion: version)
        } catch let error as DeviceDocError {
            loadError = error
        } catch {
            loadError = .networkError(error)
        }
    }
}

/// One reading page of the guide: a top-level section with its
/// subsections folded in, so "Factory reset device" carries "Any device"
/// and "Serial number" rather than each being a row of its own.
struct TouchlinkGuidePage: Identifiable {
    let title: String
    var blocks: [DocBlock]

    var id: String { title }

    /// The first paragraph, for the header.
    var summary: String? {
        for block in blocks {
            if case .paragraph(let spans) = block { return spans.plainText }
        }
        return nil
    }

    /// Rows use a symbol for what the page is about; warnings keep the
    /// triangle.
    var systemImage: String {
        let t = title.lowercased()
        if t.contains("support") { return "checkmark.seal" }
        if t.contains("scan") { return "dot.radiowaves.left.and.right" }
        if t.contains("identify") { return "lightbulb.max" }
        if t.contains("reset") { return "arrow.counterclockwise" }
        return "info.circle"
    }

    /// z2m's intro section (the parser calls it "Overview") becomes "About
    /// Touchlink"; deeper sections fold into the page above them.
    static func pages(from sections: [DocSection]) -> [Self] {
        let top = sections.map(\.level).min() ?? 1
        var pages: [Self] = []
        for section in sections {
            if section.level <= top + 1 || pages.isEmpty {
                let isIntro = pages.isEmpty && (section.level < top + 1 || section.title == "Overview")
                pages.append(Self(title: isIntro ? "About Touchlink" : section.title, blocks: section.blocks))
            } else {
                pages[pages.count - 1].blocks.append(.subsection(title: section.title, blocks: section.blocks))
            }
        }
        return pages.filter { !$0.blocks.isEmpty }
    }
}

/// How well a coordinator does Touchlink, per z2m's guide: Texas
/// Instruments fully, Silicon Labs partly, the rest not at all.
enum TouchlinkSupport {
    case full
    case partial
    case none

    init?(coordinatorType: String?) {
        guard let type = coordinatorType?.lowercased(), !type.isEmpty else { return nil }
        if type.contains("zstack") || type.contains("z-stack") {
            self = .full
        } else if type.contains("ember") || type.contains("ezsp") {
            self = .partial
        } else {
            self = .none
        }
    }

    var title: String {
        switch self {
        case .full: "Supported"
        case .partial: "Partial"
        case .none: "Not supported"
        }
    }

    var needsAttention: Bool { self != .full }
}

#Preview {
    NavigationStack {
        TouchlinkGuideView(bridgeID: nil)
            .environment(AppEnvironment())
    }
    .configuredTopScrollEdgeEffect()
}
