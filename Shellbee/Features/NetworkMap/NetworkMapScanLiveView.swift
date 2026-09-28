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
            StatStrip(items: stats)

            if !scan.failedNames.isEmpty {
                Text("No reply from \(scan.failedNames.joined(separator: ", "))")
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

    /// Routers done (or queried, when successes aren't logged), failures,
    /// and time left once the pace is known.
    private var stats: [StatStripItem] {
        var items: [StatStripItem] = []
        if scan.visibility == .everyDevice {
            items.append(StatStripItem(value: "\(scan.finishedCount)/\(scan.targetCount)", caption: "Routers"))
        } else {
            items.append(StatStripItem(value: "\(scan.targetCount)", caption: "Routers"))
        }
        items.append(StatStripItem(value: "\(scan.failedCount)", caption: "No reply",
                                   valueColor: scan.failedCount > 0 ? .red : nil))
        if let remaining = scan.estimatedTimeRemaining(now: now) {
            items.append(StatStripItem(value: Self.approximate(remaining), caption: "Left"))
        } else if scan.scanStartedAt == nil && scan.visibility != .failuresOnly {
            items.append(StatStripItem(value: "Waiting", caption: "Zigbee2MQTT"))
        }
        return items
    }

    private var loggingFootnote: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
            Text("Zigbee2MQTT reports completed routers only with debug logging.")
            Button {
                showsLoggingHelp = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel("How to follow every router")
            .popover(isPresented: $showsLoggingHelp) {
                Text("Failures appear live. To also count each completed router, set Log level to Debug and turn on Log debug to MQTT and frontend in Zigbee2MQTT. That option needs a Zigbee2MQTT restart and may slow the bridge down.")
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
