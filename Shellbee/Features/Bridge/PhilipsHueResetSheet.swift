import SwiftUI

struct PhilipsHueResetSheet: View {
    @Environment(\.dismiss) private var dismiss

    let extendedPanId: String
    let onApply: (_ extendedPanId: String, _ serialNumbers: [String]) -> Void

    @State private var serialNumbersRaw = ""
    @State private var customPanId: String

    init(extendedPanId: String, onApply: @escaping (_ extendedPanId: String, _ serialNumbers: [String]) -> Void) {
        self.extendedPanId = extendedPanId
        self.onApply = onApply
        _customPanId = State(initialValue: extendedPanId)
    }

    private var serialNumbers: [String] {
        serialNumbersRaw
            .replacingOccurrences(of: " ", with: "")
            .split(separator: ",")
            .map(String.init)
    }

    private static let snPredicate = NSPredicate(format: "SELF MATCHES %@", "^[a-fA-F0-9]{6}$")
    private static let panPredicate = NSPredicate(format: "SELF MATCHES %@", "^0x[a-fA-F0-9]{16}$")

    private var isValid: Bool {
        guard !serialNumbers.isEmpty else { return false }
        let snValid = serialNumbers.allSatisfy { Self.snPredicate.evaluate(with: $0) }
        if customPanId.isEmpty { return snValid }
        return snValid && Self.panPredicate.evaluate(with: customPanId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SettingsTextField("Serial Numbers", text: $serialNumbersRaw, placeholder: "e.g. a1b2c3, d4e5f6")
                } footer: {
                    Text("Enter comma-separated 6-character hex serial numbers printed on each bulb.")
                }

                Section {
                    SettingsTextField("Extended PAN ID", text: $customPanId, placeholder: "0x\(String(repeating: "0", count: 16))")
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Leave blank to use the network's extended PAN ID. Format: 0x followed by 16 hex characters.")
                }
            }
            .navigationTitle("Philips Hue Reset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(customPanId, serialNumbers)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    PhilipsHueResetSheet(extendedPanId: "0x0000000000000000") { _, _ in }
}
