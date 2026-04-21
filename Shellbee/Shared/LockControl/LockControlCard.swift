import SwiftUI

struct LockControlCard: View {
    let context: LockControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            header
            if mode == .interactive { lockButton }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if mode == .snapshot {
                Image(systemName: context.isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(context.isLocked ? Color.green : Color.orange)
                Text("Lock State").font(.headline)
            } else {
                Text("Lock").font(.headline)
            }
            Spacer()
            stateBadge
        }
    }

    private var stateBadge: some View {
        let color: Color = context.isLocked ? .green : .orange
        return Text(context.isLocked ? "Locked" : "Unlocked")
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(color.opacity(DesignTokens.Opacity.chipFill), in: Capsule())
    }

    private var lockButton: some View {
        Button {
            if let payload = context.togglePayload() { onSend(payload) }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: context.isLocked ? "lock.open" : "lock")
                    .font(.system(size: 18, weight: .semibold))
                Text(context.isLocked ? "Unlock" : "Lock")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(
                context.isLocked ? Color.orange.opacity(DesignTokens.Opacity.accentFill) : Color.green.opacity(DesignTokens.Opacity.accentFill),
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
            )
            .foregroundStyle(context.isLocked ? Color.orange : Color.green)
        }
        .buttonStyle(.plain)
        .disabled(context.stateFeature?.isWritable != true)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if let ctx = LockControlContext(device: .preview, state: ["state": .string("LOCK")]) {
                LockControlCard(context: ctx, mode: .interactive, onSend: { _ in })
                LockControlCard(context: ctx, mode: .snapshot, onSend: { _ in })
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
