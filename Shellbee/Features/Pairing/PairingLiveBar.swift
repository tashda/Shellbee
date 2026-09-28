import SwiftUI

/// Glass bar at the bottom of the pairing guide. It opens the network on
/// one bridge, counts down while it's open, then follows the device that
/// joins through its interview: Interviewing, Paired or Interview failed.
struct PairingLiveBar: View {
    let bridgeID: UUID
    /// Devices that joined while the guide was open, oldest first.
    let sessionDevices: [Device]
    let onRename: (Device) -> Void

    @Environment(AppEnvironment.self) private var environment

    private var scope: BridgeScope { environment.scope(for: bridgeID) }
    private var info: BridgeInfo? { scope.bridgeInfo }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            content
        }
        .padding(.leading, DesignTokens.Spacing.lg)
        .padding(.trailing, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: DesignTokens.Size.readableContentMaxWidth)
        .glassEffectIfAvailable(in: Capsule())
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.sm)
        .animation(.snappy, value: phase)
    }

    // MARK: - Phase

    private enum Phase: Equatable {
        case closed
        case open
        case interviewing(Device)
        case paired(Device)
        case failed(Device)
    }

    private var phase: Phase {
        if let device = sessionDevices.last {
            if device.interviewState == .failed { return .failed(device) }
            if device.isInterviewing || !device.interviewCompleted { return .interviewing(device) }
            return .paired(device)
        }
        return info?.permitJoin == true ? .open : .closed
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .closed:
            Image(systemName: "personalhotspot")
                .font(.title3)
                .foregroundStyle(.secondary)
            text(title: "Network closed", subtitle: Text("Open it for 4 minutes to pair"))
            Button("Open") { scope.setPermitJoin(enabled: true) }
                .glassProminentButtonStyleIfAvailable()
        case .open:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: DesignTokens.Spacing.md) {
                    countdownRing(at: context.date)
                    text(title: "Waiting for the device", subtitle: closesText(at: context.date), showsBridge: true)
                }
            }
            Button("Close") { scope.setPermitJoin(enabled: false) }
                .glassButtonStyleIfAvailable()
        case .interviewing(let device):
            ProgressView()
                .frame(width: DesignTokens.Size.pairingBarRing)
            text(title: "Interviewing", subtitle: Text(device.cardSubtitle))
        case .paired(let device):
            statusSymbol("checkmark.circle.fill", color: .green)
            text(title: "Paired", subtitle: Text(device.friendlyName))
            Button("Rename") { onRename(device) }
                .glassButtonStyleIfAvailable()
        case .failed:
            statusSymbol("exclamationmark.triangle.fill", color: .orange)
            text(title: "Interview failed", subtitle: Text("Move it closer and try again"))
            Button("Retry") { scope.setPermitJoin(enabled: true) }
                .glassButtonStyleIfAvailable()
        }
    }

    // MARK: - Pieces

    private func text(title: String, subtitle: Text, showsBridge: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: DesignTokens.Spacing.xs) {
                if showsBridge, let name = environment.attributionBridgeName(for: bridgeID) {
                    BridgeMonogram(bridgeID: bridgeID, bridgeName: name)
                }
                subtitle
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func statusSymbol(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.title2)
            .foregroundStyle(.themedStatus(color))
            .frame(width: DesignTokens.Size.pairingBarRing)
    }

    private func countdownRing(at date: Date) -> some View {
        let remaining = remainingSeconds(at: date) ?? 0
        let total = max(info?.permitJoinTimeout ?? 254, 1)
        return ZStack {
            Circle()
                .stroke(.fill.tertiary, lineWidth: DesignTokens.Size.pairingBarRingStroke)
            Circle()
                .trim(from: 0, to: min(Double(remaining) / Double(total), 1))
                .stroke(.tint, style: StrokeStyle(lineWidth: DesignTokens.Size.pairingBarRingStroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: DesignTokens.Size.pairingBarRing, height: DesignTokens.Size.pairingBarRing)
        .accessibilityHidden(true)
    }

    private func closesText(at date: Date) -> Text {
        guard let remaining = remainingSeconds(at: date) else { return Text("Network open") }
        return Text("Closes in \(remaining / 60):\(String(format: "%02d", remaining % 60))")
    }

    private func remainingSeconds(at date: Date) -> Int? {
        guard let end = info?.permitJoinEnd else { return nil }
        return max((end - Int(date.timeIntervalSince1970 * 1000)) / 1000, 0)
    }
}
