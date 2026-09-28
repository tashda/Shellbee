import SwiftUI

/// One expose in full: its z2m key, type, range, access and description.
struct DocCapabilityDetailView: View {
    let capability: DeviceDocCapability

    var body: some View {
        List {
            SwiftUI.Group {
                Section {
                    if let property = capability.property {
                        LabeledContent("Property") {
                            Text(property)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    LabeledContent("Type", value: capability.kindText)
                    if let range = capability.rangeText {
                        LabeledContent("Range", value: range)
                    } else if let unit = capability.unit, !unit.isEmpty {
                        LabeledContent("Unit", value: unit)
                    }
                    if let step = capability.valueStep {
                        LabeledContent("Step", value: step.formatted())
                    }
                    LabeledContent("Access", value: capability.accessText)
                    if let endpoint = capability.endpoint, !endpoint.isEmpty {
                        LabeledContent("Endpoint", value: endpoint)
                    }
                } footer: {
                    if let description = capability.description, !description.isEmpty {
                        Text(description)
                    }
                }

                if capability.kind == "enum", !capability.values.isEmpty {
                    Section("Values") {
                        ForEach(capability.values, id: \.self) { value in
                            Text(value)
                        }
                    }
                }
            }
            .shellbeeThemedRows()
        }
        .listStyle(.insetGrouped)
        .shellbeeThemedCanvas()
        .navigationTitle(capability.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}
