import SwiftUI

/// A compact, non-interactive banner reserved for short, transient
/// confirmations like "Copied to Clipboard". The queue manager surfaces a
/// fast-track notification briefly above whatever main banner is showing,
/// then dismisses it on a fixed timer.
struct FastTrackBanner: View {
    let notification: InAppNotification

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: notification.level.systemImage)
                .font(DesignTokens.Typography.notificationLevelIcon)
                .foregroundStyle(notification.level.color)
            Text(notification.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .glassEffectIfAvailable(in: Capsule(style: .continuous))
        .shadow(
            color: .black.opacity(DesignTokens.Shadow.floatingOpacity),
            radius: DesignTokens.Shadow.floatingRadius,
            y: -DesignTokens.Shadow.floatingY
        )
    }
}

#Preview("Fast-track — Copied") {
    VStack {
        Spacer()
        FastTrackBanner(
            notification: InAppNotification(
                level: .info,
                title: "Copied to Clipboard",
                priority: .fastTrack
            )
        )
        .padding(.bottom, DesignTokens.Size.notificationBottomInset)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
}
