import SwiftUI

/// The persistent, player-like Activity Center attached to the iPhone tab
/// bar. New notifications temporarily take visual precedence; both expand
/// into the same native Activity Center sheet.
@available(iOS 26.0, *)
struct ActivityTabBarAccessory: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @AppStorage(ActivityAccessoryDisplayMode.storageKey) private var displayModeRaw = ActivityAccessoryDisplayMode.summary.rawValue

    private var displayMode: ActivityAccessoryDisplayMode {
        ActivityAccessoryDisplayMode(rawValue: displayModeRaw) ?? .summary
    }

    private var isInline: Bool {
        placement == .inline
    }

    private var latestActivity: BridgeBoundLogEntry? {
        environment.allLogEntries.first
    }

    private var recentActivityCount: Int {
        let cutoff = Date.now.addingTimeInterval(-15 * 60)
        return environment.allLogEntries.count { $0.entry.timestamp >= cutoff }
    }

    var body: some View {
        ZStack {
            if displayMode != .notificationsOnly {
                Button(action: openActivity) {
                    ActivityAccessorySummary(
                        mode: displayMode,
                        latestActivity: latestActivity,
                        recentActivityCount: recentActivityCount,
                        isInline: isInline
                    )
                }
                .buttonStyle(.plain)
            }

            InAppNotificationOverlay(
                presentation: .tabBarAccessory,
                isInlineActivityAccessory: isInline
            )
        }
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
    let recentActivityCount: Int
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
            "Activity"
        }
    }

    private var subtitle: String? {
        switch mode {
        case .latestActivity: latestActivity?.entry.summarySubtitle
        case .summary: "View Activity"
        case .notificationsOnly: nil
        }
    }

    private var symbolName: String {
        latestActivity?.entry.level.systemImage ?? "list.bullet.rectangle"
    }

    private var symbolColor: Color {
        latestActivity?.entry.level.color ?? .secondary
    }
}
