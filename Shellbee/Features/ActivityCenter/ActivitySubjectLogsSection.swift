import SwiftUI

/// The recent subject activity section embedded in device and group detail.
struct ActivitySubjectLogsSection<Destination: View>: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    let subjectName: String
    let subjectLabel: String
    let destination: () -> Destination

    private var scope: BridgeScope { environment.scope(for: bridgeID) }
    private static var recentLimit: Int { 5 }

    init(
        bridgeID: UUID,
        subjectName: String,
        subjectLabel: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.bridgeID = bridgeID
        self.subjectName = subjectName
        self.subjectLabel = subjectLabel
        self.destination = destination
    }

    var body: some View {
        let activityEvents = ActivitySubjectEvents(
            subjectName: subjectName,
            bridgeID: bridgeID,
            store: scope.store,
            environment: environment
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
                NavigationLink(destination: destination) {
                    Label("See All Logs", systemImage: "list.bullet")
                }
            }
        }
    }
}
