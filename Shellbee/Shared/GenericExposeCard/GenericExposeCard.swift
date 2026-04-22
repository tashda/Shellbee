import SwiftUI

struct GenericExposeCard: View {
    let device: Device
    let state: [String: JSONValue]
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    private static let skipTypes: Set<String> = ["light", "switch", "cover", "lock", "fan", "climate"]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            header
            let rows = makeRows()
            if rows.isEmpty {
                Text("No controllable features found")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(rows, id: \.id) { row in
                    GenericExposeRow(row: row, mode: mode, onSend: onSend)
                    if row.id != rows.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if mode == .snapshot {
                Image(systemName: "cpu")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Device State").font(.headline)
            } else {
                Text("Controls").font(.headline)
            }
        }
    }

    private func makeRows() -> [ExposeRow] {
        let exposes = device.definition?.exposes ?? []
        let flat = exposes.flattenedLeaves
        return flat.compactMap { expose -> ExposeRow? in
            guard !Self.skipTypes.contains(expose.type) else { return nil }
            guard expose.isReadable || expose.isWritable else { return nil }
            let prop = expose.property ?? expose.name ?? ""
            guard !prop.isEmpty else { return nil }
            return ExposeRow(expose: expose, property: prop, stateValue: state[prop])
        }
    }

}

struct ExposeRow: Identifiable {
    let expose: Expose
    let property: String
    let stateValue: JSONValue?

    var id: String { property }

    var label: String {
        expose.label ?? property.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct GenericExposeRow: View {
    let row: ExposeRow
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    @State private var numericDraft: Double = 0

    var body: some View {
        switch row.expose.type {
        case "binary":
            binaryRow
        case "enum":
            enumRow
        case "numeric":
            numericRow
        default:
            textRow
        }
    }

    @ViewBuilder private var binaryRow: some View {
        let isOn = row.stateValue == row.expose.valueOn || row.stateValue?.boolValue == true
        if mode == .interactive, row.expose.isWritable,
           let on = row.expose.valueOn, let off = row.expose.valueOff {
            Toggle(row.label, isOn: Binding(
                get: { isOn },
                set: { v in onSend(.object([row.property: v ? on : off])) }
            ))
        } else {
            LabeledContent(row.label) {
                Text(isOn ? "On" : "Off").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var enumRow: some View {
        let values = row.expose.values ?? []
        if mode == .interactive, row.expose.isWritable, !values.isEmpty {
            Picker(row.label, selection: Binding(
                get: { row.stateValue?.stringValue ?? values.first ?? "" },
                set: { onSend(.object([row.property: .string($0)])) }
            )) {
                ForEach(values, id: \.self) {
                    Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0)
                }
            }
        } else {
            LabeledContent(row.label) {
                Text(row.stateValue?.stringValue?.replacingOccurrences(of: "_", with: " ").capitalized ?? "—")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var numericRow: some View {
        let current = row.stateValue?.numberValue ?? 0
        let unit = row.expose.unit.map { " \($0)" } ?? ""
        if mode == .interactive, row.expose.isWritable,
           let min = row.expose.valueMin, let max = row.expose.valueMax {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Text(row.label)
                    Spacer()
                    Text("\(Int(numericDraft))\(unit)").foregroundStyle(.secondary).monospacedDigit()
                }
                Slider(value: $numericDraft, in: min...max) { editing in
                    guard !editing else { return }
                    onSend(.object([row.property: .double(numericDraft)]))
                }
            }
            .onAppear { numericDraft = current }
            .onChange(of: current) { _, v in numericDraft = v }
        } else {
            LabeledContent(row.label) {
                Text("\(current.formatted(.number.precision(.fractionLength(0...1))))\(unit)")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }

    private var textRow: some View {
        LabeledContent(row.label) {
            Text(row.stateValue?.stringified ?? "—").foregroundStyle(.secondary)
        }
    }
}

private extension Optional where Wrapped: Collection {
    var isNilOrEmpty: Bool { self?.isEmpty ?? true }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            GenericExposeCard(device: .preview, state: [
                "power_on_behavior": .string("previous"),
                "transition": .double(3)
            ], mode: .interactive, onSend: { _ in })
            GenericExposeCard(device: .preview, state: [
                "power_on_behavior": .string("on"),
                "transition": .double(1)
            ], mode: .snapshot, onSend: { _ in })
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
