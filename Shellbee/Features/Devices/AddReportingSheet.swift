import SwiftUI

struct AddReportingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let device: Device
    let endpointClusters: [(endpoint: Int, clusters: [String])]
    let onAdd: (ReportingConfig) -> Void

    @State private var endpoint: Int = 0
    @State private var cluster: String = ""
    @State private var attribute: String = ""
    @State private var minInterval: Int = 1
    @State private var maxInterval: Int = 3600
    @State private var reportableChange: Int = 1

    private var endpoints: [Int] { endpointClusters.map(\.endpoint) }

    private var clustersForEndpoint: [String] {
        endpointClusters.first { $0.endpoint == endpoint }?.clusters ?? []
    }

    private var canSave: Bool {
        endpoint != 0 && !cluster.isEmpty && !attribute.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Data Source") {
                    if endpoints.count > 1 {
                        Picker("Endpoint", selection: $endpoint) {
                            Text("Choose").tag(0)
                            ForEach(endpoints, id: \.self) { ep in
                                Text("EP \(ep)").tag(ep)
                            }
                        }
                    }
                    if !clustersForEndpoint.isEmpty {
                        Picker("Cluster", selection: $cluster) {
                            Text("Choose").tag("")
                            ForEach(clustersForEndpoint, id: \.self) { c in
                                Text(c).tag(c)
                            }
                        }
                    } else {
                        TextField("Cluster (e.g. genOnOff)", text: $cluster)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    TextField("Attribute (e.g. onOff)", text: $attribute)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Reporting Interval") {
                    InlineIntField("Min Interval", value: $minInterval, unit: "s", range: 0...3600)
                    InlineIntField("Max Interval", value: $maxInterval, unit: "s", range: 0...65535)
                }

                Section {
                    InlineIntField("Min Change", value: $reportableChange, range: 0...1000)
                } footer: {
                    Text("Minimum change in value before a report is sent. Set to 0 to report on any change.")
                }
            }
            .navigationTitle("Add Reporting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        onAdd(ReportingConfig(
                            endpoint: endpoint,
                            cluster: cluster, attribute: attribute,
                            minInterval: minInterval, maxInterval: maxInterval,
                            reportableChange: reportableChange
                        ))
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if endpoint == 0, let first = endpoints.first { endpoint = first }
                if cluster.isEmpty, let first = clustersForEndpoint.first { cluster = first }
            }
            .onChange(of: endpoint) { _, _ in
                if !clustersForEndpoint.contains(cluster) {
                    cluster = clustersForEndpoint.first ?? ""
                }
            }
        }
    }
}

#Preview {
    AddReportingSheet(
        device: .preview,
        endpointClusters: [(1, ["genOnOff", "genLevelCtrl", "lightingColorCtrl"])]
    ) { _ in }
}
