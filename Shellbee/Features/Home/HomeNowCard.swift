import SwiftUI

/// What is happening this second: a firmware flash in flight, permit join
/// counting down, a device being interviewed.
///
/// The card exists only while one of those is true and removes itself when it
/// finishes, so it is pinned above the rest of Home rather than sitting in a
/// slot the user arranged. One summary row per activity — never a row per
/// device — so a forty-device flash session doesn't turn Home into a progress
/// list. It is the same story the Live Activity tells on the Lock Screen.
struct HomeNowCard: View {
    let otaStatuses: [String: OTAUpdateStatus]
    let permitJoinEnd: Date?
    let permitJoinTotal: Int?
    let interviewingCount: Int
    let onOpenUpdates: () -> Void
    let onStopPermitJoin: () -> Void
    let onOpenInterviewing: () -> Void

    static func hasContent(
        otaStatuses: [String: OTAUpdateStatus],
        permitJoinEnd: Date?,
        interviewingCount: Int
    ) -> Bool {
        otaStatuses.values.contains(where: \.isActive)
            || (permitJoinEnd.map { $0 > Date() } ?? false)
            || interviewingCount > 0
    }

    private var activeUpdates: [OTAUpdateStatus] {
        otaStatuses.values
            .filter(\.isActive)
            .sorted { ($0.sortPriority, $0.deviceName) < ($1.sortPriority, $1.deviceName) }
    }

    var body: some View {
        HomeCardContainer(padding: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 0) {
                if !activeUpdates.isEmpty {
                    updatesRow
                }
                if permitJoinEnd != nil {
                    if !activeUpdates.isEmpty { Divider().padding(.vertical, DesignTokens.Spacing.xs) }
                    permitJoinRow
                }
                if interviewingCount > 0 {
                    if !activeUpdates.isEmpty || permitJoinEnd != nil {
                        Divider().padding(.vertical, DesignTokens.Spacing.xs)
                    }
                    interviewingRow
                }
            }
        }
        .transition(.push(from: .top).combined(with: .opacity))
    }

    // MARK: - Updating

    private var updatesRow: some View {
        Button(action: onOpenUpdates) {
            HomeNowRow(
                progress: aggregateProgress,
                tint: .green,
                symbol: "arrow.up.circle.fill",
                title: updatesTitle,
                detail: updatesDetail
            ) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(HomeCardButtonStyle())
    }

    private var flashing: [OTAUpdateStatus] { activeUpdates.filter { $0.phase == .updating } }

    private var aggregateProgress: Double? {
        let values = flashing.compactMap(\.progress)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count) / 100
    }

    private var updatesTitle: String {
        let count = activeUpdates.count
        return "Updating \(count) device\(count == 1 ? "" : "s")"
    }

    private var updatesDetail: String {
        var parts: [String] = []
        if let first = flashing.first { parts.append(first.deviceName) }
        let queued = activeUpdates.count - flashing.count
        if queued > 0 { parts.append("\(queued) queued") }
        if let remaining = flashing.compactMap(\.remaining).max(), remaining > 0 {
            parts.append("~\(max(remaining / 60, 1)) min")
        }
        return parts.isEmpty ? "Starting" : parts.joined(separator: " · ")
    }

    // MARK: - Permit join

    @ViewBuilder
    private var permitJoinRow: some View {
        if let end = permitJoinEnd {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(Int(end.timeIntervalSince(context.date)), 0)
                HomeNowRow(
                    progress: permitJoinTotal.map { Double(remaining) / Double(max($0, 1)) },
                    tint: .orange,
                    symbol: "person.crop.circle.badge.plus",
                    title: "Permit join is open",
                    detail: "Closes in \(Self.clock(remaining))",
                    ringCaption: Self.clock(remaining)
                ) {
                    Button(action: onStopPermitJoin) {
                        Text("Stop")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, DesignTokens.Size.deviceStatusPillPaddingH)
                            .padding(.vertical, DesignTokens.Size.deviceStatusPillPaddingV)
                            .background(Color.red.opacity(DesignTokens.Opacity.chipFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Interviewing

    private var interviewingRow: some View {
        Button(action: onOpenInterviewing) {
            HomeNowRow(
                progress: nil,
                tint: .indigo,
                symbol: "waveform.path.ecg",
                title: "\(interviewingCount) interviewing",
                detail: "Learning what the device can do"
            ) {
                ProgressView().controlSize(.small)
            }
        }
        .buttonStyle(HomeCardButtonStyle())
    }
}

/// One activity: a ring on the left, what's happening in the middle, and the
/// action or affordance on the right.
private struct HomeNowRow<Accessory: View>: View {
    let progress: Double?
    let tint: Color
    let symbol: String
    let title: String
    let detail: String
    var ringCaption: String? = nil
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: DesignTokens.Size.homeNowRingStroke)
                if let progress {
                    Circle()
                        .trim(from: 0, to: max(min(progress, 1), 0))
                        .stroke(tint, style: StrokeStyle(lineWidth: DesignTokens.Size.homeNowRingStroke, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: DesignTokens.Duration.mediumAnimation), value: progress)
                }
                if let ringCaption {
                    Text(ringCaption)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding(.horizontal, DesignTokens.Spacing.xxs)
                } else {
                    Image(systemName: symbol)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: DesignTokens.Size.homeNowRing, height: DesignTokens.Size.homeNowRing)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: DesignTokens.Spacing.sm)
            accessory()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(Rectangle())
    }
}

#Preview {
    HomeNowCard(
        otaStatuses: [
            "Kitchen spot 4": OTAUpdateStatus(deviceName: "Kitchen spot 4", phase: .updating, progress: 68, remaining: 240),
            "Hall spot 2": OTAUpdateStatus(deviceName: "Hall spot 2", phase: .scheduled, progress: nil, remaining: nil),
        ],
        permitJoinEnd: Date().addingTimeInterval(42),
        permitJoinTotal: 60,
        interviewingCount: 1,
        onOpenUpdates: {},
        onStopPermitJoin: {},
        onOpenInterviewing: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
