import SwiftUI

/// Home's latest events. It reads the log itself so a new log line redraws
/// this card only, not the whole Home screen.
struct HomeActivityCard: View {
    let limit: Int
    let onOpenAll: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation

    var body: some View {
        let items = recentEventItems
        HomeGroupedRows(title: "Activity") {
            if items.isEmpty {
                Text("No recent events")
                    .foregroundStyle(.secondary)
                    .homeGroupedRow()
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        sceneNavigation.pendingLogSheet = LogSheetRequest(entryIDs: [item.id])
                    } label: {
                        HomeActivityRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .homeGroupedRow()
                    if index < items.count - 1 { Divider().padding(.leading, DesignTokens.Spacing.lg) }
                }
                Divider().padding(.leading, DesignTokens.Spacing.lg)
                Button("See all", action: onOpenAll)
                    .homeGroupedRow()
            }
        }
    }

    private var recentEventItems: [ActivityEventItem] {
        environment.allLogEntries
            .lazy
            .filter { !LogRowIconography.isLinkQualityOnly($0.entry) }
            .prefix(limit)
            .map(environment.activityEventItem(for:))
    }
}
