import SwiftUI

struct LockControlCard: View {
    let context: LockControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    @ViewBuilder
    var body: some View {
        if mode == .snapshot {
            snapshotContent
        } else {
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
    }

    // MARK: - Snapshot

    /// Compact log-row rendering. Lock glyph + "Lock" + LOCKED/UNLOCKED pill.
    private var snapshotContent: some View {
        CompactSnapshotCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: context.isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(heroTint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Lock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: DesignTokens.Spacing.sm)

                statePill
            }
        }
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
                colors: [heroTint.opacity(DesignTokens.Opacity.onStateTint), heroTint.opacity(DesignTokens.Opacity.subtleFade)],
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
        }
    }

    private var heroEyebrow: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: context.isLocked ? "lock.fill" : "lock.open.fill")
                .font(DesignTokens.Typography.eyebrowIcon)
                .symbolRenderingMode(.hierarchical)
            Text("Lock")
                .font(DesignTokens.Typography.eyebrowLabel)
                .tracking(DesignTokens.Typography.eyebrowTracking)
                .textCase(.uppercase)
        }
        .foregroundStyle(heroTint)
    }

    private var heroValue: some View {
        Text(context.isLocked ? "Locked" : "Unlocked")
            .font(DesignTokens.Typography.heroStateText)
            .foregroundStyle(heroTint)
            .lineLimit(1)
            .minimumScaleFactor(DesignTokens.Typography.scaleFactorRelaxed)
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
            .fill(Color.primary.opacity(DesignTokens.Opacity.hairline))
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
                    .font(DesignTokens.Typography.formRowIconBold)
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
