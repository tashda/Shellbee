import SwiftUI

/// The recent subject activity section embedded in device and group detail.
struct ActivitySubjectLogsSection<Destination: View>: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    let subjectName: String
    let subjectLabel: String
    var showsSignalChanges = false
    let destination: () -> Destination
    let onSeeAll: (() -> Void)?

    private var scope: BridgeScope { environment.scope(for: bridgeID) }
    private static var recentLimit: Int { 5 }

    init(
        bridgeID: UUID,
        subjectName: String,
        subjectLabel: String,
        showsSignalChanges: Bool = false,
        onSeeAll: (() -> Void)? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.bridgeID = bridgeID
        self.subjectName = subjectName
        self.subjectLabel = subjectLabel
        self.showsSignalChanges = showsSignalChanges
        self.onSeeAll = onSeeAll
        self.destination = destination
    }

    var body: some View {
        let activityEvents = ActivitySubjectEvents(
            subjectName: subjectName,
            bridgeID: bridgeID,
            store: scope.store,
            environment: environment,
            showsSignalChanges: showsSignalChanges
        )
        let recent = Array(activityEvents.items.prefix(Self.recentLimit))

        Section("Logs") {
            if activityEvents.sourceEntries.isEmpty {
                Text("No logs for this \(subjectLabel) yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recent) { item in
                    ActivitySubjectEvents.Row(item: item, bridgeID: bridgeID)
                }
                if let onSeeAll {
                    // Opens the Activity Center rather than pushing, but
                    // reads as the same disclosure row as a NavigationLink.
                    Button(action: onSeeAll) {
                        HStack {
                            Text("Show All Logs")
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink("Show All Logs", destination: destination)
                }
            }
        }
    }
}
