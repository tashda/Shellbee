import SwiftUI

/// A device's Documentation page, used by Device detail and the Device
/// Library. Everything is native `List` rows: the identity card, one How to
/// pair row, what the device exposes grouped like its settings, options,
/// notes and a link to zigbee2mqtt.io. On a wide iPad the identity and
/// pairing move to a side column and the rest keeps a readable width.
struct DocumentationExperienceView: View {
    let device: Device
    let documentation: DeviceDocumentation
    var typeLabel: String? = nil
    var openPairing: (() -> Void)?

    @State private var width: CGFloat = 0

    private var normalized: NormalizedDeviceDoc { documentation.normalized }

    private var usesTwoColumns: Bool {
        width >= DesignTokens.Size.docTwoColumnMinimumWidth && hasBodyContent
    }

    private var hasBodyContent: Bool {
        !normalized.capabilities.isEmpty || !normalized.options.isEmpty
            || !normalized.notesSections.isEmpty || !normalized.additionalSections.isEmpty
    }

    var body: some View {
        SwiftUI.Group {
            if usesTwoColumns {
                twoColumns
            } else {
                singleColumn
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private var singleColumn: some View {
        List {
            SwiftUI.Group {
                headerSection
                pairingSection
                bodySections
                DocSourceSection(sourcePath: documentation.sourcePath)
            }
            .shellbeeThemedRows()
        }
        .listStyle(.insetGrouped)
        .readableListMargins(width: width)
        .shellbeeThemedCanvas()
    }

    private var twoColumns: some View {
        HStack(alignment: .top, spacing: 0) {
            List {
                SwiftUI.Group {
                    bodySections
                }
                .shellbeeThemedRows()
            }
            .listStyle(.insetGrouped)
            .readableListMargins(width: width - DesignTokens.Size.docSideColumnWidth)
            .shellbeeThemedCanvas()

            List {
                SwiftUI.Group {
                    headerSection
                    pairingSection
                    DocSourceSection(sourcePath: documentation.sourcePath)
                }
                .shellbeeThemedRows()
            }
            .listStyle(.insetGrouped)
            .frame(width: DesignTokens.Size.docSideColumnWidth)
            .shellbeeThemedCanvas()
        }
    }

    private var headerSection: some View {
        Section {
            DocIdentityHeader(
                device: device,
                identity: normalized.identity,
                typeLabel: typeLabel,
                exposeCount: normalized.capabilities.count
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var pairingSection: some View {
        if let pairing = normalized.pairing, let openPairing {
            DocPairingSection(pairing: pairing, openPairing: openPairing)
        }
    }

    @ViewBuilder
    private var bodySections: some View {
        DocCapabilitySections(capabilities: normalized.capabilities)
        if !normalized.options.isEmpty {
            DocOptionsSection(
                options: normalized.options,
                definition: device.definition,
                sourcePath: documentation.sourcePath
            )
        }
        DocNotesSection(title: "Notes", sections: normalized.notesSections, sourcePath: documentation.sourcePath)
        DocNotesSection(title: "More", sections: normalized.additionalSections, sourcePath: documentation.sourcePath)
    }
}

private extension View {
    /// Keeps list content to a readable width once the column is wider than
    /// that, like Settings on a large iPad.
    @ViewBuilder
    func readableListMargins(width: CGFloat) -> some View {
        let margin = (width - DesignTokens.Size.readableContentMaxWidth) / 2
        if margin > DesignTokens.Spacing.xl {
            contentMargins(.horizontal, margin, for: .scrollContent)
        } else {
            self
        }
    }
}

#Preview {
    NavigationStack {
        DocumentationExperienceView(
            device: .preview,
            documentation: DeviceDocumentation(
                sourcePath: "devices/preview.md",
                parsed: ParsedDeviceDoc(sections: []),
                normalized: DeviceDocNormalizer.normalize(
                    parsed: ParsedDeviceDoc(sections: [
                        DocSection(title: "Notes", level: 2, blocks: [
                            .subsection(title: "Pairing", blocks: [
                                .paragraph([.text("Press the pairing button 4 times in a row.")]),
                                .note([.text("Keep the device close to the coordinator.")])
                            ])
                        ])
                    ]),
                    device: .preview
                )
            ),
            openPairing: {}
        )
    }
}
