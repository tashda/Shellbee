import SwiftUI

/// The persistent, player-like Activity Center attached to the iPhone tab
/// bar. It reads the same structured Activity history shown in its sheet.
@available(iOS 26.0, *)
struct ActivityTabBarAccessory: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @AppStorage(ActivityAccessoryDisplayMode.storageKey) private var displayModeRaw = ActivityAccessoryDisplayMode.summary.rawValue
    let transitionNamespace: Namespace.ID?

    private var displayMode: ActivityAccessoryDisplayMode {
        ActivityAccessoryDisplayMode(rawValue: displayModeRaw) ?? .summary
    }

    private var isInline: Bool {
        placement == .inline
    }

    private var latestActivity: BridgeBoundLogEntry? {
        environment.allLogEntries.first
    }

    private var latestAttention: BridgeBoundLogEntry? {
        environment.allLogEntries.first { $0.entry.isActivityAttention }
    }

    private var recentActivityCount: Int {
        let cutoff = Date.now.addingTimeInterval(-15 * 60)
        return environment.allLogEntries.count { $0.entry.timestamp >= cutoff }
    }

    private var recentAttentionCount: Int {
        let cutoff = Date.now.addingTimeInterval(-15 * 60)
        return environment.allLogEntries.count {
            $0.entry.isActivityAttention && $0.entry.timestamp >= cutoff
        }
    }

    var body: some View {
        SwiftUI.Group {
            if let transitionNamespace {
                accessorySurface
                    .matchedTransitionSource(id: "activity-center", in: transitionNamespace)
            } else {
                accessorySurface
            }
        }
    }

    /// Keep the matched source on the actual mini-player surface. A Button
    /// adds a separate control transaction before the cover starts, which
    /// makes the opening zoom noticeably less continuous than the return.
    private var accessorySurface: some View {
        ActivityAccessorySummary(
            mode: displayMode,
            latestActivity: latestActivity,
            latestAttention: latestAttention,
            recentActivityCount: recentActivityCount,
            recentAttentionCount: recentAttentionCount,
            isInline: isInline
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: openActivity)
        .simultaneousGesture(openActivityGesture, including: .all)
        .accessibilityAddTraits(.isButton)
    }

    private func openActivity() {
        sceneNavigation.isActivityCenterPresented = true
    }

    private var openActivityGesture: some Gesture {
        DragGesture(minimumDistance: DesignTokens.Spacing.xs)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(vertical) > abs(horizontal), vertical < -DesignTokens.Spacing.xxl else { return }
                openActivity()
            }
    }
}

@available(iOS 26.0, *)
private struct ActivityAccessorySummary: View {
    @Environment(AppEnvironment.self) private var environment
    let mode: ActivityAccessoryDisplayMode
    let latestActivity: BridgeBoundLogEntry?
    let latestAttention: BridgeBoundLogEntry?
    let recentActivityCount: Int
    let recentAttentionCount: Int
    let isInline: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            artwork

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                if !isInline, let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: DesignTokens.Spacing.sm)

            Image(systemName: "chevron.up")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: isInline ? nil : .infinity, alignment: .leading)
        .accessibilityLabel("Activity: \(title)")
        .accessibilityHint("Opens Activity")
    }

    private var title: String {
        switch mode {
        case .latestActivity:
            latestActivity?.entry.summaryTitle ?? "Activity"
        case .summary:
            recentActivityCount == 0 ? "No recent activity" : "\(recentActivityCount) recent events"
        case .notificationsOnly:
            latestAttention?.entry.summaryTitle
                ?? (recentAttentionCount == 0 ? "Notifications" : "\(recentAttentionCount) notifications")
        }
    }

    private var subtitle: String? {
        switch mode {
        case .latestActivity: latestActivity?.entry.summarySubtitle
        case .summary: "View Activity"
        case .notificationsOnly: latestAttention?.entry.summarySubtitle ?? "No new notifications"
        }
    }

    /// A player-style artwork slot. Event modes show the event's own
    /// thumbnail; Summary stays quiet unless something needs attention.
    @ViewBuilder
    private var artwork: some View {
        let size = DesignTokens.ActivityFeed.accessoryArtwork
        switch mode {
        case .latestActivity:
            eventArtwork(latestActivity, fallback: "tray.full.fill", size: size)
        case .notificationsOnly:
            eventArtwork(latestAttention, fallback: "bell.fill", size: size)
        case .summary:
            if recentAttentionCount > 0 {
                symbolArtwork("exclamationmark", foreground: .white, background: Color.orange, size: size)
            } else {
                symbolArtwork("tray.full.fill", foreground: .secondary, background: .fill.tertiary, size: size)
            }
        }
    }

    @ViewBuilder
    private func eventArtwork(_ item: BridgeBoundLogEntry?, fallback: String, size: CGFloat) -> some View {
        if let item {
            ActivityThumbnail(entry: item.entry, store: storeFor(item.bridgeID), size: size, pipBorder: .clear)
        } else {
            symbolArtwork(fallback, foreground: .secondary, background: .fill.tertiary, size: size)
        }
    }

    private func storeFor(_ bridgeID: UUID) -> AppStore? {
        environment.registry.session(for: bridgeID)?.store
    }

    private func symbolArtwork(
        _ name: String,
        foreground: some ShapeStyle,
        background: some ShapeStyle,
        size: CGFloat
    ) -> some View {
        Image(systemName: name)
            .font(.system(size: size * DesignTokens.ActivityFeed.glyphRatio, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: Circle())
    }
}
