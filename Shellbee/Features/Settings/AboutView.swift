import SwiftUI

struct AboutView: View {
    @Environment(AppEnvironment.self) private var environment

    private var info: BridgeInfo? { environment.store.bridgeInfo }
    private var stats: HomeStatsSnapshot { HomeStatsSnapshot(devices: environment.store.devices) }

    var body: some View {
        Form {
            bridgeSection
            networkSection
            deviceBreakdownSections
            openSourceSection
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var bridgeSection: some View {
        Section("Bridge") {
            if let version = info?.version {
                LabeledContent("Version", value: version)
            }
            if let commit = info?.commit {
                LabeledContent("Commit", value: String(commit.prefix(12)))
            }
            if let type = info?.coordinator.type {
                LabeledContent("Coordinator", value: type)
            }
            if let ieee = info?.coordinator.ieeeAddress {
                LabeledContent("IEEE Address", value: ieee)
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
                    LabeledContent("Channel", value: "\(channel)")
                }
                if let panID = info?.network?.panID {
                    LabeledContent("PAN ID", value: String(format: "0x%04X", panID))
                }
                if case .string(let ext) = info?.network?.extendedPanID {
                    LabeledContent("Extended PAN ID", value: ext)
                }
            }
        }
    }

    private var openSourceSection: some View {
        Section("Open Source") {
            Link(destination: URL(string: "https://github.com/Koenkk/zigbee2mqtt")!) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Zigbee2MQTT")
                            .foregroundStyle(.primary)
                        Text("Open source Zigbee gateway by Koenkk")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var deviceBreakdownSections: some View {
        if !stats.deviceTypeItems.isEmpty {
            Section("Device Types") {
                ForEach(stats.deviceTypeItems) { item in
                    LabeledContent(item.title, value: "\(item.count)")
                }
            }
        }
        if !stats.powerSourceItems.isEmpty {
            Section("Power Sources") {
                ForEach(stats.powerSourceItems) { item in
                    LabeledContent(item.title, value: "\(item.count)")
                }
            }
        }
        if !stats.vendorItems.isEmpty {
            Section("Vendors") {
                ForEach(stats.vendorItems) { item in
                    LabeledContent(item.title, value: "\(item.count)")
                }
            }
        }
        if !stats.modelItems.isEmpty {
            Section("Models") {
                ForEach(stats.modelItems) { item in
                    LabeledContent(item.title, value: "\(item.count)")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView().environment(AppEnvironment())
    }
}
