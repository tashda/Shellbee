import SwiftUI

struct LockControlCard: View {
    let context: LockControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            heroHeadline
            if showsActionButton {
                hairline
                actionButton
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    /// Locked = green (Apple Home's "secured" tile), Unlocked = orange so the
    /// unusual/attention-worthy state stands out at a glance.
    private var heroTint: Color {
        context.isLocked ? .green : .orange
    }

    /// Tint of the *action* the user is about to take. Tapping the button
    /// swaps the lock's state, so the button shows the destination color:
    /// "Unlock" reads orange (you're opening a secure door), "Lock" reads
    /// green (you're securing it).
    private var actionTint: Color {
        context.isLocked ? .orange : .green
    }

    private var heroBackground: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            LinearGradient(
                colors: [heroTint.opacity(0.18), heroTint.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Hero

    private var heroHeadline: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                heroEyebrow
                heroValue
            }
            Spacer(minLength: 0)
            if mode == .snapshot { statePill }
        }
    }

    private var heroEyebrow: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: context.isLocked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 11, weight: .bold))
                .symbolRenderingMode(.hierarchical)
            Text("Lock")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
        }
        .foregroundStyle(heroTint)
    }

    private var heroValue: some View {
        Text(context.isLocked ? "Locked" : "Unlocked")
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(heroTint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var statePill: some View {
        Text(context.isLocked ? "LOCKED" : "UNLOCKED")
            .font(.caption.weight(.bold))
            .foregroundStyle(heroTint)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(heroTint.opacity(DesignTokens.Opacity.chipFill), in: Capsule())
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: DesignTokens.Size.hairline)
    }

    // MARK: - Action button

    private var showsActionButton: Bool {
        mode == .interactive && context.stateFeature?.isWritable == true
    }

    private var actionButton: some View {
        Button {
            if let payload = context.togglePayload() { onSend(payload) }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: context.isLocked ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(context.isLocked ? "Unlock" : "Lock")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .tint(actionTint)
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
