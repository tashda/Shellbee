import SwiftUI

/// The one entry point to a device's pairing guide on its Documentation page.
struct DocPairingSection: View {
    let pairing: DevicePairingGuide
    let openPairing: () -> Void

    var body: some View {
        Section {
            Button(action: openPairing) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "personalhotspot")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: DesignTokens.Size.docSectionIconFrame)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text("How to pair")
                            .foregroundStyle(.primary)
                        if !pairing.summary.isEmpty {
                            Text(pairing.summary.plainText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// Device options as rows: z2m's label, the first line of the description
/// and the type. Each row pushes to `DocOptionDetailView`.
struct DocOptionsSection: View {
    let options: [DocOption]
    let definition: DeviceDefinition?
    let sourcePath: String?

    var body: some View {
        Section("Options") {
            ForEach(options) { option in
                let label = option.label(in: definition)
                NavigationLink {
                    DocOptionDetailView(option: option, label: label, sourcePath: sourcePath)
                } label: {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                            Text(label)
                            if !option.description.isEmpty {
                                Text(option.description.plainText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let type = option.typeText {
                            Text(type)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

/// Documentation sections as rows that push to a reading page. Sections
/// that warn get the warning triangle.
struct DocNotesSection: View {
    let title: String
    let sections: [DocSection]
    let sourcePath: String?

    var body: some View {
        if !sections.isEmpty {
            Section(title) {
                ForEach(sections) { section in
                    NavigationLink {
                        DocReadingView(title: section.title, blocks: section.blocks, sourcePath: sourcePath)
                    } label: {
                        Label {
                            Text(section.title)
                        } icon: {
                            DocNoteSymbol(isWarning: DocNote.isWarning(section.blocks))
                        }
                    }
                }
            }
        }
    }
}

/// A link to the device's page on zigbee2mqtt.io.
struct DocSourceSection: View {
    let sourcePath: String

    var body: some View {
        if let url = DocLinkResolver.pageURL(for: sourcePath) {
            Section {
                Link(destination: url) {
                    Label("View on zigbee2mqtt.io", systemImage: "safari")
                }
            }
        }
    }
}

extension Array where Element == InlineSpan {
    /// The spans as plain text, keeping their case.
    var plainText: String {
        map { span in
            switch span {
            case .text(let text), .bold(let text), .italic(let text), .boldItalic(let text), .code(let text):
                text
            case .link(let label, _):
                label
            }
        }
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
