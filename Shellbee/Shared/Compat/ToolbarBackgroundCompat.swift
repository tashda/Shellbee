import SwiftUI

private struct ConfiguredTopScrollEdgeEffectModifier: ViewModifier {
    @AppStorage("developerSoftTopEdgeEnabled")
    private var softTopEdgeEnabled = true

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            if softTopEdgeEnabled {
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
    /// Applies the developer-selected top scroll-edge treatment on iOS 27+.
    /// Earlier releases keep their native system edge treatment.
    func configuredTopScrollEdgeEffect() -> some View {
        modifier(ConfiguredTopScrollEdgeEffectModifier())
    }
}
