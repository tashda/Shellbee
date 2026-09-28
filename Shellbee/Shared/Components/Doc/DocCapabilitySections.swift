import SwiftUI

/// What a device exposes, grouped the same way as its settings: Controls,
/// Behaviour, Indicators, Maintenance, Status, More, then Diagnostics. Each
/// row pushes to `DocCapabilityDetailView`. Place inside a `List`.
struct DocCapabilitySections: View {
    let capabilities: [DeviceDocCapability]

    var body: some View {
        ForEach(groups, id: \.category) { group in
            Section(FeatureLayout.title(for: group.category)) {
                ForEach(group.items) { capability in
                    NavigationLink {
                        DocCapabilityDetailView(capability: capability)
                    } label: {
                        row(capability)
                    }
                }
            }
        }
    }

    private func row(_ capability: DeviceDocCapability) -> some View {
        LabeledContent {
            if let summary = capability.valueSummary {
                Text(summary)
                    .lineLimit(1)
            }
        } label: {
            Label {
                Text(capability.label)
                    .lineLimit(1)
            } icon: {
                Image(systemName: meta(for: capability).symbol)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var groups: [(category: FeatureCategory, items: [DeviceDocCapability])] {
        let buckets = Dictionary(grouping: capabilities) { category(for: $0) }
        return FeatureLayout.displayOrder.compactMap { category in
            guard let items = buckets[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    private func category(for capability: DeviceDocCapability) -> FeatureCategory {
        if capability.isDiagnostic { return .diagnostic }
        if Self.primaryControls.contains(capability.property ?? "") { return .operation }
        return meta(for: capability).category
    }

    /// Features a typed card operates, which the settings catalog leaves out
    /// because the card already shows them.
    private static let primaryControls: Set<String> = [
        "state", "effect", "color_xy", "color_hs", "position", "tilt"
    ]

    private func meta(for capability: DeviceDocCapability) -> FeatureMeta {
        FeatureCatalog.meta(for: capability.property ?? "", exposeType: capability.kind)
    }
}
