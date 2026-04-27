import SwiftUI

struct MeshDetailView: View {
    let snapshot: HomeSnapshot

    var body: some View {
        Form {
            Section("Network") {
                if let channel = snapshot.networkChannel {
                    CopyableRow(label: "Channel", value: "\(channel)")
                }
                if let pan = snapshot.panIDText {
                    CopyableRow(label: "PAN ID", value: pan)
                        .monospaced()
                }
            }

            Section("Coordinator") {
                if let type = snapshot.coordinatorType {
                    CopyableRow(label: "Type", value: type)
                }
                if let ieee = snapshot.coordinatorIEEEAddress {
                    CopyableRow(label: "IEEE Address", value: ieee)
                        .monospaced()
                }
            }

            Section("Topology") {
                CopyableRow(label: "Routers", value: "\(snapshot.routerCount)")
                CopyableRow(label: "End Devices", value: "\(snapshot.endDeviceCount)")
                if let lqi = snapshot.averageLinkQuality {
                    CopyableRow(label: "Average LQI", value: "\(lqi)")
                }
            }
        }
        .navigationTitle("Mesh")
        .navigationBarTitleDisplayMode(.inline)
    }
}
