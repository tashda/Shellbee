import SwiftUI

struct LightEffectsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let feature: LightAdvancedFeature
    let onChange: (JSONValue) -> Void

    private var values: [String] {
        guard case .enumeration(let vals) = feature.kind else { return [] }
        return vals
    }

    private var currentValue: String? { feature.value?.stringValue }

    var body: some View {
        NavigationStack {
            List(values, id: \.self) { effect in
                Button {
                    onChange(.string(effect))
                    dismiss()
                } label: {
                    HStack {
                        Text(effect.replacingOccurrences(of: "_", with: " ").capitalized)
                            .foregroundStyle(.primary)
                        Spacer()
                        if currentValue == effect {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .navigationTitle("Effects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
