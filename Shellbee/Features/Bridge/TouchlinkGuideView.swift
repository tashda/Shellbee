import SwiftUI

struct TouchlinkGuideView: View {
    private static let sourcePath = "guide/usage/touchlink.md"
    private static let serialNumberSectionTitles: Set<String> = [
        "Serial number",
        "Serial number (Philips Hue only)"
    ]

    @Environment(AppEnvironment.self) private var environment

    /// Phase 4 multi-bridge: bridge whose network the touchlink action runs
    /// against. Touchlink is per-network, not global. Optional only because
    /// the guide can be opened from the docs browser without an active
    /// bridge — in that case actions are no-ops. Callers must pass it
    /// explicitly (no default) to surface the no-bridge case at every site.
    let bridgeID: UUID?

    @State private var guide: ParsedGuideDoc?
    @State private var isLoading = false
    @State private var loadError: DeviceDocError?
    @State private var showHueResetSheet = false

    private var scope: BridgeScope? {
        bridgeID.map { environment.scope(for: $0) }
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.lg)
        }
        .background(Color(.systemGroupedBackground))
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

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: DesignTokens.Spacing.md) {
                ProgressView()
                Text("Loading Touchlink guide")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        } else if let loadError {
            ContentUnavailableView(
                "Guide Unavailable",
                systemImage: "wifi.exclamationmark",
                description: Text(loadError.localizedDescription)
            )
            .frame(maxWidth: .infinity, minHeight: 320)
        } else if let guide {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                touchlinkHero

                ForEach(guide.parsed.sections) { section in
                    TouchlinkGuideSectionCard(title: section.title) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            if Self.serialNumberSectionTitles.contains(section.title) {
                                serialNumberSectionContent
                            } else {
                                ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                                    DocBlockView(block: block, sourcePath: guide.sourcePath)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var touchlinkHero: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Touchlink lets nearby Zigbee devices communicate outside the normal network join flow.")
                .font(.title3.weight(.bold))

            Text("Use it to scan nearby Touchlink-capable devices, identify them, or factory reset them before pairing again. Devices usually need to be very close to the coordinator.")
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: DesignTokens.Spacing.sm) {
                TouchlinkHeroChip(label: "Close Range", tint: .orange)
                TouchlinkHeroChip(label: "Scan Nearby Devices", tint: .teal)
                TouchlinkHeroChip(label: "Philips Hue Reset", tint: .blue)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.teal.opacity(DesignTokens.Opacity.onStateTint),
                    Color.cyan.opacity(DesignTokens.Opacity.lightOpaque),
                    Color(.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous)
        )
    }

    @ViewBuilder
    private var serialNumberSectionContent: some View {
        Text("Most **Philips Hue** devices can be factory reset **without scanning**, by using the serial number printed on the device. _Usually a 6-character code under the barcode on the base or housing._")
            .font(.body)

        Text("Shellbee can send this reset directly — enter one or more serial numbers and Shellbee handles the rest. _Separate multiple codes with commas to reset several devices at once._")
            .font(.body)
            .foregroundStyle(.secondary)

        Button {
            showHueResetSheet = true
        } label: {
            Label("Reset by Serial Number", systemImage: "wrench.and.screwdriver")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.top, DesignTokens.Spacing.xs)
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

private struct TouchlinkHeroChip: View {
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

private struct TouchlinkGuideSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text(title)
                .font(.title3.weight(.bold))
            content()
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        TouchlinkGuideView(bridgeID: nil)
            .environment(AppEnvironment())
    }
}
