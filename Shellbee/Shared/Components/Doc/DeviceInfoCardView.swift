import SwiftUI

// Shows device definition metadata at the top of the doc view.
// Data comes from device.definition (available immediately, no network needed).
struct DeviceInfoCardView: View {
    let device: Device

    var body: some View {
        guard let def = device.definition else { return AnyView(EmptyView()) }
        return AnyView(content(def))
    }

    @ViewBuilder
    private func content(_ def: DeviceDefinition) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows(for: def), id: \.label) { row in
                InfoRow(label: row.label, value: row.value)
                if row.label != rows(for: def).last?.label {
                    Divider().padding(.leading, DesignTokens.Spacing.lg)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
    }

    private struct InfoRow: View {
        let label: String
        let value: String

        var body: some View {
            HStack(alignment: .top) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
    }

    private struct RowData {
        let label: String
        let value: String
    }

    private func rows(for def: DeviceDefinition) -> [RowData] {
        var result: [RowData] = [
            RowData(label: "Model", value: def.model),
            RowData(label: "Vendor", value: def.vendor),
            RowData(label: "Description", value: def.description)
        ]
        let exposesSummary = exposeSummary(def)
        if !exposesSummary.isEmpty {
            result.append(RowData(label: "Exposes", value: exposesSummary))
        }
        result.append(RowData(label: "OTA Updates", value: (def.supportsOTA ?? false) ? "Supported" : "Not supported"))
        return result
    }

    private func exposeSummary(_ def: DeviceDefinition) -> String {
        def.exposes.map { expose in
            if let features = expose.features, !features.isEmpty {
                let names = features.compactMap(\.name).joined(separator: ", ")
                return "\(expose.type) (\(names))"
            }
            return expose.name ?? expose.type
        }.joined(separator: ", ")
    }
}

#Preview {
    DeviceInfoCardView(device: .preview)
        .padding()
}
