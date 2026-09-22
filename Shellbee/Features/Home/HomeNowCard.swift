import SwiftUI

/// What is happening right now: pairing open and counting down, firmware
/// in flight, a device being interviewed.
///
/// This is the one card on Home, because it is the one thing here you
/// operate — everything else you only read. It exists only while something
/// is in flight and takes itself away when that finishes, so it is pinned
/// above the sections rather than sitting in one.
///
/// One row per activity, never one per device: a forty-device flash
/// session is still a single line.
struct HomeNowCard: View {
    /// Pairing open on one bridge. Several bridges can be open at once, so
    /// each gets its own row and says which bridge it is when it has to.
    struct PermitJoin: Identifiable {
        let bridgeID: UUID
        let bridgeName: String
        let endsAt: Date
        /// True once more than one bridge is connected.
        let namesBridge: Bool

        var id: UUID { bridgeID }
    }

    let permitJoins: [PermitJoin]
    let updatingCount: Int
    /// Mean progress across the devices actually flashing, 0–1.
    let updateProgress: Double?
    let interviewingCount: Int
    let onOpenUpdates: () -> Void
    let onStopPermitJoin: (UUID) -> Void

    static func hasContent(
        permitJoins: [PermitJoin],
        updatingCount: Int,
        interviewingCount: Int
    ) -> Bool {
        !permitJoins.isEmpty || updatingCount > 0 || interviewingCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ForEach(Array(permitJoins.enumerated()), id: \.element.id) { index, join in
                if index > 0 { Divider() }
                permitJoinRow(join)
            }

            if updatingCount > 0 {
                if !permitJoins.isEmpty { Divider() }
                updatingRow
            }

            if interviewingCount > 0 {
                if !permitJoins.isEmpty || updatingCount > 0 { Divider() }
                CardHeader(
                    systemImage: "waveform.path.ecg",
                    title: "Interviewing",
                    value: deviceCount(interviewingCount)
                ) {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .cardSurface()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Pairing

    private func permitJoinRow(_ join: PermitJoin) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(Int(join.endsAt.timeIntervalSince(context.date)), 0)
            CardHeader(
                systemImage: "person.crop.circle.badge.plus",
                // With one bridge there's room to say what the clock means.
                // With several, the bridge's name is the more useful half
                // and a countdown beside a Stop button reads as time left.
                title: join.namesBridge ? "Pairing · \(join.bridgeName)" : "Pairing open",
                value: join.namesBridge
                    ? Self.clock(remaining)
                    : "Closes in \(Self.clock(remaining))",
                tint: .orange
            ) {
                Button("Stop") { onStopPermitJoin(join.bridgeID) }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
            }
        }
    }

    /// m:ss, the way a timer reads.
    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Firmware

    private var updatingRow: some View {
        Button(action: onOpenUpdates) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                CardHeader(
                    systemImage: "arrow.up.circle.fill",
                    title: "Updating",
                    value: updateValue,
                    tint: .green
                ) {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                if let updateProgress {
                    ProgressView(value: updateProgress)
                        .tint(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var updateValue: String {
        guard let updateProgress else { return deviceCount(updatingCount) }
        return "\(deviceCount(updatingCount)) · \(Int(updateProgress * 100)) %"
    }

    private func deviceCount(_ n: Int) -> String {
        "\(n) device\(n == 1 ? "" : "s")"
    }
}

#Preview {
    VStack {
        HomeNowCard(
            permitJoins: [
                .init(bridgeID: UUID(), bridgeName: "Home Bridge",
                      endsAt: Date().addingTimeInterval(83), namesBridge: false)
            ],
            updatingCount: 3,
            updateProgress: 0.68,
            interviewingCount: 1,
            onOpenUpdates: {},
            onStopPermitJoin: { _ in }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
