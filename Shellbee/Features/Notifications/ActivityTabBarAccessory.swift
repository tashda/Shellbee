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
                accessoryButton
                    .matchedTransitionSource(id: "activity-center", in: transitionNamespace)
            } else {
                accessoryButton
            }
        }
    }

    private var accessoryButton: some View {
        Button(action: openActivity) {
            ActivityAccessorySummary(
                mode: displayMode,
                latestActivity: latestActivity,
                latestAttention: latestAttention,
                recentActivityCount: recentActivityCount,
                recentAttentionCount: recentAttentionCount,
                isInline: isInline
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .simultaneousGesture(openActivityGesture, including: .all)
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
    let mode: ActivityAccessoryDisplayMode
    let latestActivity: BridgeBoundLogEntry?
    let latestAttention: BridgeBoundLogEntry?
    let recentActivityCount: Int
    let recentAttentionCount: Int
    let isInline: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: symbolName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(symbolColor)

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

    private var symbolName: String {
        if mode == .notificationsOnly {
            return latestAttention?.entry.level.systemImage ?? "bell"
        }
        return latestActivity?.entry.level.systemImage ?? "list.bullet.rectangle"
    }

    private var symbolColor: Color {
        if mode == .notificationsOnly {
            return latestAttention?.entry.level.color ?? .secondary
        }
        return latestActivity?.entry.level.color ?? .secondary
    }
}
