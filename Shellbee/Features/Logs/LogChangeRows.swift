import SwiftUI

/// One row of the Activity sheet's Changes section.
struct LogChangeRow: Identifiable {
    enum Value {
        case text(from: String?, to: String)
        case colour(from: Color?, to: Color, name: String)
    }

    let id: String
    let label: String
    let value: Value
}

/// Turns a state diff into rows a person can read. Z2M reports a colour
/// several ways at once (x/y, hue/saturation twice, and an estimated
/// colour temperature), so colour collapses into one swatch row plus Hue
/// and Saturation, and values that read the same before and after drop out.
enum LogChangeRows {
    static func rows(for changes: [LogContext.StateChange], payload: [String: JSONValue]?) -> [LogChangeRow] {
        let changed = changes.filter { $0.displayFrom != $0.displayTo }
        let colourChanges = changed.filter { isColour($0.property) }
        let others = changed.filter { !isColour($0.property) }
        return colourRows(colourChanges, payload: payload) + others.map(textRow)
    }

    // MARK: - Colour

    private enum ColourPart { case hue, saturation, xy, temperature, other }

    private static func colourRows(_ changes: [LogContext.StateChange], payload: [String: JSONValue]?) -> [LogChangeRow] {
        guard !changes.isEmpty else { return [] }
        let byPart = Dictionary(grouping: changes, by: { part(of: $0.property) })
        let mode = payload?["color_mode"]?.stringValue
        let isWhiteMode = mode == "color_temp"
            || (mode == nil && byPart[.hue] == nil && byPart[.xy] == nil)

        if isWhiteMode {
            return (byPart[.temperature] ?? []).map(textRow) + (byPart[.other] ?? []).map(textRow)
        }

        var rows: [LogChangeRow] = []
        if let to = payload.flatMap(LightDisplayColor.resolve(state:)) {
            rows.append(LogChangeRow(
                id: "colour",
                label: String(localized: "Colour"),
                value: .colour(from: fromColour(byPart), to: to, name: LightDisplayColor.name(for: to))
            ))
        }
        if let hue = byPart[.hue]?.first {
            rows.append(LogChangeRow(id: "hue", label: String(localized: "Hue"),
                                     value: .text(from: hue.from.flatMap { degrees($0) }, to: degrees(hue.to) ?? hue.displayTo)))
        }
        if let saturation = byPart[.saturation]?.first {
            rows.append(LogChangeRow(id: "saturation", label: String(localized: "Saturation"),
                                     value: .text(from: saturation.from.flatMap { percent($0) }, to: percent(saturation.to) ?? saturation.displayTo)))
        }
        return rows + (byPart[.other] ?? []).map(textRow)
    }

    /// The colour before the change, when the report carries the old hue.
    private static func fromColour(_ byPart: [ColourPart: [LogContext.StateChange]]) -> Color? {
        guard let hue = byPart[.hue]?.first?.from?.numberValue else { return nil }
        let saturation = byPart[.saturation]?.first?.from?.numberValue ?? 100
        return Color(hue: min(max(hue / 360, 0), 1), saturation: min(max(saturation / 100, 0), 1), brightness: 1)
    }

    private static func part(of property: String) -> ColourPart {
        let key = property.lowercased().split(separator: ".").last.map(String.init) ?? property.lowercased()
        switch key {
        case "h", "hue": return .hue
        case "s", "saturation": return .saturation
        case "x", "y", "color_xy": return .xy
        default: return key.contains("temp") ? .temperature : .other
        }
    }

    private static func isColour(_ property: String) -> Bool {
        ActivityInstrumentResolver.kind(forProperty: property) == .colour
            || ["hue", "saturation"].contains(property.lowercased())
    }

    // MARK: - Formatting

    private static func textRow(_ change: LogContext.StateChange) -> LogChangeRow {
        LogChangeRow(id: change.property, label: change.displayLabel,
                     value: .text(from: change.displayFrom, to: change.displayTo))
    }

    private static func degrees(_ value: JSONValue) -> String? {
        value.numberValue.map { "\(Int($0.rounded()))°" }
    }

    private static func percent(_ value: JSONValue) -> String? {
        value.numberValue.map { "\(Int($0.rounded())) %" }
    }
}

/// Label on the left, "from → to" on the right, or a pair of swatches for
/// the colour row.
struct LogChangeRowView: View {
    let row: LogChangeRow

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(row.label)
                .font(DesignTokens.Typography.formRowLabel)
            Spacer()
            switch row.value {
            case .text(let from, let to):
                if let from {
                    Text(from)
                        .foregroundStyle(.secondary)
                    arrow
                }
                Text(to)
                    .fontWeight(.medium)
            case .colour(let from, let to, let name):
                if let from {
                    swatch(from)
                    arrow
                }
                swatch(to)
                Text(name)
                    .fontWeight(.medium)
            }
        }
        .font(DesignTokens.Typography.formRowValue)
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .accessibilityLabel("to")
    }

    private func swatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .overlay(Circle().strokeBorder(Color.primary.opacity(DesignTokens.Opacity.hairline)))
            .frame(width: DesignTokens.Size.changeSwatch, height: DesignTokens.Size.changeSwatch)
            .accessibilityHidden(true)
    }
}
