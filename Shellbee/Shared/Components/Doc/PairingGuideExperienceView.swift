import SwiftUI

struct PairingGuideExperienceView: View {
    let device: Device
    let identity: DeviceDocIdentity
    let pairing: DevicePairingGuide?
    let sourcePath: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                DocHeroCard<EmptyView>(
                    device: device,
                    eyebrow: identity.vendor,
                    title: "Pair \(identity.model)",
                    description: pairing?.summary ?? [.text("Review the available device notes and steps below to pair this device with Zigbee2MQTT.")],
                    sourcePath: sourcePath,
                    gradient: DocHeroCard<EmptyView>.pairingGradient
                )

                if let pairing {
                    if !pairing.prerequisites.isEmpty {
                        PairingGuideSection(title: "Before You Start", systemImage: "checklist") {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                ForEach(Array(pairing.prerequisites.enumerated()), id: \.offset) { _, spans in
                                    HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                        PairingInlineTextView(spans: spans, sourcePath: sourcePath)
                                            .font(.body)
                                    }
                                }
                            }
                        }
                    }

                    if !pairing.primarySteps.isEmpty {
                        PairingGuideSection(title: "Steps", systemImage: "list.number") {
                            PairingStepListView(steps: pairing.primarySteps, sourcePath: sourcePath)
                        }
                    }

                    if !pairing.alternatives.isEmpty {
                        PairingGuideSection(title: "Alternatives", systemImage: "arrow.triangle.branch") {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                ForEach(pairing.alternatives) { method in
                                    AlternativePairingCard(method: method, sourcePath: sourcePath)
                                }
                            }
                        }
                    }

                    if !pairing.successCues.isEmpty {
                        PairingGuideSection(title: "What Success Looks Like", systemImage: "sparkles") {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                ForEach(Array(pairing.successCues.enumerated()), id: \.offset) { _, spans in
                                    PairingCalloutView(spans: spans, sourcePath: sourcePath, tint: .green)
                                }
                            }
                        }
                    }

                    if !pairing.troubleshooting.isEmpty {
                        PairingGuideSection(title: "If It Didn't Work", systemImage: "exclamationmark.triangle") {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                ForEach(Array(pairing.troubleshooting.enumerated()), id: \.offset) { _, spans in
                                    PairingCalloutView(spans: spans, sourcePath: sourcePath, tint: .orange)
                                }
                            }
                        }
                    }

                    if !pairing.additionalNotes.isEmpty {
                        PairingGuideSection(title: "Additional Notes", systemImage: "text.alignleft") {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                ForEach(Array(pairing.additionalNotes.enumerated()), id: \.offset) { _, block in
                                    PairingBlockView(block: block, sourcePath: sourcePath)
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Pairing Guide",
                        systemImage: "personalhotspot.slash",
                        description: Text("Pairing instructions aren't documented for \(identity.model).")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, DesignTokens.Spacing.xxl)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.lg)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct PairingGuideSection<Content: View>: View {
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

private struct AlternativePairingCard: View {
    let method: DevicePairingMethod
    let sourcePath: String?

    var body: some View {
        if method.isTouchlinkReset {
            TouchlinkResetCard()
        } else if method.isPhilipsHueSerialReset {
            PhilipsHueSerialResetCard()
        } else {
            GenericAlternativeCard(method: method, sourcePath: sourcePath)
        }
    }
}

private struct PhilipsHueSerialResetCard: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showResetSheet = false

    /// Phase 1 multi-bridge: docs are not bridge-attributed today, so the
    /// reset action targets the user's selected bridge. Phase 2 may thread
    /// an explicit bridge id through the docs browser.
    private var scope: BridgeScope? { environment.selectedScope }
    private var store: AppStore? { scope?.store }

    var body: some View {
        Button { showResetSheet = true } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "light.cylindrical.ceiling.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Philips Hue Reset by Serial Numbers")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Reset Philips Hue bulbs using the serial numbers printed on each bulb — no close-range scan needed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.lg)
        .background(Color.blue.opacity(DesignTokens.Opacity.hairline), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
                .strokeBorder(Color.blue.opacity(DesignTokens.Opacity.accentFill))
        )
        .sheet(isPresented: $showResetSheet) {
            PhilipsHueResetSheet(
                extendedPanId: store?.bridgeInfo?.network?.extendedPanID?.stringValue ?? ""
            ) { panId, serials in
                philipsHueReset(extendedPanId: panId, serialNumbers: serials)
            }
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
}

private struct TouchlinkResetCard: View {
    var body: some View {
        NavigationLink(destination: TouchlinkGuideView(bridgeID: nil)) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "wave.3.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Touchlink Factory Reset")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Hold the device close to the coordinator and use the in-app Touchlink guide.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.lg)
        .background(Color.teal.opacity(DesignTokens.Opacity.hairline), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
                .strokeBorder(Color.teal.opacity(DesignTokens.Opacity.accentFill))
        )
    }
}

private struct GenericAlternativeCard: View {
    let method: DevicePairingMethod
    let sourcePath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(method.title)
                .font(.headline)
            if !method.summary.isEmpty {
                PairingInlineTextView(spans: method.summary, sourcePath: sourcePath)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !method.steps.isEmpty {
                PairingStepListView(steps: method.steps, sourcePath: sourcePath)
            }
            if !method.notes.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    ForEach(Array(method.notes.enumerated()), id: \.offset) { _, block in
                        PairingBlockView(block: block, sourcePath: sourcePath)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
    }
}

private struct PairingInlineTextView: View {
    let spans: [InlineSpan]
    let sourcePath: String?

    var body: some View {
        DocInlineTextView(spans: spans, sourcePath: sourcePath)
    }
}

private struct PairingStepListView: View {
    let steps: [StepItem]
    let sourcePath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: DesignTokens.Size.docStepCircle, height: DesignTokens.Size.docStepCircle)
                        Text("\(step.number)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    PairingInlineTextView(spans: step.spans, sourcePath: sourcePath)
                        .font(.body)
                        .padding(.top, DesignTokens.Spacing.xs)
                }
            }
        }
    }
}

private struct PairingCalloutView: View {
    let spans: [InlineSpan]
    let sourcePath: String?
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.noteBar)
                .fill(tint)
                .frame(width: DesignTokens.Size.docNoteBarWidth)
            PairingInlineTextView(spans: spans, sourcePath: sourcePath)
                .font(.subheadline)
        }
        .padding(DesignTokens.Spacing.md)
        .background(tint.opacity(DesignTokens.Opacity.hairline), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
    }
}

private struct PairingBlockView: View {
    let block: DocBlock
    let sourcePath: String?

    var body: some View {
        switch block {
        case .paragraph(let spans):
            PairingInlineTextView(spans: spans, sourcePath: sourcePath)
                .font(.body)
        case .stepList(let steps):
            PairingStepListView(steps: steps, sourcePath: sourcePath)
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, spans in
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                        Text("•")
                        PairingInlineTextView(spans: spans, sourcePath: sourcePath)
                    }
                }
            }
        case .note(let spans):
            PairingCalloutView(spans: spans, sourcePath: sourcePath, tint: .blue)
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
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ForEach(options) { option in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(option.name)
                            .font(.system(.subheadline, design: .monospaced).weight(.medium))
                        PairingInlineTextView(spans: option.description, sourcePath: sourcePath)
                            .font(.caption)
                    }
                }
            }
        case .subsection(let title, let blocks):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(.headline)
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    PairingBlockView(block: block, sourcePath: sourcePath)
                }
            }
        }
    }
}
