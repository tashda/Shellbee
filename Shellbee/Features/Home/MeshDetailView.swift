import SwiftUI

struct MeshDetailView: View {
    let snapshot: HomeSnapshot
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Mesh")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .configuredTopScrollEdgeEffect()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var form: some View {
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
                // Network Map is iPad-only and hidden behind Developer Mode
                // for now — see MainTabView, which only surfaces its tab there.
                if AdaptiveLayout.isPad && developerModeEnabled {
                    NavigationLink {
                        NetworkMapView()
                    } label: {
                        Label("Network Map", symbol: .custom("mesh"))
                    }
                }
            }
        }
    }
}
