import SwiftUI

struct LightEffectsSheet: View {
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
                } label: {
                    HStack {
                        Text(effect.replacingOccurrences(of: "_", with: " ").capitalized)
                            .foregroundStyle(.primary)
                        Spacer()
                        SelectionIndicator(isSelected: currentValue == effect)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Effects")
            .navigationBarTitleDisplayMode(.inline)
        }
        .configuredTopScrollEdgeEffect()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
