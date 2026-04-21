import SwiftUI

struct AddReportingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let device: Device
    let availableClusters: [String]
    let onAdd: (ReportingConfig) -> Void

    @State private var cluster: String = ""
    @State private var attribute: String = ""
    @State private var minInterval: Int = 1
    @State private var maxInterval: Int = 3600
    @State private var reportableChange: Int = 1

    private var canSave: Bool { !cluster.isEmpty && !attribute.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Data Source") {
                    if !availableClusters.isEmpty {
                        Picker("Cluster", selection: $cluster) {
                            Text("Choose").tag("")
                            ForEach(availableClusters, id: \.self) { c in
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
                if cluster.isEmpty, let first = availableClusters.first { cluster = first }
            }
        }
    }
}

#Preview {
    AddReportingSheet(
        device: .preview,
        availableClusters: ["genOnOff", "genLevelCtrl", "lightingColorCtrl"]
    ) { _ in }
}
