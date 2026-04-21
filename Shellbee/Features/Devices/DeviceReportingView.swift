import SwiftUI

struct DeviceReportingView: View {
    @Environment(AppEnvironment.self) private var environment
    let device: Device
    @State private var showAddSheet = false

    private var currentDevice: Device {
        environment.store.devices.first { $0.ieeeAddress == device.ieeeAddress } ?? device
    }

    private var reportings: [ConfiguredReporting] {
        ConfiguredReporting.parse(from: currentDevice.endpoints ?? [:])
    }

    private var availableClusters: [String] {
        var clusters: Set<String> = []
        for (_, value) in currentDevice.endpoints ?? [:] {
            if let obj = value.object,
               let clustersObj = obj["clusters"]?.object,
               let arr = clustersObj["input"]?.array {
                clusters.formUnion(arr.compactMap(\.stringValue))
            }
        }
        return clusters.sorted()
    }

    var body: some View {
        List {
            if reportings.isEmpty {
                ContentUnavailableView(
                    "No Configured Reporting",
                    systemImage: "waveform",
                    description: Text("No attribute reporting is configured for this device.")
                )
            } else {
                Section("Configured Reporting") {
                    ForEach(reportings) { reporting in
                        ReportingRow(reporting: reporting)
                    }
                }
            }
        }
        .navigationTitle("Reporting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddReportingSheet(
                device: currentDevice,
                availableClusters: availableClusters
            ) { config in
                sendReportingConfig(config)
            }
        }
    }

    private func sendReportingConfig(_ config: ReportingConfig) {
        environment.send(
            topic: Z2MTopics.Request.deviceReportingConfigure,
            payload: .object([
                "id": .string(currentDevice.friendlyName),
                "cluster": .string(config.cluster),
                "attribute": .string(config.attribute),
                "minimum_report_interval": .int(config.minInterval),
                "maximum_report_interval": .int(config.maxInterval),
                "reportable_change": .int(config.reportableChange)
            ])
        )
    }
}

struct ConfiguredReporting: Identifiable {
    let id = UUID()
    let endpoint: Int
    let cluster: String
    let attribute: String
    let minInterval: Int
    let maxInterval: Int
    let reportableChange: Int

    static func parse(from endpoints: [String: JSONValue]) -> [ConfiguredReporting] {
        var result: [ConfiguredReporting] = []
        for (key, value) in endpoints {
            guard let ep = Int(key),
                  let obj = value.object,
                  let arr = obj["configured_reportings"]?.array else { continue }
            for item in arr {
                guard let r = item.object,
                      let cluster = r["cluster"]?.stringValue,
                      let attribute = r["attribute"]?.stringValue else { continue }
                result.append(ConfiguredReporting(
                    endpoint: ep, cluster: cluster, attribute: attribute,
                    minInterval: r["minimum_report_interval"]?.intValue ?? 0,
                    maxInterval: r["maximum_report_interval"]?.intValue ?? 3600,
                    reportableChange: r["reportable_change"]?.intValue ?? 0
                ))
            }
        }
        return result.sorted { $0.endpoint < $1.endpoint }
    }
}

struct ReportingConfig {
    var cluster: String
    var attribute: String
    var minInterval: Int
    var maxInterval: Int
    var reportableChange: Int
}

private struct ReportingRow: View {
    let reporting: ConfiguredReporting

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text(reporting.cluster).font(.subheadline.weight(.medium)).monospaced()
                Text("·").foregroundStyle(.tertiary)
                Text(reporting.attribute).font(.subheadline).monospaced()
                Spacer()
                Text("EP \(reporting.endpoint)").font(.caption).foregroundStyle(.tertiary)
            }
            HStack(spacing: DesignTokens.Spacing.md) {
                Label("\(reporting.minInterval)s min", systemImage: "timer.circle")
                Label("\(reporting.maxInterval)s max", systemImage: "timer.circle.fill")
                if reporting.reportableChange > 0 {
                    Label("Δ\(reporting.reportableChange)", systemImage: "plusminus")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        DeviceReportingView(device: .preview)
            .environment(AppEnvironment())
    }
}
