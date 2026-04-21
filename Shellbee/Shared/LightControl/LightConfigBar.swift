import SwiftUI

struct LightConfigBar: View {
    let context: LightControlContext
    let onSend: (JSONValue) -> Void

    @State private var showEffects = false
    @State private var showStartup = false
    @State private var showMore = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if let effect = context.effectFeature {
                glassButton(title: "Effects", systemImage: "sparkles") { showEffects = true }
                    .sheet(isPresented: $showEffects) {
                        LightEffectsSheet(feature: effect) { onSend(effect.payload($0)) }
                    }
            }

            if !context.startupFeatures.isEmpty {
                glassButton(title: "Startup", systemImage: "power") { showStartup = true }
                    .sheet(isPresented: $showStartup) {
                        LightAdvancedSheet(title: "Startup", features: context.startupFeatures, onChange: onSend)
                    }
            }

            if !context.otherAdvancedFeatures.isEmpty {
                glassButton(title: "More", systemImage: "ellipsis") { showMore = true }
                    .sheet(isPresented: $showMore) {
                        LightAdvancedSheet(title: "Settings", features: context.otherAdvancedFeatures, onChange: onSend)
                    }
            }
        }
    }

    private func glassButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
