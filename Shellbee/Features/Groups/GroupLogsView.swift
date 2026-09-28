import SwiftUI

struct GroupLogsView: View {
    let bridgeID: UUID
    let group: Group

    var body: some View {
        ActivitySubjectLogsView(bridgeID: bridgeID, subjectName: group.friendlyName)
    }
}

#Preview {
    NavigationStack {
        GroupLogsView(bridgeID: UUID(), group: .previewWithMembers)
            .environment(AppEnvironment())
    }
    .configuredTopScrollEdgeEffect()
}
