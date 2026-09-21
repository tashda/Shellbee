import SwiftUI

/// The result of a finished scan, read from Z2M's response. Routers that
/// did not answer are listed by name, because those are the ones worth
/// checking (powered off, out of range, or overloaded).
struct NetworkMapScanSummaryView: View {
    let summary: NetworkMapScanSummary
    let onDismiss: () -> Void

    private static let listedFailureLimit = 8

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            NetworkMapScanRows {
                NetworkMapScanRow(label: "Devices", value: "\(summary.deviceCount)")
                NetworkMapScanRow(
                    label: "Routers Responded",
                    value: "\(summary.respondedCount) of \(summary.queriedCount)"
                )
                if let duration = summary.duration {
                    NetworkMapScanRow(label: "Scan Time", value: NetworkMapScanLiveView.clock(duration))
                }
            }

            if !summary.failedDeviceNames.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Did Not Respond")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                    NetworkMapScanRows {
                        ForEach(summary.failedDeviceNames.prefix(Self.listedFailureLimit), id: \.self) { name in
                            NetworkMapScanRow(label: name, value: "")
                        }
                        let hidden = summary.failedDeviceNames.count - Self.listedFailureLimit
                        if hidden > 0 {
                            NetworkMapScanRow(label: "Others", value: "\(hidden)")
                        }
                    }
                    Text("Devices behind them still appear, as reported by routers that did respond.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                }

                Button(action: onDismiss) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .glassProminentButtonStyleIfAvailable()
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
