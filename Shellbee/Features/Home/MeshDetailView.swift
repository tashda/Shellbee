import SwiftUI

struct MeshDetailView: View {
    let snapshot: HomeSnapshot

    var body: some View {
        Form {
            Section("Network") {
                if let channel = snapshot.networkChannel {
                    LabeledContent("Channel", value: "\(channel)")
                }
                if let pan = snapshot.panIDText {
                    LabeledContent("PAN ID", value: pan)
                        .monospaced()
                }
            }

            Section("Coordinator") {
                if let type = snapshot.coordinatorType {
                    LabeledContent("Type", value: type)
                }
                if let ieee = snapshot.coordinatorIEEEAddress {
                    LabeledContent("IEEE Address", value: ieee)
                        .monospaced()
                        .textSelection(.enabled)
                }
            }

            Section("Topology") {
                LabeledContent("Routers", value: "\(snapshot.routerCount)")
                LabeledContent("End Devices", value: "\(snapshot.endDeviceCount)")
                if let lqi = snapshot.averageLinkQuality {
                    LabeledContent("Average LQI", value: "\(lqi)")
                }
            }
        }
        .navigationTitle("Mesh")
        .navigationBarTitleDisplayMode(.inline)
    }
}
