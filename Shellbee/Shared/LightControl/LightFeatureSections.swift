import SwiftUI

/// Renders a light's "leftover" advanced features as native iOS Settings-style
/// `List` sections beneath the hero `LightControlCard`. Effects stay inside
/// the card (true light-specific control); Startup, Power-on, and other
/// advanced configuration drop down here so they look like native iOS
/// Settings.
///
/// Place inside a `List` whose `.listStyle` is grouped or inset-grouped.
struct LightFeatureSections: View {
    let context: LightControlContext
    let onSend: (JSONValue) -> Void

    var body: some View {
        if !context.startupFeatures.isEmpty {
            Section("Startup") {
                ForEach(context.startupFeatures) { feature in
                    LightAdvancedFeatureRow(feature: feature) { value in
                        onSend(feature.payload(value))
                    }
                }
            }
        }
        if !context.otherAdvancedFeatures.isEmpty {
            Section("Configuration") {
                ForEach(context.otherAdvancedFeatures) { feature in
                    LightAdvancedFeatureRow(feature: feature) { value in
                        onSend(feature.payload(value))
                    }
                }
            }
        }
    }
}
