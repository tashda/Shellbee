import SwiftUI

struct DocumentationExperienceView: View {
    let device: Device
    let documentation: DeviceDocumentation
    var openPairing: (() -> Void)?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            DocumentationHeroCard(identity: documentation.normalized.identity, device: device)

            DocumentationGroupCard(title: "At a Glance", systemImage: "sparkles.rectangle.stack") {
                DocumentationAtGlanceView(identity: documentation.normalized.identity)
            }

            if let pairing = documentation.normalized.pairing {
                DocumentationGroupCard(title: "Pairing Summary", systemImage: "link.badge.plus") {
                    PairingSummaryCard(pairing: pairing, sourcePath: documentation.sourcePath, openPairing: openPairing)
                }
            }

            if !documentation.normalized.capabilities.isEmpty {
                DocumentationGroupCard(title: "Capabilities", systemImage: "slider.horizontal.below.rectangle") {
                    CapabilityGridView(capabilities: documentation.normalized.capabilities)
                }
            }

            if !documentation.normalized.options.isEmpty {
                DocumentationGroupCard(title: "Device Options", systemImage: "slider.horizontal.3") {
                    DeviceOptionsListView(options: documentation.normalized.options, sourcePath: documentation.sourcePath)
                }
            }

            if !documentation.normalized.notesSections.isEmpty {
                DocumentationSectionCollection(title: "Notes & Quirks", sections: documentation.normalized.notesSections, sourcePath: documentation.sourcePath)
            }

            if !documentation.normalized.advancedSections.isEmpty {
                DocumentationSectionCollection(title: "Advanced", sections: documentation.normalized.advancedSections, sourcePath: documentation.sourcePath)
            }

            if !documentation.normalized.miscSections.isEmpty {
                DocumentationSectionCollection(title: "Additional Information", sections: documentation.normalized.miscSections, sourcePath: documentation.sourcePath)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }
}

private struct DocumentationHeroCard: View {
    let identity: DeviceDocIdentity
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
                heroImage

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(identity.vendor.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(identity.model)
                        .font(.title2.weight(.bold))

                    if !identity.description.isEmpty {
                        Text(identity.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: DesignTokens.Spacing.md)
            }

            HStack(spacing: DesignTokens.Spacing.sm) {
                HeroChip(label: identity.supportsOTA ? "OTA Supported" : "OTA Not Supported", tint: identity.supportsOTA ? .blue : .secondary)
                HeroChip(label: device.type.chipLabel, tint: device.type.chipTint)
                if let powerSource = device.powerSource, !powerSource.isEmpty {
                    HeroChip(label: powerSource, tint: .orange)
                }
            }

            if let exposesSummary = identity.exposesSummary, !exposesSummary.isEmpty {
                Text(exposesSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.18),
                    Color.blue.opacity(0.08),
                    Color(.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous)
        )
    }

    private var heroImage: some View {
        DeviceImageView(device: device, isAvailable: true, size: DesignTokens.Size.deviceActionSheetImage * 1.4)
            .frame(width: DesignTokens.Size.deviceActionSheetImage * 1.5, height: DesignTokens.Size.deviceActionSheetImage * 1.5)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
    }
}

private struct HeroChip: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Size.compactChipVerticalPadding)
            .background(tint.opacity(DesignTokens.Opacity.chipFill), in: Capsule())
            .foregroundStyle(tint)
    }
}

private struct DocumentationAtGlanceView: View {
    let identity: DeviceDocIdentity

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            AtGlanceRow(label: "Vendor", value: identity.vendor)
            AtGlanceRow(label: "Model", value: identity.model)
            if !identity.description.isEmpty {
                AtGlanceRow(label: "Description", value: identity.description)
            }
            AtGlanceRow(label: "OTA Updates", value: identity.supportsOTA ? "Supported" : "Not supported")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AtGlanceRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PairingSummaryCard: View {
    let pairing: DevicePairingGuide
    let sourcePath: String
    var openPairing: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            DocumentationInlineTextView(spans: pairing.summary, sourcePath: sourcePath)
                .font(.body)

            if !pairing.prerequisites.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Before you start")
                        .font(.headline)
                    ForEach(Array(pairing.prerequisites.enumerated()), id: \.offset) { _, spans in
                        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                            DocumentationInlineTextView(spans: spans, sourcePath: sourcePath)
                                .font(.subheadline)
                        }
                    }
                }
            }

            if !pairing.primarySteps.isEmpty {
                DocumentationStepListView(steps: Array(pairing.primarySteps.prefix(3)), sourcePath: sourcePath)
            }

            if let openPairing {
                Button(action: openPairing) {
                    Label("Open Pairing Guide", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CapabilityGridView: View {
    let capabilities: [DeviceDocCapability]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ForEach(capabilities) { capability in
                CapabilityCard(capability: capability)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CapabilityCard: View {
    let capability: DeviceDocCapability

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(capability.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle = capability.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: DesignTokens.Spacing.md)
                CapabilityKindBadge(kind: capability.kind)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(capability.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            CapabilityMetaRow(capability: capability)

            if !capability.detailChips.isEmpty {
                FlowChipWrap(items: capability.detailChips)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
    }
}

private struct CapabilityKindBadge: View {
    let kind: String

    var body: some View {
        Text(kind.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Size.compactChipVerticalPadding)
            .background(Color.accentColor.opacity(DesignTokens.Opacity.chipFill), in: Capsule())
            .fixedSize()
    }
}

private struct CapabilityMetaRow: View {
    let capability: DeviceDocCapability

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                metaChips
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                metaChips
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var metaChips: some View {
        AccessChip(label: capability.isReadable ? "Read" : "State only", tint: capability.isReadable ? .green : .secondary)
        AccessChip(label: capability.isWritable ? "Write" : "No Write", tint: capability.isWritable ? .blue : .secondary)
        if let unit = capability.unit, !unit.isEmpty {
            NeutralChip(label: unit)
        }
    }
}

private struct AccessChip: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Size.compactChipVerticalPadding)
            .foregroundStyle(tint)
            .background(tint.opacity(DesignTokens.Opacity.chipFill), in: Capsule())
    }
}

private struct NeutralChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Size.compactChipVerticalPadding)
            .background(Color(.quaternarySystemFill), in: Capsule())
    }
}

