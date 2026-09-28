import SwiftUI

struct DeviceLogsView: View {
    let bridgeID: UUID
    let device: Device

    var body: some View {
        ActivitySubjectLogsView(
            bridgeID: bridgeID,
            subjectName: device.friendlyName,
            showsSignalChanges: true
        )
    }
}

#Preview {
    NavigationStack {
        DeviceLogsView(bridgeID: UUID(), device: .preview)
            .environment(AppEnvironment())
    }
    .configuredTopScrollEdgeEffect()
}
