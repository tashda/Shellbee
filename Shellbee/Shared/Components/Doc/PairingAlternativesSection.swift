import SwiftUI

/// "Other ways to pair" as navigation rows. Touchlink opens the in-app
/// Touchlink guide and the Philips Hue serial reset opens its sheet; any
/// other method pushes its steps as a reading page.
struct PairingAlternativesSection: View {
    let methods: [DevicePairingMethod]
    let sourcePath: String?
    let bridgeID: UUID?

    var body: some View {
        Section("Other ways to pair") {
            ForEach(methods) { method in
                if method.isTouchlinkReset {
                    NavigationLink {
                        TouchlinkGuideView(bridgeID: bridgeID)
                    } label: {
                        row(
                            title: "Touchlink factory reset",
                            subtitle: "Hold the device close to the coordinator",
                            systemImage: "wave.3.left"
                        )
                    }
                } else if method.isPhilipsHueSerialReset {
                    PhilipsHueSerialResetRow(bridgeID: bridgeID)
                } else {
                    NavigationLink {
                        DocReadingView(title: method.title, blocks: method.blocks, sourcePath: sourcePath)
                    } label: {
                        row(title: method.title, subtitle: method.summary.plainText, systemImage: "arrow.triangle.branch")
                    }
                }
            }
        }
    }

    private func row(title: String, subtitle: String, systemImage: String) -> some View {
        PairingAlternativeLabel(title: title, subtitle: subtitle, systemImage: systemImage)
    }
}

private struct PairingAlternativeLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .foregroundStyle(.primary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PhilipsHueSerialResetRow: View {
    let bridgeID: UUID?
    @Environment(AppEnvironment.self) private var environment
    @State private var showResetSheet = false

    private var scope: BridgeScope? {
        bridgeID.map { environment.scope(for: $0) } ?? environment.selectedScope
    }

    var body: some View {
        Button { showResetSheet = true } label: {
            HStack {
                PairingAlternativeLabel(
                    title: "Reset by serial number",
                    subtitle: "Uses the serial number printed on each Philips Hue bulb",
                    systemImage: "barcode"
                )
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showResetSheet) {
            PhilipsHueResetSheet(
                extendedPanId: scope?.bridgeInfo?.network?.extendedPanID?.stringValue ?? ""
            ) { panId, serials in
                reset(extendedPanId: panId, serialNumbers: serials)
            }
        }
    }

    private func reset(extendedPanId: String, serialNumbers: [String]) {
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

private extension DevicePairingMethod {
    /// The method's summary, steps and notes as one run of blocks.
    var blocks: [DocBlock] {
        var blocks: [DocBlock] = []
        if !summary.isEmpty { blocks.append(.paragraph(summary)) }
        if !steps.isEmpty { blocks.append(.stepList(steps)) }
        return blocks + notes
    }
}
