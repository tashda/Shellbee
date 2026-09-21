import SwiftUI

/// The running-scan part of the refresh card. Every number here comes from
/// the bridge's own log lines (see `NetworkMapScanProgress`); when the
/// bridge's logging hides per-router results, the card says so instead of
/// inventing progress.
struct NetworkMapScanLiveView: View {
    let scan: NetworkMapScanProgress
    let now: Date

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if scan.visibility == .everyDevice {
                progressBar
            }
            tiles
            if !scan.recentEvents.isEmpty {
                feed
            }
            timing
            if scan.visibility != .everyDevice {
                loggingNote
            }
        }
        .animation(.smooth, value: scan)
    }

    // MARK: - Progress

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            GeometryReader { proxy in
                let total = max(scan.targetCount, 1)
                let respondedWidth = proxy.size.width * CGFloat(scan.respondedCount) / CGFloat(total)
                let failedWidth = proxy.size.width * CGFloat(scan.failedCount) / CGFloat(total)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.16))
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.green).frame(width: respondedWidth)
                        Rectangle().fill(Color.red).frame(width: failedWidth)
                    }
                    .clipShape(Capsule())
                }
            }
            .frame(height: DesignTokens.Size.networkMapScanBarHeight)
            Text("\(scan.finishedCount) of \(scan.targetCount) routers scanned")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Tiles

    @ViewBuilder
    private var tiles: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if scan.visibility == .everyDevice {
                NetworkMapScanStatTile(
                    value: "\(scan.respondedCount)",
                    label: "Responded",
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                )
            } else {
                NetworkMapScanStatTile(
                    value: "\(scan.targetCount)",
                    label: "Routers to Scan",
                    systemImage: "dot.radiowaves.left.and.right",
                    tint: .accentColor
                )
            }
            NetworkMapScanStatTile(
                value: "\(scan.failedCount)",
                label: "Failed",
                systemImage: "xmark.circle.fill",
                tint: scan.failedCount > 0 ? .red : .secondary
            )
            if scan.visibility == .everyDevice {
                NetworkMapScanStatTile(
                    value: "\(scan.waitingCount)",
                    label: "Waiting",
                    systemImage: "clock.fill",
                    tint: .secondary
                )
            } else {
                NetworkMapScanStatTile(
                    value: Self.clock(now.timeIntervalSince(scan.requestedAt)),
                    label: "Elapsed",
                    systemImage: "clock.fill",
                    tint: .secondary
                )
            }
        }
    }

    // MARK: - Feed

    private var feed: some View {
        VStack(spacing: 0) {
            ForEach(scan.recentEvents) { event in
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: event.outcome == .responded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(event.outcome == .responded ? .green : .red)
                    Text(event.deviceName)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: DesignTokens.Spacing.sm)
                    Text(event.outcome == .responded ? "Responded" : "Failed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            Color.secondary.opacity(DesignTokens.Opacity.networkMapScanTileFill),
            in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
    }

    // MARK: - Timing

    private var timing: some View {
        HStack {
            if scan.visibility == .everyDevice {
                Label(Self.clock(now.timeIntervalSince(scan.requestedAt)), systemImage: "stopwatch")
            }
            Spacer()
            if let remaining = scan.estimatedTimeRemaining(now: now) {
                Text("About \(Self.approximate(remaining)) left")
            } else if scan.visibility != .everyDevice {
                // Z2M pauses a second per router, so this is a floor, not a guess.
                Text("Takes at least \(Self.approximate(Double(scan.targetCount))) for \(scan.targetCount) routers")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }

    private var loggingNote: some View {
        Label {
            Text(scan.visibility == .failuresOnly
                 ? "Zigbee2MQTT only reports failed routers at this log level. To follow every router, set Log level to Debug and turn on Log debug to MQTT and frontend."
                 : "Zigbee2MQTT only reports failed routers while scanning. To follow every router, set Log level to Debug and turn on Log debug to MQTT and frontend.")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
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
