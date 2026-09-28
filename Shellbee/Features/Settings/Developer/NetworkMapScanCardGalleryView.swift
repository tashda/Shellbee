import SwiftUI

/// The network map's refresh card in each state, drawn over the canvas as
/// it appears on the map, with sample figures.
struct NetworkMapScanCardGalleryView: View {
    private enum Sample: String, CaseIterable, Identifiable {
        case scanning = "Scanning"
        case scanningQuiet = "Scanning, successes hidden"
        case finished = "Finished"
        case finishedWithFailures = "Finished, routers missing"
        case failed = "Failed"

        var id: String { rawValue }
    }

    @State private var sample: Sample = .scanning
    @State private var startedAt = Date().addingTimeInterval(-42)

    var body: some View {
        NetworkMapRefreshProgressView(
            bridgeID: UUID(),
            bridgeName: "Home Bridge",
            phase: phase,
            startedAt: startedAt,
            scan: scan,
            fillsViewport: false,
            onDismiss: {},
            onRetry: {}
        )
        .shellbeeThemedCanvas()
        .navigationTitle("Network Map Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Picker("State", selection: $sample) {
                    ForEach(Sample.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(.secondary)
            }
        }
    }

    private var phase: NetworkMapRefreshPhase {
        switch sample {
        case .scanning, .scanningQuiet: .building(deviceCount: 0)
        case .finished: .completed(Self.summary(failed: []))
        case .finishedWithFailures: .completed(Self.summary(failed: ["Garage Plug", "Attic Repeater"]))
        case .failed: .failed(message: "Zigbee2MQTT didn't answer within 2 minutes. The bridge may be busy or offline.")
        }
    }

    private var scan: NetworkMapScanProgress? {
        let routers = (1...24).map { "Router \($0)" }
        var progress = NetworkMapScanProgress(
            targetNames: routers,
            visibility: sample == .scanningQuiet ? .startAndFailures : .everyDevice,
            requestedAt: startedAt
        )
        progress.ingest(logMessage: "Starting network scan", at: startedAt.addingTimeInterval(2))
        for (index, name) in routers.prefix(15).enumerated() {
            let line = index == 6 ? "Failed to execute LQI for '\(name)'" : "LQI succeeded for '\(name)'"
            progress.ingest(logMessage: line, at: startedAt.addingTimeInterval(Double(3 + index * 2)))
        }
        return progress
    }

    private static func summary(failed: [String]) -> NetworkMapScanSummary {
        let names = (1...20).map { "Router \($0)" } + failed
        let nodes = names.enumerated().map { index, name -> [String: Any] in
            ["ieeeAddr": "0x\(index)", "friendlyName": name, "type": "Router",
             "failed": failed.contains(name) ? ["lqi"] : []]
        } + (0..<96).map { ["ieeeAddr": "0xe\($0)", "friendlyName": "End \($0)", "type": "EndDevice"] }
        let data = (try? JSONSerialization.data(withJSONObject: ["nodes": nodes, "links": []])) ?? Data()
        let topology = (try? JSONDecoder().decode(NetworkTopology.self, from: data)) ?? NetworkTopology(nodes: [], links: [])
        return NetworkMapScanSummary(topology: topology, progress: nil, finishedAt: .now)
    }
}
