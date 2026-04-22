import SwiftUI

struct AboutView: View {
    @Environment(AppEnvironment.self) private var environment

    private var info: BridgeInfo? { environment.store.bridgeInfo }
    private var stats: HomeStatsSnapshot { HomeStatsSnapshot(devices: environment.store.devices) }

    var body: some View {
        Form {
            bridgeSection
            networkSection
            moreSection
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var bridgeSection: some View {
        Section("Bridge") {
            if let version = info?.version {
                CopyableRow(label: "Version", value: version)
            }
            if let commit = info?.commit {
                CopyableRow(label: "Commit", value: String(commit.prefix(12)))
            }
            if let type = info?.coordinator.type {
                CopyableRow(label: "Coordinator", value: type)
            }
            if let ieee = info?.coordinator.ieeeAddress {
                CopyableRow(label: "IEEE Address", value: ieee)
            }
            if let logLevel = info?.logLevel {
                LabeledContent("Log Level", value: logLevel)
            }
        }
    }

    @ViewBuilder
    private var networkSection: some View {
        if info?.network != nil {
            Section("Zigbee Network") {
                if let channel = info?.network?.channel {
                    CopyableRow(label: "Channel", value: "\(channel)")
                }
                if let panID = info?.network?.panID {
                    CopyableRow(label: "PAN ID", value: String(format: "0x%04X", panID))
                }
                if case .string(let ext) = info?.network?.extendedPanID {
                    CopyableRow(label: "Extended PAN ID", value: ext)
                }
            }
        }
    }

    private var moreSection: some View {
        Section {
            NavigationLink { DeviceStatisticsView() } label: {
                Text("Device Statistics")
            }
            NavigationLink { AcknowledgementsView() } label: {
                Text("Acknowledgements")
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView().environment(AppEnvironment())
    }
}
