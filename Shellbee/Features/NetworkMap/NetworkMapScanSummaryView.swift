import SwiftUI

/// The result of a finished scan, read from Z2M's response. Routers that
/// did not answer are listed by name, because those are the ones worth
/// checking (powered off, out of range, or overloaded).
struct NetworkMapScanSummaryView: View {
    let summary: NetworkMapScanSummary
    let onDismiss: () -> Void

    private static let listedFailureLimit = 6

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            StatStrip(items: stats)

            if !summary.failedDeviceNames.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Didn't respond")
                        .font(.subheadline.weight(.semibold))
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(summary.failedDeviceNames.prefix(Self.listedFailureLimit), id: \.self) { name in
                            Label(name, systemImage: "wifi.exclamationmark")
                                .font(.subheadline)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                            Divider()
                        }
                        let hidden = summary.failedDeviceNames.count - Self.listedFailureLimit
                        if hidden > 0 {
                            Text("and \(hidden) more")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                        }
                    }
                    Text("Devices behind them still appear, as reported by routers that did respond.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onDismiss) {
                    Text("Done").frame(maxWidth: .infinity)
                }
                .glassProminentButtonStyleIfAvailable()
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stats: [StatStripItem] {
        var items = [
            StatStripItem(value: "\(summary.deviceCount)", caption: "Devices"),
            StatStripItem(value: "\(summary.respondedCount)/\(summary.queriedCount)", caption: "Routers",
                          valueColor: summary.failedDeviceNames.isEmpty ? nil : .orange)
        ]
        if let duration = summary.duration {
            items.append(StatStripItem(value: NetworkMapScanLiveView.clock(duration), caption: "Scan time"))
        }
        return items
    }
}
