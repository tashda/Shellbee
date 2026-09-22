import SwiftUI

/// The persistent, player-like Activity Center attached to the iPhone tab
/// bar. It reads the same structured Activity history shown in its sheet.
@available(iOS 26.0, *)
struct ActivityTabBarAccessory: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @AppStorage(ActivityAccessoryDisplayMode.storageKey) private var displayModeRaw = ActivityAccessoryDisplayMode.latestActivity.rawValue
    @AppStorage(ActivityAttentionClearance.storageKey) private var clearanceRaw = ""
    let transitionNamespace: Namespace.ID?
    /// Mirrors the Activity filter's Show Signal Changes, so the accessory
    /// never surfaces events the Activity Center itself hides.
    let showsSignalChanges: Bool

    private var displayMode: ActivityAccessoryDisplayMode {
        ActivityAccessoryDisplayMode(rawValue: displayModeRaw) ?? .summary
    }

    private var isInline: Bool {
        placement == .inline
    }

    private var visibleEntries: [BridgeBoundLogEntry] {
        guard !showsSignalChanges else { return environment.allLogEntries }
        return environment.allLogEntries.filter { !LogRowIconography.isLinkQualityOnly($0.entry) }
    }

    private var latestActivity: BridgeBoundLogEntry? {
        visibleEntries.first
    }

    /// Attention the user hasn't cleared in the Activity Center, so the
    /// accessory stops nagging once Needs Attention is cleared.
    private var attentionEntries: [BridgeBoundLogEntry] {
        let clearance = ActivityAttentionClearance(rawValue: clearanceRaw)
        return visibleEntries.filter {
            $0.entry.isActivityAttention
                && !clearance.isCleared($0.entry, bridgeID: $0.bridgeID, subject: environment.activitySubject(for: $0))
        }
    }

    private var latestAttention: BridgeBoundLogEntry? {
        attentionEntries.first
    }

    private var recentActivityCount: Int {
        let cutoff = Date.now.addingTimeInterval(-15 * 60)
        return visibleEntries.count { $0.entry.timestamp >= cutoff }
    }

    private var recentAttentionCount: Int {
        let cutoff = Date.now.addingTimeInterval(-15 * 60)
        return attentionEntries.count { $0.entry.timestamp >= cutoff }
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
struct ActivityAccessorySummary: View {
    @Environment(AppEnvironment.self) private var environment
    let mode: ActivityAccessoryDisplayMode
    let latestActivity: BridgeBoundLogEntry?
    let latestAttention: BridgeBoundLogEntry?
    let recentActivityCount: Int
    let recentAttentionCount: Int
    let isInline: Bool

    var body: some View {
        ActivityAccessoryContent(
            instrument: instrument,
            title: title,
            subtitle: subtitle,
            change: event.flatMap { ActivityAccessoryChange(entry: $0.entry) },
            timestamp: event?.entry.timestamp,
            identity: event?.entry.summaryTitle ?? "",
            isInline: isInline
        )
    }

    /// The event the accessory is showing, if its mode shows one.
    private var event: BridgeBoundLogEntry? {
        switch mode {
        case .latestActivity: latestActivity
        case .notificationsOnly: latestAttention
        case .summary: nil
        }
    }

    /// Same wording as the event's card in the Activity feed.
    private var item: ActivityEventItem? {
        event.map(environment.activityEventItem(for:))
    }

    private var title: String {
        switch mode {
        case .latestActivity:
            item?.content.title ?? "Activity"
        case .summary:
            recentActivityCount == 0 ? "No recent activity" : "\(recentActivityCount) recent events"
        case .notificationsOnly:
            item?.content.title
                ?? (recentAttentionCount == 0 ? "Notifications" : "\(recentAttentionCount) notifications")
        }
    }

    private var subtitle: String? {
        switch mode {
        case .latestActivity: item?.content.message
        case .summary: "View Activity"
        case .notificationsOnly: item?.content.message ?? "No new notifications"
        }
    }

    /// Event modes show the event's own instrument; Summary stays quiet
    /// unless something needs attention.
    private var instrument: ActivityInstrument {
        if let item { return item.instrument }
        switch mode {
        case .summary where recentAttentionCount > 0, .notificationsOnly:
            return .init(kind: .message, severity: recentAttentionCount > 0 ? .warning : .quiet)
        case .summary, .latestActivity:
            return .init(kind: .message, severity: .quiet)
        }
    }
}
