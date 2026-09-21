import SwiftUI

/// The running-scan part of the refresh card. Every number here comes from
/// the bridge's own log lines (see `NetworkMapScanProgress`); when the
/// bridge's logging hides per-router results, the card says so instead of
/// inventing progress.
struct NetworkMapScanLiveView: View {
    let scan: NetworkMapScanProgress
    let now: Date

    @State private var showsLoggingHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if let fraction = scan.fractionComplete {
                ProgressView(value: fraction)
                    .tint(.accentColor)
            }

            Text(statusLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())

            NetworkMapScanRows {
                if scan.visibility == .everyDevice {
                    NetworkMapScanRow(label: "Responded", value: "\(scan.respondedCount)")
                } else {
                    NetworkMapScanRow(label: "Routers", value: "\(scan.targetCount)")
                }
                NetworkMapScanRow(
                    label: "Failed",
                    value: "\(scan.failedCount)",
                    valueColor: scan.failedCount > 0 ? .red : .secondary
                )
                if scan.visibility == .everyDevice {
                    NetworkMapScanRow(label: "Waiting", value: "\(scan.waitingCount)")
                }
            }

            if !scan.failedNames.isEmpty {
                Text(scan.failedNames.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if scan.visibility != .everyDevice {
                loggingFootnote
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth, value: scan)
    }

    private var statusLine: String {
        let elapsed = Self.clock(now.timeIntervalSince(scan.requestedAt))
        if scan.scanFinishedAt != nil {
            return "Scan finished · \(elapsed)"
        }
        guard scan.scanStartedAt != nil || scan.visibility == .failuresOnly else {
            return "Waiting for Zigbee2MQTT · \(elapsed)"
        }
        if scan.visibility == .everyDevice {
            var line = "\(scan.finishedCount) of \(scan.targetCount) routers · \(elapsed)"
            if let remaining = scan.estimatedTimeRemaining(now: now) {
                line += " · about \(Self.approximate(remaining)) left"
            }
            return line
        }
        return "Scanning routers · \(elapsed)"
    }

    private var loggingFootnote: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
            Text("Only failed routers are reported at this log level.")
            Button {
                showsLoggingHelp = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel("How to follow every router")
            .popover(isPresented: $showsLoggingHelp) {
                Text("To follow every router during a scan, set Log level to Debug and turn on Log debug to MQTT and frontend in the Zigbee2MQTT settings.")
                    .font(.subheadline)
                    .padding()
                    .frame(idealWidth: DesignTokens.Size.networkMapScanCardWidth)
                    .fixedSize(horizontal: false, vertical: true)
                    .presentationCompactAdaptation(.popover)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    // MARK: - Formatting

    static func clock(_ interval: TimeInterval) -> String {
        let seconds = max(Int(interval), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func approximate(_ interval: TimeInterval) -> String {
        let seconds = max(Int(interval.rounded()), 1)
        if seconds < 60 { return "\(seconds) s" }
        let minutes = Int((Double(seconds) / 60).rounded())
        return minutes == 1 ? "1 min" : "\(minutes) min"
    }
}
