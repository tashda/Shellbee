import SwiftUI

struct LockControlCard: View {
    let context: LockControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    /// Unlocking takes two taps: the first arms the button, the second sends.
    @State private var isUnlockArmed = false

    @ViewBuilder
    var body: some View {
        if mode == .snapshot {
            snapshotContent
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                CardHeader(
                    systemImage: context.isLocked ? "lock.fill" : "lock.open.fill",
                    title: "Lock",
                    value: context.isLocked ? "Locked" : "Unlocked",
                    tint: heroTint,
                    valueColor: context.isLocked ? .secondary : .orange
                )
                if showsActionButton { actionButton }
            }
            .cardSurface()
        }
    }

    // MARK: - Snapshot

    /// Compact log-row rendering. Lock glyph + "Lock" + LOCKED/UNLOCKED pill.
    private var snapshotContent: some View {
        CompactSnapshotCard {
            CompactControlSnapshotRow(
                systemImage: context.isLocked ? "lock.fill" : "lock.open.fill",
                title: "Lock",
                subtitle: nil,
                tint: heroTint
            ) {
                statePill
            }
        }
    }

    /// Locked = green (Apple Home's "secured" tile), Unlocked = orange so the
    /// unusual/attention-worthy state stands out at a glance.
    private var heroTint: Color {
        context.isLocked ? .green : .orange
    }

    private var statePill: some View {
        Text(context.isLocked ? "LOCKED" : "UNLOCKED")
            .font(.caption.weight(.bold))
            .foregroundStyle(heroTint)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(heroTint.opacity(DesignTokens.Opacity.chipFill), in: Capsule())
    }

    // MARK: - Action button

    private var showsActionButton: Bool {
        mode == .interactive && context.stateFeature?.isWritable == true
    }

    private var actionButton: some View {
        Button(action: performAction) {
            Label(buttonTitle, systemImage: context.isLocked ? "lock.open.fill" : "lock.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonBorderShape(.capsule)
        .modifier(LockButtonStyle(isArmed: isUnlockArmed))
        .animation(.snappy, value: isUnlockArmed)
    }

    private var buttonTitle: String {
        guard context.isLocked else { return "Lock" }
        return isUnlockArmed ? "Tap Again to Unlock" : "Unlock"
    }

    private func performAction() {
        if context.isLocked, !isUnlockArmed {
            isUnlockArmed = true
            Task {
                try? await Task.sleep(for: .seconds(3))
                isUnlockArmed = false
            }
            return
        }
        isUnlockArmed = false
        if let payload = context.togglePayload() { onSend(payload) }
    }
}

/// Glass while idle; orange prominent glass once unlocking is armed.
private struct LockButtonStyle: ViewModifier {
    let isArmed: Bool

    func body(content: Content) -> some View {
        if isArmed {
            content.glassProminentButtonStyleIfAvailable().tint(.orange)
        } else {
            content.glassButtonStyleIfAvailable().tint(.primary)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if let locked = LockControlContext(device: .preview, state: ["state": .string("LOCK")]) {
                LockControlCard(context: locked, mode: .interactive, onSend: { _ in })
                LockControlCard(context: locked, mode: .snapshot, onSend: { _ in })
            }
            if let unlocked = LockControlContext(device: .preview, state: ["state": .string("UNLOCK")]) {
                LockControlCard(context: unlocked, mode: .interactive, onSend: { _ in })
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
