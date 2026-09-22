import SwiftUI

/// Filter health for air purifiers: whether the filter needs replacing,
/// plus filter and device age when the device reports them.
struct FanFilterCard: View {
    let context: FanControlContext

    var body: some View {
        let needsReplace = replaceFilterValue ?? false
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            CardHeader(
                systemImage: needsReplace ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
                title: "Filter",
                value: needsReplace ? "Replace" : "Healthy",
                tint: needsReplace ? .orange : .green,
                valueColor: needsReplace ? .orange : .secondary
            )
            if !ageItems.isEmpty {
                StatStrip(items: ageItems)
            }
        }
        .cardSurface()
    }

    static func isRelevant(for context: FanControlContext) -> Bool {
        context.extras.contains { filterProps.contains($0.property ?? "") }
    }

    static let filterProps: Set<String> = ["replace_filter", "filter_age", "device_age"]

    private var replaceFilterValue: Bool? {
        guard let e = context.extras.first(where: { $0.property == "replace_filter" }),
              let p = e.property else { return nil }
        let v = context.state[p]
        if v == e.valueOn { return true }
        if v == e.valueOff { return false }
        return v?.boolValue
    }

    private var ageItems: [StatStripItem] {
        var items: [StatStripItem] = []
        if let v = context.state["filter_age"]?.numberValue {
            items.append(StatStripItem(value: Self.formatDuration(v), caption: "Filter Age"))
        }
        if let v = context.state["device_age"]?.numberValue {
            items.append(StatStripItem(value: Self.formatDuration(v), caption: "Device Age"))
        }
        return items
    }

    private static func formatDuration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total < 60 { return "\(total) min" }
        let hours = total / 60
        if hours < 48 { return "\(hours) h" }
        let days = hours / 24
        if days < 60 { return "\(days) d" }
        return "\(days / 30) mo"
    }
}
