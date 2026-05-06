import SwiftUI

/// Sheet that surfaces log entries from notification taps. Used by both
/// `MainTabView` (compact) and `MainSplitView` (regular) so the
/// notification overlay routes the same way regardless of shell.
struct LogSheetHost: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let request: LogSheetRequest

    private var singleResolved: (UUID, LogEntry)? {
        guard request.isSingle, let id = request.entryIDs.first else { return nil }
        for session in environment.registry.orderedSessions {
            if let entry = session.store.logEntries.first(where: { $0.id == id }) {
                return (session.bridgeID, entry)
            }
        }
        return nil
    }

    var body: some View {
        if let (bridgeID, entry) = singleResolved {
            NavigationStack {
                LogDetailView(bridgeID: bridgeID, entry: entry, doneAction: { dismiss() })
                    .navigationDestination(for: DeviceRoute.self) { route in
                        DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                    }
                    .navigationDestination(for: GroupRoute.self) { route in
                        GroupDetailView(bridgeID: route.bridgeID, group: route.group)
                    }
            }
        } else {
            NavigationStack {
                LogsView(
                    initialEntryFilter: Set(request.entryIDs),
                    notificationSheetStyle: true,
                    onDone: { dismiss() }
                )
                .navigationDestination(for: DeviceRoute.self) { route in
                    DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
                }
                .navigationDestination(for: GroupRoute.self) { route in
                    GroupDetailView(bridgeID: route.bridgeID, group: route.group)
                }
            }
        }
    }
}
