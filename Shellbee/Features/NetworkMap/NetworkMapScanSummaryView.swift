import SwiftUI

/// The result of a finished scan, read from Z2M's response. Routers that
/// did not answer are listed by name, because those are the ones worth
/// checking (powered off, out of range, or overloaded).
struct NetworkMapScanSummaryView: View {
    let summary: NetworkMapScanSummary
    let onDismiss: () -> Void

    private static let listedFailureLimit = 8

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                NetworkMapScanStatTile(
                    value: "\(summary.deviceCount)",
                    label: "Devices",
                    systemImage: "sensor.tag.radiowaves.forward.fill",
                    tint: .accentColor
                )
                NetworkMapScanStatTile(
                    value: "\(summary.respondedCount)/\(summary.queriedCount)",
                    label: "Routers Responded",
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                )
                NetworkMapScanStatTile(
                    value: "\(summary.failedDeviceNames.count)",
                    label: "Failed",
                    systemImage: "xmark.circle.fill",
                    tint: summary.failedDeviceNames.isEmpty ? .secondary : .red
                )
            }

            if !summary.failedDeviceNames.isEmpty {
                failures
            }

            if let duration = summary.duration {
                Text("Scanned in \(NetworkMapScanLiveView.clock(duration)) · \(summary.linkCount) links")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !summary.failedDeviceNames.isEmpty {
                Button("Done", action: onDismiss)
                    .glassProminentButtonStyleIfAvailable()
                    .controlSize(.large)
            }
        }
    }

    private var failures: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Did Not Respond")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(summary.failedDeviceNames.prefix(Self.listedFailureLimit), id: \.self) { name in
                Label {
                    Text(name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .font(.subheadline)
            }
            let hidden = summary.failedDeviceNames.count - Self.listedFailureLimit
            if hidden > 0 {
                Text("and \(hidden) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Their neighbors are still on the map, as reported by the routers that did respond.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, DesignTokens.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.md)
        .background(
            Color.red.opacity(DesignTokens.Opacity.networkMapScanTileFill),
            in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
        )
    }
}