private struct FlowChipWrap: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(items, id: \.self) { item in
                    chip(item)
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ForEach(items, id: \.self) { item in
                    chip(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(_ item: String) -> some View {
        Text(item)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Size.compactChipVerticalPadding)
            .background(Color(.quaternarySystemFill), in: Capsule())
    }
}

private struct DeviceOptionsListView: View {
    let options: [DocOption]
    let sourcePath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(options) { option in
                DocumentationOptionRowView(option: option, sourcePath: sourcePath)
                    .padding(.vertical, DesignTokens.Spacing.md)
                if option.id != options.last?.id {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DocumentationSectionCollection: View {
    let title: String
    let sections: [DocSection]
    let sourcePath: String

    var body: some View {
        DocumentationGroupCard(title: title, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                ForEach(sections) { section in
                    DocumentationFallbackSectionView(section: section, sourcePath: sourcePath)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var systemImage: String {
        switch title {
        case "Notes & Quirks": return "exclamationmark.bubble"
        case "Advanced": return "wrench.and.screwdriver"
        default: return "ellipsis.rectangle"
        }
    }
}

private struct DocumentationFallbackSectionView: View {
    let section: DocSection
    let sourcePath: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(section.title)
                .font(.headline)

            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                DocumentationBlockView(block: block, sourcePath: sourcePath)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DocumentationBlockView: View {
    let block: DocBlock
    let sourcePath: String

    var body: some View {
        switch block {
        case .paragraph(let spans):
            DocumentationInlineTextView(spans: spans, sourcePath: sourcePath)
                .font(.body)
        case .stepList(let steps):
            DocumentationStepListView(steps: steps, sourcePath: sourcePath)
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, spans in
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                        Text("•")
                        DocumentationInlineTextView(spans: spans, sourcePath: sourcePath)
                            .font(.body)
                    }
                }
            }
        case .note(let spans):
            DocumentationCalloutView(spans: spans, sourcePath: sourcePath, tint: .blue)
        case .codeBlock(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.md)
            }
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
        case .table(let table):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack {
                    ForEach(table.headers, id: \.self) { header in
                        Text(header)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        case .optionsList(let options):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                ForEach(options) { option in
                    DocumentationOptionRowView(option: option, sourcePath: sourcePath)
                }
            }
        case .subsection(let title, let blocks):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    DocumentationBlockView(block: block, sourcePath: sourcePath)
                }
            }
        }
    }
}

private struct DocumentationOptionRowView: View {
    let option: DocOption
    let sourcePath: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(option.name)
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Size.docOptionPaddingV)
                    .background(Color(.quaternarySystemFill), in: Capsule())

                if let type = option.type {
                    Text(type)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Size.docOptionPaddingV)
                        .foregroundStyle(.secondary)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }

            if !option.description.isEmpty {
                DocumentationInlineTextView(spans: option.description, sourcePath: sourcePath)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DocumentationCalloutView: View {
    let spans: [InlineSpan]
    let sourcePath: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.noteBar)
                .fill(tint)
                .frame(width: DesignTokens.Size.docNoteBarWidth)
            DocumentationInlineTextView(spans: spans, sourcePath: sourcePath)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
    }
}

private struct DocumentationInlineTextView: View {
    let spans: [InlineSpan]
    let sourcePath: String

    var body: some View {
        DocInlineTextView(spans: spans, sourcePath: sourcePath)
    }
}

private struct DocumentationStepListView: View {
    let steps: [StepItem]
    let sourcePath: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: DesignTokens.Size.docStepCircle, height: DesignTokens.Size.docStepCircle)
                        Text("\(step.number)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    DocumentationInlineTextView(spans: step.spans, sourcePath: sourcePath)
                        .font(.body)
                        .padding(.top, DesignTokens.Spacing.xs)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DocumentationGroupCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.bold))
            content()
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
    }
}

#Preview {
    ScrollView {
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
            )
        )
    }
    .background(Color(.systemGroupedBackground))
}
