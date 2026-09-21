import SwiftUI

private struct ConfiguredTopScrollEdgeEffectModifier: ViewModifier {
    @AppStorage("developerSoftTopEdgeEnabled")
    private var softTopEdgeEnabled = true

    @ViewBuilder
    func body(content: Content) -> some View {
        if softTopEdgeEnabled {
            if #available(iOS 26.0, *) {
                content.scrollEdgeEffectStyle(.soft, for: .top)
            } else {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    /// Applies the developer-selected top scroll-edge treatment everywhere
    /// Shellbee explicitly styles a navigation surface.
    func configuredTopScrollEdgeEffect() -> some View {
        modifier(ConfiguredTopScrollEdgeEffectModifier())
    }
}
