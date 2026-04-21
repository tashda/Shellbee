import SwiftUI

struct InlineIntField: View {
    let label: String
    @Binding var value: Int
    var unit: String = ""
    var range: ClosedRange<Int>? = nil
    var offLabel: String? = nil

    @State private var text: String = ""
    @FocusState private var focused: Bool

    init(_ label: String, value: Binding<Int>, unit: String = "", range: ClosedRange<Int>? = nil, offLabel: String? = nil) {
        self.label = label
        self._value = value
        self.unit = unit
        self.range = range
        self.offLabel = offLabel
    }

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                TextField(offLabel ?? "", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .foregroundStyle(.secondary)
                if !unit.isEmpty, !text.isEmpty {
                    Text(unit)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { sync() }
        .onChange(of: value) { _, _ in if !focused { sync() } }
        .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
    }

    private func sync() {
        let lower = range?.lowerBound ?? 0
        text = (offLabel != nil && value == lower) ? "" : "\(value)"
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let lower = range?.lowerBound ?? 0
        if trimmed.isEmpty {
            value = lower
        } else if let n = Int(trimmed) {
            if let r = range { value = max(r.lowerBound, min(r.upperBound, n)) }
            else { value = max(lower, n) }
        }
        sync()
    }
}

#Preview {
    Form {
        InlineIntField("Offline Timeout", value: .constant(10), unit: "min", range: 1...60)
        InlineIntField("Max Jitter", value: .constant(500), unit: "ms", range: 0...60000)
        InlineIntField("Throttle", value: .constant(0), unit: "s", range: 0...300, offLabel: "Off")
        InlineIntField("Log Directories", value: .constant(10), range: 1...50)
    }
}
