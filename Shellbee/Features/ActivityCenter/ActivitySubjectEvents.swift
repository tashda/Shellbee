import SwiftUI

/// The Activity Center's user-facing events for one device or group.
///
/// Detail pages use this instead of reading `AppStore.logEntries` directly,
/// so the event wording, instruments, subject resolution and signal-noise
/// filtering stay aligned with Activity Center and Home's Recent Events.
struct ActivitySubjectEvents {
    let sourceEntries: [LogEntry]
    let items: [ActivityEventItem]

    init(
        subjectName: String,
        bridgeID: UUID,
        store: AppStore,
        environment: AppEnvironment,
        showsSignalChanges: Bool = false
    ) {
        let bridgeName = environment.registry.session(for: bridgeID)?.displayName ?? "Bridge"

        func belongsToSubject(_ entry: LogEntry) -> Bool {
            let bound = BridgeBoundLogEntry(
                bridgeID: bridgeID,
                bridgeName: bridgeName,
                entry: entry
            )
            return environment.activitySubject(for: bound) == .named(subjectName)
        }

        sourceEntries = store.logEntries.filter(belongsToSubject)

        // Use the same default Activity filtering and coalescing as the
        // Activity log. This notably keeps high-volume link-quality drift
        // from crowding out events that a person can act on.
        let viewModel = LogsViewModel()
        viewModel.showLinkQualityChanges = showsSignalChanges
        items = viewModel
            .filteredEntries(store: store)
            .filter(belongsToSubject)
            .map { entry in
                environment.activityEventItem(for: BridgeBoundLogEntry(
                    bridgeID: bridgeID,
                    bridgeName: bridgeName,
                    entry: entry
                ))
            }
    }

    /// The shared native-list presentation of an Activity event. The card
    /// feed, Home and detail pages all build from the same `ActivityEventItem`.
    struct Row: View {
        @Environment(AppEnvironment.self) private var environment
        let item: ActivityEventItem
        let bridgeID: UUID
        var usesValueNavigation = false
        var showsBridgeIndicator = true

        var body: some View {
            if let entry = item.entry {
                SwiftUI.Group {
                    if usesValueNavigation {
                        NavigationLink(value: LogsPaneRoute.activity(LogRoute(bridgeID: bridgeID, entry: entry))) {
                            label
                        }
                    } else {
                        NavigationLink {
                            LogDetailView(bridgeID: bridgeID, entry: entry)
                        } label: {
                            label
                        }
                    }
                }
                .modifier(BridgeRowLeadingBarBackground(
                    bridgeID: bridgeID,
                    enabled: showsBridgeIndicator
                ))
            }
        }

        private var label: some View {
            ActivityEventRow(
                instrument: item.instrument,
                content: item.content,
                timestamp: item.timestamp,
                instrumentSize: DesignTokens.ActivityFeed.thumbnail
            )
            .padding(.vertical, DesignTokens.Spacing.sm)
            .accessibilityIdentifier("activity-log-\(bridgeName)")
        }

        private var bridgeName: String {
            environment.registry.session(for: bridgeID)?.displayName ?? "Unknown"
        }
    }
}
