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

    /// iOS 26 introduced `scrollEdgeEffectStyle(_:for:)` with an `.auto` default
    /// that picked `.soft` (fade & blur). iOS 27's SDK silently changed what
    /// `.auto` resolves to for the top edge, defaulting to `.hard` (flat,
    /// opaque) instead — a look Shellbee's toolbars were never designed for.
    /// This forces the old `.soft` behavior back for the top scroll edge only;
    /// bottom edges (tab bars) are left on the system default.
    @ViewBuilder
    func forceSoftTopScrollEdgeEffect() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
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
