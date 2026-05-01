import SwiftUI

extension View {
    @ViewBuilder
    func minimizeSearchToolbarIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            self.searchToolbarBehavior(.minimize)
        } else {
            self
        }
    }

    @ViewBuilder
    func glassEffectIfAvailable<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self.background(shape.fill(.ultraThinMaterial))
        }
    }

    @ViewBuilder
    func glassProminentButtonStyleIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func glassButtonStyleIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// `.symbolEffect(.bounce)` (no value) needs iOS 18 because BounceSymbolEffect
    /// only conforms to IndefiniteSymbolEffect there. iOS 17 has no equivalent
    /// without an external `value:` trigger, so the effect is dropped on 17.
    @ViewBuilder
    func bounceSymbolEffectIfAvailable() -> some View {
        if #available(iOS 18.0, *) {
            self.bounceSymbolEffectIndefinite()
        } else {
            self
        }
    }

    @available(iOS 18.0, *)
    fileprivate func bounceSymbolEffectIndefinite() -> some View {
        self.symbolEffect(.bounce)
    }
}
