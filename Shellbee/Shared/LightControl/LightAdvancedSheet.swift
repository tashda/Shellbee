import SwiftUI

struct LightAdvancedSheet: View {
    @Environment(\.dismiss) private var dismiss

    var title: String = "Settings"
    let features: [LightAdvancedFeature]
    let onChange: (JSONValue) -> Void

    var body: some View {
        NavigationStack {
            List(features) { feature in
                LightAdvancedFeatureRow(feature: feature) { value in
                    onChange(feature.payload(value))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
